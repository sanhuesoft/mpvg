//
//  ArtworkCacheManager.swift
//  mpvg
//
//  Two-tiered (Memory + Persistent Disk) high-performance artwork caching
//  system for album covers and artist portraits. Guarantees instant scrolling,
//  zero redundant network requests, and offline availability.
//

import Foundation
import CryptoKit
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

final class ArtworkCacheManager {
    static let shared = ArtworkCacheManager()
    
    private let memoryCache = NSCache<NSString, PlatformImage>()
    private let diskQueue = DispatchQueue(label: "com.sanhuesoft.mpvg.artworkcache", qos: .userInitiated, attributes: .concurrent)
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    
    // In-flight network request deduplication
    private var inFlightTasks: [String: Task<PlatformImage?, Never>] = [:]
    private let tasksLock = NSLock()
    
    private init() {
        // 1. Configure In-Memory Cache
        memoryCache.countLimit = 600
        memoryCache.totalCostLimit = 1024 * 1024 * 256 // 256 MB RAM limit
        
        // 2. Setup Persistent Disk Directory in Application Support (immune to OS purge)
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        
        let persistentArtDir = appSupportDir.appendingPathComponent("mpvg/artwork_cache", isDirectory: true)
        if !fileManager.fileExists(atPath: persistentArtDir.path) {
            try? fileManager.createDirectory(at: persistentArtDir, withIntermediateDirectories: true)
        }
        
        // Exclude from iCloud backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = persistentArtDir
        try? mutableURL.setResourceValues(resourceValues)
        self.diskCacheDirectory = persistentArtDir
        
        // Migrate any existing files from legacy .cachesDirectory so existing caches are not lost
        if let legacyCaches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let legacyArtDir = legacyCaches.appendingPathComponent("mpvg/artwork_cache", isDirectory: true)
            if fileManager.fileExists(atPath: legacyArtDir.path),
               let legacyFiles = try? fileManager.contentsOfDirectory(at: legacyArtDir, includingPropertiesForKeys: nil) {
                for file in legacyFiles {
                    let dest = persistentArtDir.appendingPathComponent(file.lastPathComponent)
                    if !fileManager.fileExists(atPath: dest.path) {
                        try? fileManager.moveItem(at: file, to: dest)
                    }
                }
            }
        }
    }
    
    // MARK: - Canonical Cache Key
    /// Normalizes URLs by removing transient query params (s, t, salt, token) and sorting the rest so cached artwork matches permanently.
    func cacheKey(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return sha256Hex(url.absoluteString)
        }
        
        // Remove dynamic authentication tokens so the cache key remains stable
        if let queryItems = components.queryItems {
            let filtered = queryItems.filter { item in
                let name = item.name.lowercased()
                return name != "t" && name != "s" && name != "salt" && name != "token"
            }
            components.queryItems = filtered.isEmpty ? nil : filtered.sorted(by: { $0.name < $1.name })
        }
        
        let normalized = components.string ?? url.absoluteString
        return sha256Hex(normalized)
    }
    
    private func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func diskFileURL(for key: String) -> URL {
        diskCacheDirectory.appendingPathComponent(key + ".dat")
    }
    
    // MARK: - Synchronous Memory / Fast Disk Lookup
    func imageFromMemory(for key: String) -> PlatformImage? {
        memoryCache.object(forKey: key as NSString)
    }
    
    /// Synchronous lookup: checks memory, and if not present, performs an immediate fast disk check
    /// and populates memory cache so SwiftUI views render without a placeholder flash on launch.
    func syncImage(for url: URL) -> PlatformImage? {
        let key = cacheKey(for: url)
        if let memImage = memoryCache.object(forKey: key as NSString) {
            return memImage
        }
        let fileURL = diskFileURL(for: key)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let diskImage = PlatformImage(data: data) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        return nil
    }
    
    func hasImage(for url: URL) -> Bool {
        let key = cacheKey(for: url)
        if memoryCache.object(forKey: key as NSString) != nil { return true }
        return fileManager.fileExists(atPath: diskFileURL(for: key).path)
    }
    
    // MARK: - Asynchronous Retrieve (Memory -> Disk)
    func image(for url: URL) async -> PlatformImage? {
        let key = cacheKey(for: url)
        
        // 1. Check Memory Cache
        if let memImage = memoryCache.object(forKey: key as NSString) {
            return memImage
        }
        
        // 2. Check Persistent Disk Cache
        let fileURL = diskFileURL(for: key)
        if let diskImage = await loadFromDisk(fileURL: fileURL) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        return nil
    }
    
    // MARK: - Deduplicated Network Loading
    func loadImage(for url: URL) async -> PlatformImage? {
        // 1. Check cache first
        if let cached = await image(for: url) {
            return cached
        }
        
        let key = cacheKey(for: url)
        
        // 2. Reuse in-flight task if already downloading this artwork
        tasksLock.lock()
        if let existing = inFlightTasks[key] {
            tasksLock.unlock()
            return await existing.value
        }
        
        let task = Task<PlatformImage?, Never> {
            do {
                let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
                let (data, response) = try await URLSession.shared.data(for: request)
                if Task.isCancelled { return nil }
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let img = PlatformImage(data: data) {
                    self.storeImage(img, for: url, rawData: data)
                    return img
                }
            } catch {
                // Handled silently
            }
            return nil
        }
        
        inFlightTasks[key] = task
        tasksLock.unlock()
        
        let result = await task.value
        
        tasksLock.lock()
        inFlightTasks.removeValue(forKey: key)
        tasksLock.unlock()
        
        return result
    }
    
    // MARK: - Store (Memory + Disk)
    func storeImage(_ image: PlatformImage, for url: URL, rawData: Data? = nil) {
        let key = cacheKey(for: url)
        
        // Store in memory
        memoryCache.setObject(image, forKey: key as NSString)
        
        // Persist to disk asynchronously
        let fileURL = diskFileURL(for: key)
        diskQueue.async { [weak self] in
            guard self != nil else { return }
            var dataToWrite: Data? = rawData
            
            if dataToWrite == nil {
                #if canImport(AppKit)
                if let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff) {
                    dataToWrite = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88])
                }
                #elseif canImport(UIKit)
                dataToWrite = image.jpegData(compressionQuality: 0.88)
                #endif
            }
            
            if let data = dataToWrite {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
    
    private func loadFromDisk(fileURL: URL) async -> PlatformImage? {
        await withCheckedContinuation { continuation in
            diskQueue.async {
                guard FileManager.default.fileExists(atPath: fileURL.path),
                      let data = try? Data(contentsOf: fileURL),
                      let image = PlatformImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
    
    // MARK: - Cache Maintenance
    func clearAllCache() {
        memoryCache.removeAllObjects()
        diskQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let files = try? self.fileManager.contentsOfDirectory(at: self.diskCacheDirectory, includingPropertiesForKeys: nil) {
                for file in files {
                    try? self.fileManager.removeItem(at: file)
                }
            }
        }
    }
    
    func formattedDiskCacheSize() -> String {
        var totalSize: Int64 = 0
        if let files = try? fileManager.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let resource = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resource.fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}
