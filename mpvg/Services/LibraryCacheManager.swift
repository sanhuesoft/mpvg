//
//  LibraryCacheManager.swift
//  mpvg
//
//  Fast local disk persistence for catalog items (albums, artists, playlists, genres)
//  to guarantee instantaneous startup without flashing demo content.
//

import Foundation

struct LibraryCacheData: Codable {
    let albums: [AlbumItem]
    let featuredAlbums: [AlbumItem]
    let recentAlbums: [AlbumItem]
    let artists: [ArtistItem]
    let playlists: [PlaylistItem]
    let genres: [GenreItem]
    let savedAt: Date
}

final class LibraryCacheManager {
    static let shared = LibraryCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheURL: URL
    private let queue = DispatchQueue(label: "com.sanhuesoft.mpvg.librarycache", qos: .utility)
    
    private init() {
        let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        
        let appDir = baseDir.appendingPathComponent("mpvg", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        self.cacheURL = appDir.appendingPathComponent("library_cache.json")
    }
    
    func hasCache() -> Bool {
        fileManager.fileExists(atPath: cacheURL.path)
    }
    
    func loadCache() -> LibraryCacheData? {
        guard fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }
        do {
            let decoded = try JSONDecoder().decode(LibraryCacheData.self, from: data)
            return decoded
        } catch {
            print("Error decoding library cache: \(error)")
            return nil
        }
    }
    
    func saveCache(
        albums: [AlbumItem],
        featuredAlbums: [AlbumItem],
        recentAlbums: [AlbumItem],
        artists: [ArtistItem],
        playlists: [PlaylistItem],
        genres: [GenreItem]
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let cacheData = LibraryCacheData(
                albums: albums,
                featuredAlbums: featuredAlbums,
                recentAlbums: recentAlbums,
                artists: artists,
                playlists: playlists,
                genres: genres,
                savedAt: Date()
            )
            do {
                let encoded = try JSONEncoder().encode(cacheData)
                try encoded.write(to: self.cacheURL, options: .atomic)
            } catch {
                print("Error saving library cache: \(error)")
            }
        }
    }
    
    func clearCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.cacheURL)
        }
    }
}
