//
//  SubsonicModels.swift
//  mpvg
//
//  Data models for Navidrome / Subsonic API v1.16+
//

import Foundation
import SwiftUI

// MARK: - Server Configuration
struct ServerConfig: Codable, Equatable, Sendable {
    var urlString: String
    var username: String
    var password: String
    var autoConnect: Bool
    var preloadQueueCount: Int
    
    nonisolated init(
        urlString: String = "http://localhost:4533",
        username: String = "admin",
        password: String = "",
        autoConnect: Bool = true,
        preloadQueueCount: Int = 5
    ) {
        self.urlString = urlString
        self.username = username
        self.password = password
        self.autoConnect = autoConnect
        self.preloadQueueCount = preloadQueueCount
    }
    
    enum CodingKeys: String, CodingKey {
        case urlString, username, password, autoConnect, preloadQueueCount
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString) ?? "http://localhost:4533"
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "admin"
        password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        autoConnect = try container.decodeIfPresent(Bool.self, forKey: .autoConnect) ?? true
        preloadQueueCount = try container.decodeIfPresent(Int.self, forKey: .preloadQueueCount) ?? 5
    }
    
    var cleanURL: URL? {
        var str = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "http://" + str
        }
        if str.hasSuffix("/") {
            str = String(str.dropLast())
        }
        return URL(string: str)
    }
}

// MARK: - Audio Device
struct AudioDeviceInfo: Identifiable, Hashable {
    let id: String         // e.g. "coreaudio/AppleUSBAudioEngine:..."
    let name: String       // e.g. "HiBy FC1"
    let driver: String     // "coreaudio", "avfoundation", or "auto"
    let isExclusiveCapable: Bool
    
    var displayName: String {
        if id == "auto" { return "Default System Device" }
        if driver.isEmpty || driver == "auto" {
            return name
        }
        let driverLabel = driver == "coreaudio" ? "CoreAudio" : (driver == "avfoundation" ? "AVFoundation" : driver.capitalized)
        return "\(name) (\(driverLabel))"
    }
}

// MARK: - Album
struct AlbumItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let title: String?
    let artist: String?
    let artistId: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Double?
    let year: Int?
    let genre: String?
    let bitRate: Int?
    let suffix: String?
    let playCount: Int?
    var userRating: Int?
    
    var displayTitle: String {
        title ?? name
    }
    
    var displayArtist: String {
        artist ?? "Unknown Artist"
    }
    
    var displayYear: String {
        if let y = year, y > 0 { return "\(y)" }
        return ""
    }
    
    var rating: Int {
        userRating ?? 0
    }
    
    var displaySpecs: String {
        var parts: [String] = []
        if let s = suffix?.uppercased(), !s.isEmpty {
            parts.append(s)
        }
        if let b = bitRate, b > 0 {
            parts.append("\(b) kbps")
        }
        if let count = songCount, count > 0 {
            parts.append("\(count) tracks")
        }
        return parts.joined(separator: " • ")
    }
    
    var formattedDuration: String {
        guard let dur = duration, dur > 0 else { return "" }
        let minutes = Int(dur) / 60
        let seconds = Int(dur) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Song / Track
struct SongItem: Identifiable, Hashable, Codable {
    let id: String
    let parent: String?
    let title: String
    let album: String?
    let artist: String?
    var artistId: String? = nil
    let track: Int?
    let year: Int?
    let genre: String?
    let coverArt: String?
    let size: Int64?
    let contentType: String?
    let suffix: String?
    let duration: Double?
    let bitRate: Int?
    let path: String?
    var userRating: Int?
    var playCount: Int? = 0
    var starred: String? = nil
    
    init(
        id: String,
        parent: String? = nil,
        title: String,
        album: String? = nil,
        artist: String? = nil,
        artistId: String? = nil,
        track: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        coverArt: String? = nil,
        size: Int64? = nil,
        contentType: String? = nil,
        suffix: String? = nil,
        duration: Double? = nil,
        bitRate: Int? = nil,
        path: String? = nil,
        userRating: Int? = nil,
        playCount: Int? = 0,
        starred: String? = nil
    ) {
        self.id = id
        self.parent = parent
        self.title = title
        self.album = album
        self.artist = artist
        self.artistId = artistId
        self.track = track
        self.year = year
        self.genre = genre
        self.coverArt = coverArt
        self.size = size
        self.contentType = contentType
        self.suffix = suffix
        self.duration = duration
        self.bitRate = bitRate
        self.path = path
        self.userRating = userRating
        self.playCount = playCount
        self.starred = starred
    }
    
    var rating: Int {
        userRating ?? 0
    }
    
    var isStarred: Bool {
        starred != nil
    }
    
    var displayArtist: String {
        artist ?? "Unknown Artist"
    }
    
    var displayAlbum: String {
        album ?? "Unknown Album"
    }
    
    var displayTrackNumber: String {
        if let t = track, t > 0 { return "\(t)" }
        return "-"
    }
    
    var formattedDuration: String {
        guard let dur = duration, dur > 0 else { return "--:--" }
        let minutes = Int(dur) / 60
        let seconds = Int(dur) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formatBadge: String {
        let suf = (suffix ?? "AUDIO").uppercased()
        if let br = bitRate, br >= 1000 {
            return "\(suf) Hi-Res"
        }
        return suf
    }
}

// MARK: - Smart Playlist Types
enum SmartPlaylistType: String, CaseIterable, Identifiable, Codable {
    case recentlyAdded = "Recently Added"
    case recentlyPlayed = "Recently Played"
    case topRated = "Top Rated"
    case unplayed = "No escuchadas"
    case mostPlayed = "Las Más Escuchadas"
    case starred = "Favoritas"
    case forgottenFavorites = "Joyas Olvidadas"
    case discoveryMix = "Mix Descubrimiento"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .recentlyAdded:
            return String(localized: "Recently Added")
        case .recentlyPlayed:
            return String(localized: "Recently Played")
        case .topRated:
            return String(localized: "Top Rated")
        case .unplayed, .mostPlayed, .starred, .forgottenFavorites, .discoveryMix:
            return rawValue
        }
    }
    
    var subtitle: String {
        switch self {
        case .recentlyAdded:
            return "Canciones añadidas recientemente a tu biblioteca"
        case .recentlyPlayed:
            return "Canciones reproducidas recientemente"
        case .topRated:
            return "Pistas mejor valoradas con 4 y 5 estrellas"
        case .unplayed:
            return "30 canciones aleatorias que nunca has reproducido"
        case .forgottenFavorites:
            return "Tus pistas favoritas o de alta calificación poco escuchadas"
        case .mostPlayed:
            return "Las 50 canciones más reproducidas de tu biblioteca"
        case .starred:
            return "Pistas marcadas como favoritas en tu colección"
        case .discoveryMix:
            return "Mix variado de 40 canciones aleatorias de tu biblioteca"
        }
    }
    
    var iconName: String {
        switch self {
        case .recentlyAdded: return "clock.arrow.circlepath"
        case .recentlyPlayed: return "play.circle.fill"
        case .topRated: return "star.fill"
        case .unplayed: return "sparkles"
        case .forgottenFavorites: return "clock.badge.checkmark"
        case .mostPlayed: return "flame.fill"
        case .starred: return "star.fill"
        case .discoveryMix: return "shuffle"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .recentlyAdded:
            return [Color(hex: "3B82F6"), Color(hex: "1D4ED8")] // Blue
        case .recentlyPlayed:
            return [Color(hex: "06B6D4"), Color(hex: "0E7490")] // Cyan
        case .topRated:
            return [Color(hex: "F59E0B"), Color(hex: "B45309")] // Amber / Gold
        case .unplayed:
            return [Color(hex: "8B5CF6"), Color(hex: "6D28D9")] // Purple / Violet
        case .forgottenFavorites:
            return [Color(hex: "F97316"), Color(hex: "C2410C")] // Orange
        case .mostPlayed:
            return [Color(hex: "EF4444"), Color(hex: "B91C1C")] // Red / Crimson
        case .starred:
            return [Color(hex: "EC4899"), Color(hex: "BE185D")] // Pink / Rose
        case .discoveryMix:
            return [Color(hex: "10B981"), Color(hex: "047857")] // Emerald / Teal
        }
    }
    
    var canRegenerate: Bool {
        switch self {
        case .unplayed, .discoveryMix, .recentlyAdded, .recentlyPlayed, .topRated:
            return true
        case .forgottenFavorites, .mostPlayed, .starred:
            return false
        }
    }
}

// MARK: - Artist
struct ArtistItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let albumCount: Int?
    let artistImageUrl: String?
}

// MARK: - Playlist
struct PlaylistItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let songCount: Int?
    let duration: Double?
    let comment: String?
    let owner: String?
    let coverArt: String?
}

// MARK: - Genre
struct GenreItem: Identifiable, Hashable, Codable {
    var id: String { value }
    let value: String
    let songCount: Int?
    let albumCount: Int?
}

// MARK: - Subsonic API Response Wrappers
struct SubsonicRootResponse<T: Codable>: Codable {
    let subsonicResponse: SubsonicResponseContainer<T>
    
    enum CodingKeys: String, CodingKey {
        case subsonicResponse = "subsonic-response"
    }
}

struct SubsonicResponseContainer<T: Codable>: Codable {
    let status: String
    let version: String
    let error: SubsonicError?
    let data: T?
    
    enum CodingKeys: String, CodingKey {
        case status, version, error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        version = try container.decode(String.self, forKey: .version)
        error = try container.decodeIfPresent(SubsonicError.self, forKey: .error)
        data = try? T(from: decoder)
    }
}

struct SubsonicError: Codable {
    let code: Int
    let message: String
}
