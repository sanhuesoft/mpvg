//
//  AudioCacheManager.swift
//  mpvg
//
//  Background queue audio preloading and disk caching manager.
//  Prefetches the next N tracks in queue so playback starts instantly without network latency.
//

import Foundation

final class AudioCacheManager: @unchecked Sendable {
    static let shared = AudioCacheManager()
    
    private let fileManager = FileManager.default
    private let audioCacheDir: URL
    private let lock = NSLock()
    private var activeDownloads: [String: Task<Void, Never>] = [:]
    
    private init() {
        let baseDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let audioDir = baseDir.appendingPathComponent("mpvg/Audio", isDirectory: true)
        if !fileManager.fileExists(atPath: audioDir.path) {
            try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
        self.audioCacheDir = audioDir
    }
    
    // MARK: - Check Cache
    func cachedAudioURL(for songId: String) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(at: audioCacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return nil
        }
        
        for fileURL in files {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            if filename == songId {
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let size = attrs[.size] as? Int64, size > 1024 { // Valid audio file (> 1KB)
                    return fileURL
                }
            }
        }
        return nil
    }
    
    // MARK: - Preload Queue
    func preloadQueue(
        queue: [SongItem],
        startingAfter index: Int,
        count: Int,
        navidrome: NavidromeService
    ) {
        guard count > 0, !queue.isEmpty, index >= 0, index < queue.count else { return }
        
        let nextTracks = Array(queue.dropFirst(index + 1).prefix(count))
        guard !nextTracks.isEmpty else { return }
        
        let nextIds = Set(nextTracks.map { $0.id })
        
        // Cancel downloads that are no longer in the immediate preload window
        lock.lock()
        for (songId, task) in activeDownloads {
            if !nextIds.contains(songId) {
                task.cancel()
                activeDownloads.removeValue(forKey: songId)
            }
        }
        lock.unlock()
        
        // Launch background downloads for needed tracks
        for song in nextTracks {
            if cachedAudioURL(for: song.id) != nil {
                continue // Already cached
            }
            
            lock.lock()
            if activeDownloads[song.id] != nil {
                lock.unlock()
                continue // Already downloading
            }
            
            let downloadTask = Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                await self.downloadTrack(song: song, navidrome: navidrome)
                
                self.lock.lock()
                self.activeDownloads.removeValue(forKey: song.id)
                self.lock.unlock()
            }
            activeDownloads[song.id] = downloadTask
            lock.unlock()
        }
    }
    
    // MARK: - Internal Download
    private func downloadTrack(song: SongItem, navidrome: NavidromeService) async {
        guard let streamURL = await navidrome.streamURL(for: song.id) else { return }
        if Task.isCancelled { return }
        
        do {
            let (tempLocalURL, response) = try await URLSession.shared.download(from: streamURL)
            if Task.isCancelled {
                try? fileManager.removeItem(at: tempLocalURL)
                return
            }
            
            // Check response status
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                try? fileManager.removeItem(at: tempLocalURL)
                return
            }
            
            let ext = (song.suffix ?? "flac").lowercased()
            let destURL = audioCacheDir.appendingPathComponent("\(song.id).\(ext)")
            
            // Atomically replace destination if existed
            if fileManager.fileExists(atPath: destURL.path) {
                try? fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: tempLocalURL, to: destURL)
        } catch {
            // Ignored - download will retry next time or stream on demand
        }
    }
    
    // MARK: - Cache Stats & Cleanup
    func cacheSizeBytes() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: audioCacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for file in files {
            if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
    
    func formattedCacheSize() -> String {
        let bytes = cacheSizeBytes()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func clearAudioCache() {
        lock.lock()
        for (_, task) in activeDownloads {
            task.cancel()
        }
        activeDownloads.removeAll()
        lock.unlock()
        
        if let files = try? fileManager.contentsOfDirectory(at: audioCacheDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
