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
    private let diskQueue = DispatchQueue(label: "com.sanhuesoft.mpvg.artworkcache", qos: .utility)
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    
    private init() {
        // 1. Configure In-Memory Cache
        memoryCache.countLimit = 600
        memoryCache.totalCostLimit = 1024 * 1024 * 256 // 256 MB RAM limit
        
        // 2. Setup Persistent Disk Directory
        let baseDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        
        let artDir = baseDir.appendingPathComponent("mpvg/artwork_cache", isDirectory: true)
        if !fileManager.fileExists(atPath: artDir.path) {
            try? fileManager.createDirectory(at: artDir, withIntermediateDirectories: true)
        }
        self.diskCacheDirectory = artDir
    }
    
    // MARK: - Canonical Cache Key
    /// Normalizes URLs by removing transient query params (s, t, salt, token) so cached artwork matches permanently.
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
            components.queryItems = filtered.isEmpty ? nil : filtered
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
    
    // MARK: - Synchronous Memory Lookup
    func imageFromMemory(for key: String) -> PlatformImage? {
        memoryCache.object(forKey: key as NSString)
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
            // Populate memory cache
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        return nil
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
        diskQueue.async { [weak self] in
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
