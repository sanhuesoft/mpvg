//
//  Track.swift
//  mpvg
//
//  Created by Fabián Sanhueza on 30-08-26.
//


import Foundation
import AVFoundation

struct Track: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let title: String
    let artist: String
    let album: String
    let trackNumber: Int
    let duration: Double
}

final class LibraryScanner {
    static func scanDirectory(at rootURL: URL) async -> [Track] {
        var tracks: [Track] = []
        let supportedExtensions = ["flac", "wav", "aiff", "alac", "m4a", "mp3"]
        
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        for case let fileURL as URL in enumerator {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                let asset = AVURLAsset(url: fileURL)
                let metadata = try? await asset.load(.metadata)
                
                var title = fileURL.deletingPathExtension().lastPathComponent
                var artist = "Desconocido"
                var album = "Desconocido"
                var trackNumber = 0
                
                if let metadata = metadata {
                    for item in metadata {
                        guard let commonKey = item.commonKey?.rawValue,
                              let stringValue = try? await item.load(.stringValue) else { continue }
                        
                        switch commonKey {
                        case "title": title = stringValue
                        case "artist": artist = stringValue
                        case "albumName": album = stringValue
                        default: break
                        }
                    }
                }
                
                let duration = (try? await asset.load(.duration).seconds) ?? 0.0
                tracks.append(Track(url: fileURL, title: title, artist: artist, album: album, trackNumber: trackNumber, duration: duration))
            }
        }
        return tracks
    }
}