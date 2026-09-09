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
    private var sessionSalt: String = "mpvg_salt"
    private var sessionToken: String = ""
    private var tokenCachedForPassword: String = ""

    init(config: ServerConfig = ServerConfig()) {
        self.config = config
    }
    
    func updateConfig(_ newConfig: ServerConfig) {
        self.config = newConfig
        self.sessionToken = ""
    }
    
    private func ensureToken() {
        if sessionToken.isEmpty || tokenCachedForPassword != config.password {
            let tokenInput = "\(config.password)\(sessionSalt)"
            let tokenHash = Insecure.MD5.hash(data: Data(tokenInput.utf8))
            self.sessionToken = tokenHash.map { String(format: "%02hhx", $0) }.joined()
            self.tokenCachedForPassword = config.password
        }
    }
    
    // MARK: - Auth Helpers
    private func buildURL(endpoint: String, extraParams: [String: String] = [:]) -> URL? {
        guard let baseURL = config.cleanURL else { return nil }
        guard var components = URLComponents(url: baseURL.appendingPathComponent("rest/\(endpoint)"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        ensureToken()
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "u", value: config.username),
            URLQueryItem(name: "t", value: sessionToken),
            URLQueryItem(name: "s", value: sessionSalt),
            URLQueryItem(name: "v", value: "1.16.1"),
            URLQueryItem(name: "c", value: "mpvg")
        ]
        
        let isBinaryEndpoint = endpoint.contains("stream") || endpoint.contains("CoverArt") || endpoint.contains("Avatar")
        if !isBinaryEndpoint {
            queryItems.append(URLQueryItem(name: "f", value: "json"))
        }
        
        for (key, value) in extraParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    // MARK: - Library Rescan
    func startScan() async -> Bool {
        guard let url = buildURL(endpoint: "startScan.view") else { return false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let status = sub["status"] as? String else {
                return false
            }
            return status == "ok"
        } catch {
            print("Error triggering library scan: \(error)")
            return false
        }
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
                            parent: (s["parent"] as? String) ?? (s["albumId"] as? String) ?? album.id,
                            title: title,
                            album: s["album"] as? String ?? album.displayTitle,
                            artist: s["artist"] as? String ?? album.displayArtist,
                            artistId: (s["artistId"] as? String) ?? album.artistId,
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
                            parent: (s["parent"] as? String) ?? (s["albumId"] as? String),
                            title: title,
                            album: s["album"] as? String,
                            artist: s["artist"] as? String,
                            artistId: s["artistId"] as? String,
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
    
    // MARK: - Playlists & Genres
    func getPlaylists() async -> [PlaylistItem] {
        guard let url = buildURL(endpoint: "getPlaylists.view") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let listWrapper = sub["playlists"] as? [String: Any],
                  let rawPlaylists = listWrapper["playlist"] as? [[String: Any]] else {
                return []
            }
            
            var playlists: [PlaylistItem] = []
            for item in rawPlaylists {
                if let id = item["id"] as? String, let name = item["name"] as? String {
                    playlists.append(PlaylistItem(
                        id: id,
                        name: name,
                        songCount: item["songCount"] as? Int,
                        duration: item["duration"] as? Double,
                        comment: item["comment"] as? String,
                        owner: item["owner"] as? String,
                        coverArt: item["coverArt"] as? String
                    ))
                }
            }
            return playlists
        } catch {
            return []
        }
    }
    
    func getPlaylist(id: String) async -> (PlaylistItem?, [SongItem]) {
        guard let url = buildURL(endpoint: "getPlaylist.view", extraParams: ["id": id]) else {
            return (nil, [])
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let playlistDict = sub["playlist"] as? [String: Any] else {
                return (nil, [])
            }
            let playlist = PlaylistItem(
                id: playlistDict["id"] as? String ?? id,
                name: playlistDict["name"] as? String ?? "Playlist",
                songCount: playlistDict["songCount"] as? Int,
                duration: playlistDict["duration"] as? Double,
                comment: playlistDict["comment"] as? String,
                owner: playlistDict["owner"] as? String,
                coverArt: playlistDict["coverArt"] as? String
            )
            var songs: [SongItem] = []
            if let songList = (playlistDict["entry"] as? [[String: Any]]) ?? (playlistDict["song"] as? [[String: Any]]) {
                for s in songList {
                    if let sid = s["id"] as? String, let title = s["title"] as? String {
                        let song = SongItem(
                            id: sid,
                            parent: (s["parent"] as? String) ?? (s["albumId"] as? String),
                            title: title,
                            album: s["album"] as? String ?? "",
                            artist: s["artist"] as? String ?? "",
                            artistId: s["artistId"] as? String,
                            track: s["track"] as? Int,
                            year: s["year"] as? Int,
                            genre: s["genre"] as? String,
                            coverArt: s["coverArt"] as? String ?? playlist.coverArt,
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
            return (playlist, songs)
        } catch {
            return (nil, [])
        }
    }
    
    func getGenres() async -> [GenreItem] {
        guard let url = buildURL(endpoint: "getGenres.view") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sub = json["subsonic-response"] as? [String: Any],
                  let listWrapper = sub["genres"] as? [String: Any],
                  let rawGenres = listWrapper["genre"] as? [[String: Any]] else {
                return []
            }
            
            var genres: [GenreItem] = []
            for item in rawGenres {
                if let value = (item["value"] as? String) ?? (item["name"] as? String), !value.isEmpty {
                    genres.append(GenreItem(
                        value: value,
                        songCount: item["songCount"] as? Int,
                        albumCount: item["albumCount"] as? Int
                    ))
                }
            }
            return genres
        } catch {
            return []
        }
    }
    
    // MARK: - Stream & Cover Art URLs
    func streamURL(for songId: String) -> URL? {
        buildURL(endpoint: "stream.view", extraParams: ["id": songId, "format": "raw"])
    }
    
    func coverArtURL(for id: String, size: Int = 300) -> URL? {
        buildURL(endpoint: "getCoverArt.view", extraParams: ["id": id, "size": "\(size)"])
    }
    
    func artistArtworkURL(for artist: ArtistItem) -> URL? {
        if let raw = artist.artistImageUrl, !raw.isEmpty {
            if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
                if let url = URL(string: raw) {
                    if let host = config.cleanURL?.host, url.host == host {
                        if url.query?.contains("u=") == true {
                            return url
                        }
                        ensureToken()
                        var comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        var q = comp?.queryItems ?? []
                        q.append(contentsOf: [
                            URLQueryItem(name: "u", value: config.username),
                            URLQueryItem(name: "t", value: sessionToken),
                            URLQueryItem(name: "s", value: sessionSalt),
                            URLQueryItem(name: "v", value: "1.16.1"),
                            URLQueryItem(name: "c", value: "mpvg")
                        ])
                        comp?.queryItems = q
                        return comp?.url ?? url
                    }
                    return url
                }
            } else if raw.hasPrefix("/") {
                if let base = config.cleanURL {
                    let full = base.appendingPathComponent(raw.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
                    ensureToken()
                    var comp = URLComponents(url: full, resolvingAgainstBaseURL: false)
                    comp?.queryItems = [
                        URLQueryItem(name: "u", value: config.username),
                        URLQueryItem(name: "t", value: sessionToken),
                        URLQueryItem(name: "s", value: sessionSalt),
                        URLQueryItem(name: "v", value: "1.16.1"),
                        URLQueryItem(name: "c", value: "mpvg")
                    ]
                    return comp?.url
                }
            }
        }
        
        return coverArtURL(for: artist.id)
    }
    
    // MARK: - Scrobble
    func scrobble(songId: String, submission: Bool = true) async {
        guard let url = buildURL(endpoint: "scrobble.view", extraParams: ["id": songId, "submission": submission ? "true" : "false"]) else { return }
        _ = try? await URLSession.shared.data(from: url)
    }
}
