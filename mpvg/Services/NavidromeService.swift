//
//  NavidromeService.swift
//  mpvg
//
//  Client for Navidrome / Subsonic REST API with MD5 token authentication
//

import Foundation
import CryptoKit

actor NavidromeService {
    private var config: ServerConfig
    
    init(config: ServerConfig = ServerConfig()) {
        self.config = config
    }
    
    func updateConfig(_ newConfig: ServerConfig) {
        self.config = newConfig
    }
    
    // MARK: - Auth Helpers
    private func buildURL(endpoint: String, extraParams: [String: String] = [:]) -> URL? {
        guard let baseURL = config.cleanURL else { return nil }
        guard var components = URLComponents(url: baseURL.appendingPathComponent("rest/\(endpoint)"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let salt = UUID().uuidString.prefix(8).lowercased()
        let tokenInput = "\(config.password)\(salt)"
        let tokenHash = Insecure.MD5.hash(data: Data(tokenInput.utf8))
        let token = tokenHash.map { String(format: "%02hhx", $0) }.joined()
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "s", value: String(salt)),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "mpvg"),
            URLQueryItem(name: "f", value: "json")
        ]
        
        for (key, value) in extraParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    // MARK: - Ping / Test Connection
    func ping() async -> Result<String, Error> {
        guard let url = buildURL(endpoint: "ping.view") else {
            return .failure(NSError(domain: "Navidrome", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"]))
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failure(NSError(domain: "Navidrome", code: 500, userInfo: [NSLocalizedDescriptionKey: "HTTP Error"]))
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sub = json["subsonic-response"] as? [String: Any],
               let status = sub["status"] as? String, status == "ok" {
                let version = sub["version"] as? String ?? "1.16.1"
                return .success("Connected successfully (Subsonic v\(version))")
            } else {
                return .failure(NSError(domain: "Navidrome", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed or invalid response"]))
            }
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Get Albums
    func getAlbums(type: String = "recent", size: Int = 30, genre: String? = nil) async -> [AlbumItem] {
        var params: [String: String] = [
            "type": type,
            "size": "\(size)"
        ]
        if let genre = genre, !genre.isEmpty {
            params["genre"] = genre
        }
        
        guard let url = buildURL(endpoint: "getAlbumList2.view", extraParams: params) else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let listWrapper = sub["albumList2"] as? [String: Any],
                  let rawAlbums = listWrapper["album"] as? [[String: Any]] else {
                return []
            }
            
            var albums: [AlbumItem] = []
            for item in rawAlbums {
                if let id = item["id"] as? String,
                   let name = (item["name"] as? String) ?? (item["title"] as? String) {
                    let album = AlbumItem(
                        id: id,
                        name: name,
                        title: item["title"] as? String,
                        artist: item["artist"] as? String,
                        artistId: item["artistId"] as? String,
                        coverArt: item["coverArt"] as? String,
                        songCount: item["songCount"] as? Int,
                        duration: item["duration"] as? Double,
                        year: item["year"] as? Int,
                        genre: item["genre"] as? String,
                        bitRate: item["bitRate"] as? Int,
                        suffix: item["suffix"] as? String,
                        playCount: item["playCount"] as? Int,
                        userRating: (item["userRating"] as? Int) ?? (item["rating"] as? Int)
                    )
                    albums.append(album)
                }
            }
            return albums
        } catch {
            print("Error cargando álbumes: \(error)")
            return []
        }
    }
    
    // MARK: - Get All Albums (Paginated to fetch entire collection)
    func getAllAlbums(type: String = "alphabeticalByArtist", maxLimit: Int = 5000) async -> [AlbumItem] {
        var allAlbums: [AlbumItem] = []
        var offset = 0
        let pageSize = 500
        
        while offset < maxLimit {
            let params: [String: String] = [
                "type": type,
                "size": "\(pageSize)",
                "offset": "\(offset)"
            ]
            
            guard let url = buildURL(endpoint: "getAlbumList2.view", extraParams: params) else { break }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let sub = json["subsonic-response"] as? [String: Any],
                      let listWrapper = sub["albumList2"] as? [String: Any],
                      let rawAlbums = listWrapper["album"] as? [[String: Any]],
                      !rawAlbums.isEmpty else {
                    break
                }
                
                for item in rawAlbums {
                    if let id = item["id"] as? String,
                       let name = (item["name"] as? String) ?? (item["title"] as? String) {
                        let album = AlbumItem(
                            id: id,
                            name: name,
                            title: item["title"] as? String,
                            artist: item["artist"] as? String,
                            artistId: item["artistId"] as? String,
                            coverArt: item["coverArt"] as? String,
                            songCount: item["songCount"] as? Int,
                            duration: item["duration"] as? Double,
                            year: item["year"] as? Int,
                            genre: item["genre"] as? String,
                            bitRate: item["bitRate"] as? Int,
                            suffix: item["suffix"] as? String,
                            playCount: item["playCount"] as? Int,
                            userRating: (item["userRating"] as? Int) ?? (item["rating"] as? Int)
                        )
                        if !allAlbums.contains(where: { $0.id == album.id }) {
                            allAlbums.append(album)
                        }
                    }
                }
                
                if rawAlbums.count < pageSize {
                    break
                }
                offset += pageSize
            } catch {
                break
            }
        }
        
        return allAlbums
    }
    
    // MARK: - Get Artists
    func getArtists() async -> [ArtistItem] {
        guard let url = buildURL(endpoint: "getArtists.view") else {
            return []
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let artistsContainer = sub["artists"] as? [String: Any],
                  let indexList = artistsContainer["index"] as? [[String: Any]] else {
                return []
            }
            
            var artists: [ArtistItem] = []
            for idx in indexList {
                if let rawList = idx["artist"] as? [[String: Any]] {
                    for a in rawList {
                        if let id = a["id"] as? String, let name = a["name"] as? String {
                            artists.append(ArtistItem(
                                id: id,
                                name: name,
                                albumCount: a["albumCount"] as? Int,
                                artistImageUrl: a["artistImageUrl"] as? String
                            ))
                        }
                    }
                }
            }
            return artists
        } catch {
            print("Error loading artists: \(error)")
            return []
        }
    }
    
    // MARK: - Get Artist Details & Albums
    func getArtist(id: String) async -> (ArtistItem?, [AlbumItem]) {
        guard let url = buildURL(endpoint: "getArtist.view", extraParams: ["id": id]) else {
            return (nil, [])
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let artistDict = sub["artist"] as? [String: Any] else {
                return (nil, [])
            }
            
            let artist = ArtistItem(
                id: artistDict["id"] as? String ?? id,
                name: artistDict["name"] as? String ?? "Artist",
                albumCount: artistDict["albumCount"] as? Int,
                artistImageUrl: artistDict["artistImageUrl"] as? String
            )
            
            var albums: [AlbumItem] = []
            if let rawAlbums = artistDict["album"] as? [[String: Any]] {
                for a in rawAlbums {
                    if let aid = a["id"] as? String, let title = a["title"] as? String ?? a["name"] as? String {
                        albums.append(AlbumItem(
                            id: aid,
                            name: title,
                            title: title,
                            artist: a["artist"] as? String ?? artist.name,
                            artistId: a["artistId"] as? String ?? id,
                            coverArt: a["coverArt"] as? String,
                            songCount: a["songCount"] as? Int,
                            duration: a["duration"] as? Double,
                            year: a["year"] as? Int,
                            genre: a["genre"] as? String,
                            bitRate: a["bitRate"] as? Int,
                            suffix: a["suffix"] as? String,
                            playCount: a["playCount"] as? Int,
                            userRating: (a["userRating"] as? Int) ?? (a["rating"] as? Int)
                        ))
                    }
                }
            }
            return (artist, albums)
        } catch {
            print("Error loading artist details: \(error)")
            return (nil, [])
        }
    }
    
    // MARK: - Get Album Details (Tracks)
    func getAlbum(id: String) async -> (AlbumItem?, [SongItem]) {
        guard let url = buildURL(endpoint: "getAlbum.view", extraParams: ["id": id]) else {
            return (nil, [])
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let albumDict = sub["album"] as? [String: Any] else {
                return (nil, [])
            }
            
            let album = AlbumItem(
                id: albumDict["id"] as? String ?? id,
                name: albumDict["name"] as? String ?? "Álbum",
                title: albumDict["title"] as? String,
                artist: albumDict["artist"] as? String,
                artistId: albumDict["artistId"] as? String,
                coverArt: albumDict["coverArt"] as? String,
                songCount: albumDict["songCount"] as? Int,
                duration: albumDict["duration"] as? Double,
                year: albumDict["year"] as? Int,
                genre: albumDict["genre"] as? String,
                bitRate: albumDict["bitRate"] as? Int,
                suffix: albumDict["suffix"] as? String,
                playCount: albumDict["playCount"] as? Int,
                userRating: (albumDict["userRating"] as? Int) ?? (albumDict["rating"] as? Int)
            )
            
            var songs: [SongItem] = []
            if let songList = albumDict["song"] as? [[String: Any]] {
                for s in songList {
                    if let sid = s["id"] as? String, let title = s["title"] as? String {
                        let song = SongItem(
                            id: sid,
                            parent: s["parent"] as? String,
                            title: title,
                            album: s["album"] as? String ?? album.displayTitle,
                            artist: s["artist"] as? String ?? album.displayArtist,
                            track: s["track"] as? Int,
                            year: s["year"] as? Int ?? album.year,
                            genre: s["genre"] as? String ?? album.genre,
                            coverArt: s["coverArt"] as? String ?? album.coverArt,
                            size: (s["size"] as? NSNumber)?.int64Value,
                            contentType: s["contentType"] as? String,
                            suffix: s["suffix"] as? String,
                            duration: s["duration"] as? Double,
                            bitRate: s["bitRate"] as? Int,
                            path: s["path"] as? String,
                            userRating: (s["userRating"] as? Int) ?? (s["rating"] as? Int)
                        )
                        songs.append(song)
                    }
                }
            }
            return (album, songs)
        } catch {
            print("Error cargando detalle de álbum: \(error)")
            return (nil, [])
        }
    }
    
    // MARK: - Search
    func search(query: String) async -> (artists: [ArtistItem], albums: [AlbumItem], songs: [SongItem]) {
        guard let url = buildURL(endpoint: "search3.view", extraParams: ["query": query, "songCount": "20", "albumCount": "20", "artistCount": "10"]) else {
            return ([], [], [])
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let result = sub["searchResult3"] as? [String: Any] else {
                return ([], [], [])
            }
            
            var artists: [ArtistItem] = []
            if let rawArtists = result["artist"] as? [[String: Any]] {
                for a in rawArtists {
                    if let id = a["id"] as? String, let name = a["name"] as? String {
                        artists.append(ArtistItem(id: id, name: name, albumCount: a["albumCount"] as? Int, artistImageUrl: a["artistImageUrl"] as? String))
                    }
                }
            }
            
            var albums: [AlbumItem] = []
            if let rawAlbums = result["album"] as? [[String: Any]] {
                for a in rawAlbums {
                    if let id = a["id"] as? String, let name = (a["name"] as? String) ?? (a["title"] as? String) {
                        albums.append(AlbumItem(
                            id: id,
                            name: name,
                            title: a["title"] as? String,
                            artist: a["artist"] as? String,
                            artistId: a["artistId"] as? String,
                            coverArt: a["coverArt"] as? String,
                            songCount: a["songCount"] as? Int,
                            duration: a["duration"] as? Double,
                            year: a["year"] as? Int,
                            genre: a["genre"] as? String,
                            bitRate: a["bitRate"] as? Int,
                            suffix: a["suffix"] as? String,
                            playCount: a["playCount"] as? Int,
                            userRating: (a["userRating"] as? Int) ?? (a["rating"] as? Int)
                        ))
                    }
                }
            }
            
            var songs: [SongItem] = []
            if let rawSongs = result["song"] as? [[String: Any]] {
                for s in rawSongs {
                    if let id = s["id"] as? String, let title = s["title"] as? String {
                        songs.append(SongItem(
                            id: id,
                            parent: s["parent"] as? String,
                            title: title,
                            album: s["album"] as? String,
                            artist: s["artist"] as? String,
                            track: s["track"] as? Int,
                            year: s["year"] as? Int,
                            genre: s["genre"] as? String,
                            coverArt: s["coverArt"] as? String,
                            size: (s["size"] as? NSNumber)?.int64Value,
                            contentType: s["contentType"] as? String,
                            suffix: s["suffix"] as? String,
                            duration: s["duration"] as? Double,
                            bitRate: s["bitRate"] as? Int,
                            path: s["path"] as? String,
                            userRating: (s["userRating"] as? Int) ?? (s["rating"] as? Int)
                        ))
                    }
                }
            }
            
            return (artists, albums, songs)
        } catch {
            return ([], [], [])
        }
    }
    
    // MARK: - Set Rating (0-5 stars)
    func setRating(id: String, rating: Int) async -> Bool {
        let clamped = max(0, min(5, rating))
        guard let url = buildURL(endpoint: "setRating.view", extraParams: ["id": id, "rating": "\(clamped)"]) else {
            return false
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let status = sub["status"] as? String else {
                return false
            }
            return status == "ok"
        } catch {
            print("Error setting rating: \(error)")
            return false
        }
    }
    
    // MARK: - Stream & Cover Art URLs
    func streamURL(for songId: String) -> URL? {
        buildURL(endpoint: "stream.view", extraParams: ["id": songId, "format": "raw"])
    }
    
    func coverArtURL(for id: String, size: Int = 300) -> URL? {
        buildURL(endpoint: "getCoverArt.view", extraParams: ["id": id, "size": "\(size)"])
    }
    
    // MARK: - Scrobble
    func scrobble(songId: String, submission: Bool = true) async {
        guard let url = buildURL(endpoint: "scrobble.view", extraParams: ["id": songId, "submission": submission ? "true" : "false"]) else { return }
        _ = try? await URLSession.shared.data(from: url)
    }
}
