//
//  PlayerViewModel.swift
//  mpvg
//
//  Central state coordinator between NavidromeService, MPVProcessManager,
//  MediaKeyController, and SwiftUI Views.
//

import Foundation
import Combine
import SwiftUI
import CryptoKit

enum SidebarTab: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case recentlyAdded = "Recently Added"
    case recentlyPlayed = "Recently Played"
    case topRated = "Top Rated"
    case unplayed = "No escuchadas"
    case forgottenFavorites = "Joyas Olvidadas"
    case mostPlayed = "Las Más Escuchadas"
    case starred = "Favoritas"
    case discoveryMix = "Mix Descubrimiento"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"
    case genres = "Genres"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .browse: return "square.grid.2x2"
        case .recentlyAdded: return "clock.arrow.circlepath"
        case .recentlyPlayed: return "play.circle"
        case .topRated: return "star.fill"
        case .unplayed: return "sparkles"
        case .forgottenFavorites: return "clock.badge.checkmark"
        case .mostPlayed: return "flame.fill"
        case .starred: return "star.fill"
        case .discoveryMix: return "shuffle"
        case .albums: return "opticaldisc"
        case .artists: return "music.mic"
        case .playlists: return "music.note.list"
        case .genres: return "tag"
        case .settings: return "gearshape"
        }
    }
    
    var asSmartPlaylistType: SmartPlaylistType? {
        switch self {
        case .recentlyAdded: return .recentlyAdded
        case .recentlyPlayed: return .recentlyPlayed
        case .topRated: return .topRated
        case .unplayed: return .unplayed
        case .forgottenFavorites: return .forgottenFavorites
        case .mostPlayed: return .mostPlayed
        case .starred: return .starred
        case .discoveryMix: return .discoveryMix
        default: return nil
        }
    }
}

enum ViewMode: String {
    case grid
    case list
}

enum SpotlightScope: String, CaseIterable, Identifiable {
    case artists = "Artistas"
    case albums = "Álbumes"
    case songs = "Canciones"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .artists: return "music.mic"
        case .albums: return "square.stack"
        case .songs: return "music.note"
        }
    }
}

enum NavigationDestination: Identifiable, Equatable, Hashable {
    case album(AlbumItem)
    case artist(ArtistItem)
    case smartPlaylist(SmartPlaylistType)
    
    var id: String {
        switch self {
        case .album(let album): return "album-\(album.id)"
        case .artist(let artist): return "artist-\(artist.id)"
        case .smartPlaylist(let type): return "smart-\(type.id)"
        }
    }
}

extension SmartPlaylistType {
    var asSidebarTab: SidebarTab {
        switch self {
        case .recentlyAdded: return .recentlyAdded
        case .recentlyPlayed: return .recentlyPlayed
        case .topRated: return .topRated
        case .unplayed: return .unplayed
        case .forgottenFavorites: return .forgottenFavorites
        case .mostPlayed: return .mostPlayed
        case .starred: return .starred
        case .discoveryMix: return .discoveryMix
        }
    }
}

#if os(macOS)
typealias AudioEngine = MPVProcessManager
#else
typealias AudioEngine = IOSAudioEngine
#endif

@MainActor
final class PlayerViewModel: ObservableObject {
    static weak var shared: PlayerViewModel?
    
    @Published var appAccentColor: String = UserDefaults.standard.string(forKey: "appAccentColor") ?? "terracotta"
    
    func setAccentColor(_ accent: PrimaryAccent) {
        UserDefaults.standard.set(accent.rawValue, forKey: "appAccentColor")
        self.appAccentColor = accent.rawValue
        self.objectWillChange.send()
    }
    
    @Published var activeTab: SidebarTab = .browse {
        didSet {
            if oldValue != activeTab {
                navigationStack.removeAll()
                if !searchQuery.isEmpty {
                    searchQuery = ""
                }
            }
        }
    }
    @Published var viewMode: ViewMode = .grid
    @Published var searchQuery: String = ""
    @Published var focusSearchTrigger: Bool = false
    
    func focusSearch() {
        focusSearchTrigger.toggle()
    }
    
    func selectTab(_ tab: SidebarTab) {
        if !searchQuery.isEmpty {
            searchQuery = ""
        }
        if activeTab != tab {
            activeTab = tab
        } else {
            navigationStack.removeAll()
        }
    }
    @Published var isSidebarVisible: Bool = true
    @Published var tabBarShowsLabels: Bool = UserDefaults.standard.object(forKey: "tabBarShowsLabels") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(tabBarShowsLabels, forKey: "tabBarShowsLabels")
        }
    }
    
    // In-window Navigation Stack
    @Published var navigationStack: [NavigationDestination] = []
    @Published var requestedDestination: NavigationDestination? = nil
    
    // Connection
    @Published var serverConfig: ServerConfig {
        didSet {
            saveConfig()
        }
    }
    @Published var isConnected: Bool = false
    @Published var connectionStatusMessage: String = "Not connected"
    @Published var isTestingConnection: Bool = false
    @Published var isSyncingLibrary: Bool = false
    @Published var isDisconnectedOverlayVisible: Bool = false
    @Published var showSettingsSheet: Bool = false
    
    // Internal grace period and health check management
    private var isInitialGracePeriodActive: Bool = true
    private var periodicHealthCheckTask: Task<Void, Never>? = nil
    
    // Catalogs
    @Published var albums: [AlbumItem] = []
    @Published var featuredAlbums: [AlbumItem] = []
    @Published var recentAlbums: [AlbumItem] = []
    @Published var recentlyPlayedAlbums: [AlbumItem] = []
    @Published var artists: [ArtistItem] = []
    @Published var playlists: [PlaylistItem] = []
    @Published var genres: [GenreItem] = []
    
    // Smart Playlists (Songs)
    @Published var smartPlaylistSongs: [SmartPlaylistType: [SongItem]] = [:]
    @Published var isLoadingSmartPlaylist: [SmartPlaylistType: Bool] = [:]
    
    var unplayedSongs: [SongItem] {
        smartPlaylistSongs[.unplayed] ?? []
    }
    
    /// Returns albums with a 4 or 5-star rating, sorted by rating descending
    var topRatedAlbums: [AlbumItem] {
        albums.filter { ($0.userRating ?? 0) >= 4 }
            .sorted {
                let r1 = $0.userRating ?? 0
                let r2 = $1.userRating ?? 0
                if r1 != r2 {
                    return r1 > r2
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }
    
    // Search Results
    @Published var searchAlbums: [AlbumItem] = []
    @Published var searchSongs: [SongItem] = []
    
    // Spotlight Search (macOS)
    @Published var isSpotlightPresented: Bool = false
    @Published var spotlightQuery: String = ""
    @Published var spotlightScope: SpotlightScope? = nil
    @Published var spotlightArtists: [ArtistItem] = []
    @Published var spotlightAlbums: [AlbumItem] = []
    @Published var spotlightSongs: [SongItem] = []
    @Published var isSpotlightLoading: Bool = false
    private var spotlightSearchTask: Task<Void, Never>? = nil
    
    // Playback
    @Published var currentSong: SongItem?
    @Published var currentAlbum: AlbumItem?
    @Published var queue: [SongItem] = []
    @Published var queueIndex: Int = 0
    @Published var showQueueSheet: Bool = false
    
    // Selection / Sheets
    @Published var selectedAlbumForDetail: AlbumItem?
    @Published var selectedAlbumTracks: [SongItem] = []
    @Published var isLoadingTracks: Bool = false
    
    @Published var selectedArtistForDetail: ArtistItem?
    @Published var selectedArtistAlbums: [AlbumItem] = []
    @Published var isLoadingArtistAlbums: Bool = false
    
    // Track loading & Toast
    @Published var isLoadingTrack: Bool = false
    @Published var toastMessage: String? = nil
    private var toastTimer: Task<Void, Never>? = nil
    
    // Dependencies
    @Published var mpv: AudioEngine
    private var navidrome: NavidromeService
    private var cancellables = Set<AnyCancellable>()
    
    init(mpv: AudioEngine? = nil) {
        let processManager = mpv ?? AudioEngine()
        self.mpv = processManager
        let saved = Self.loadConfig()
        self.serverConfig = saved
        self.navidrome = NavidromeService(config: saved)
        Self.shared = self
        
        // Hydrate library from local disk cache if available to prevent demo content flash
        if let cached = LibraryCacheManager.shared.loadCache() {
            self.albums = cached.albums
            self.featuredAlbums = cached.featuredAlbums
            self.recentAlbums = cached.recentAlbums
            self.recentlyPlayedAlbums = cached.recentlyPlayedAlbums ?? []
            self.artists = cached.artists
            self.playlists = cached.playlists
            self.genres = cached.genres
            if let smart = cached.smartPlaylists {
                var restored: [SmartPlaylistType: [SongItem]] = [:]
                for (k, v) in smart {
                    if let type = SmartPlaylistType(rawValue: k) {
                        restored[type] = v
                    }
                }
                self.smartPlaylistSongs = restored
            }
        } else if saved.password.isEmpty {
            // Only populate sample catalog on a fresh unconfigured installation
            loadSampleCatalog()
        }
        
        updateSessionAuth()
        
        // Continuous playback: automatically play the next track in queue when a song finishes
        processManager.onTrackFinished = { [weak self] in
            Task { @MainActor [weak self] in
                self?.nextTrack()
            }
        }
        
        // Playback failure notification from audio engine
        processManager.onPlaybackError = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handlePlaybackFailure()
            }
        }
        
        // Forward discrete state changes from mpv (do NOT forward high-frequency currentTime ticks)
        processManager.$isPaused
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        processManager.$currentDevice
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        processManager.$isExclusive
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        processManager.$isRunning
            .dropFirst()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // Forward currentTime ticks at a throttled rate so the elapsed time
        // label in PlayerBarView stays in sync without hammering the UI
        processManager.$currentTime
            .throttle(for: .milliseconds(250), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // Configure macOS System Media Keys & Now Playing
        MediaKeyController.shared.configure(with: self)
        
        // Auto connect if configured
        if saved.autoConnect && !saved.password.isEmpty {
            Task {
                await testConnection()
            }
        }
        
        // Startup grace period: suppress disconnected overlay for 10 seconds during launch
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            guard let self = self else { return }
            self.isInitialGracePeriodActive = false
            if !self.isConnected && !self.serverConfig.urlString.isEmpty && !self.serverConfig.password.isEmpty {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self.isDisconnectedOverlayVisible = true
                }
            }
        }
        
        // Start background periodic health check (every 30 seconds)
        startPeriodicHealthCheck()
        
        // Listen to search query changes with debounce
        $searchQuery
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
            
        // Listen to Spotlight search query changes with fast debounce (250ms)
        $spotlightQuery
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSpotlightSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    private static let configKey = "NavidromeServerConfig"
    
    private static func loadConfig() -> ServerConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return ServerConfig()
        }
        return config
    }
    
    private func saveConfig() {
        updateSessionAuth()
        if let data = try? JSONEncoder().encode(serverConfig) {
            UserDefaults.standard.set(data, forKey: Self.configKey)
        }
        Task {
            await navidrome.updateConfig(serverConfig)
        }
    }
    
    // MARK: - Server Connection
    func testConnection() async {
        isTestingConnection = true
        let result = await navidrome.ping()
        isTestingConnection = false
        
        switch result {
        case .success(let msg):
            self.isConnected = true
            self.connectionStatusMessage = msg
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                self.isDisconnectedOverlayVisible = false
            }
            await loadLibrary()
        case .failure(let err):
            self.isConnected = false
            self.connectionStatusMessage = "Error: \(err.localizedDescription)"
            if !self.isInitialGracePeriodActive && !self.serverConfig.urlString.isEmpty {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self.isDisconnectedOverlayVisible = true
                }
            }
        }
    }
    
    // MARK: - Periodic Health Check
    private func startPeriodicHealthCheck() {
        periodicHealthCheckTask?.cancel()
        periodicHealthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard let self = self, !Task.isCancelled else { break }
                await self.performPeriodicConnectionCheck()
            }
        }
    }
    
    func performPeriodicConnectionCheck() async {
        guard !serverConfig.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let result = await navidrome.ping()
        switch result {
        case .success(let msg):
            let wasDisconnected = !self.isConnected
            self.isConnected = true
            self.connectionStatusMessage = msg
            if wasDisconnected || self.isDisconnectedOverlayVisible {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self.isDisconnectedOverlayVisible = false
                }
                if albums.isEmpty {
                    await loadLibrary()
                }
            }
        case .failure(let err):
            self.isConnected = false
            self.connectionStatusMessage = "Error: \(err.localizedDescription)"
            if !self.isInitialGracePeriodActive {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    self.isDisconnectedOverlayVisible = true
                }
            }
        }
    }
    
    // MARK: - Playback Failure Handling
    func handlePlaybackFailure(for song: SongItem? = nil) async {
        self.isLoadingTrack = false
        guard !serverConfig.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let result = await navidrome.ping()
        switch result {
        case .success:
            let targetSong = song ?? currentSong
            if let title = targetSong?.title {
                showToast("No se pudo reproducir \"\(title)\". Verifica el archivo en el servidor.")
            }
        case .failure(let err):
            self.isConnected = false
            self.connectionStatusMessage = "Error: \(err.localizedDescription)"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                self.isDisconnectedOverlayVisible = true
            }
        }
    }
    
    // MARK: - Navigation & Overlay Helpers
    func openSettings() {
        #if os(macOS)
        selectTab(.settings)
        #else
        showSettingsSheet = true
        #endif
    }
    
    func dismissDisconnectedOverlay() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            self.isDisconnectedOverlayVisible = false
        }
    }
    
    func loadLibrary() async {
        guard isConnected else { return }
        
        async let recent = navidrome.getAlbums(type: "newest", size: 30)
        async let recentPlayed = navidrome.getAlbums(type: "recent", size: 30)
        async let frequent = navidrome.getAlbums(type: "frequent", size: 24)
        async let allAlb = navidrome.getAllAlbums(type: "alphabeticalByArtist")
        async let arts = navidrome.getArtists()
        async let pls = navidrome.getPlaylists()
        async let gen = navidrome.getGenres()
        
        let (rec, recPlayed, freq, allA, artList, plList, genList) = await (recent, recentPlayed, frequent, allAlb, arts, pls, gen)
        
        self.recentAlbums = rec
        self.recentlyPlayedAlbums = recPlayed
        self.featuredAlbums = freq
        self.albums = allA
        self.artists = artList
        self.playlists = plList
        self.genres = genList
        
        persistSmartPlaylistsCache()
        
        Task {
            for type in SmartPlaylistType.allCases {
                await self.loadSmartPlaylist(type)
            }
        }
    }
    
    // MARK: - Manual Library Sync
    func syncLibrary(triggerServerScan: Bool = true) async {
        guard isConnected else {
            showToast("Conecta con el servidor para sincronizar la biblioteca.")
            return
        }
        
        isSyncingLibrary = true
        defer { isSyncingLibrary = false }
        
        if triggerServerScan {
            _ = await navidrome.startScan()
        }
        
        await loadLibrary()
        showToast("Biblioteca sincronizada correctamente.")
    }
    
    // MARK: - Search
    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchAlbums = []
            searchSongs = []
            return
        }
        
        if isConnected {
            let res = await navidrome.search(query: trimmed)
            self.searchAlbums = res.albums
            self.searchSongs = res.songs
        } else {
            self.searchAlbums = albums.filter {
                $0.displayTitle.localizedCaseInsensitiveContains(trimmed) ||
                $0.displayArtist.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }
    
    // MARK: - Spotlight Search (macOS)
    func toggleSpotlight() {
        if isSpotlightPresented {
            closeSpotlight()
        } else {
            openSpotlight()
        }
    }
    
    func openSpotlight() {
        isSpotlightPresented = true
        if !spotlightQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            performSpotlightSearch(query: spotlightQuery)
        }
    }
    
    func closeSpotlight() {
        isSpotlightPresented = false
    }
    
    func performSpotlightSearch(query: String) {
        spotlightSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.spotlightArtists = []
            self.spotlightAlbums = []
            self.spotlightSongs = []
            self.isSpotlightLoading = false
            return
        }
        
        self.isSpotlightLoading = true
        spotlightSearchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            if self.isConnected {
                let res = await self.navidrome.search(query: trimmed)
                if Task.isCancelled { return }
                self.spotlightArtists = res.artists
                self.spotlightAlbums = res.albums
                self.spotlightSongs = res.songs
            } else {
                let filteredArtists = self.artists.filter {
                    $0.name.localizedCaseInsensitiveContains(trimmed)
                }
                let filteredAlbums = self.albums.filter {
                    $0.displayTitle.localizedCaseInsensitiveContains(trimmed) ||
                    $0.displayArtist.localizedCaseInsensitiveContains(trimmed)
                }
                if Task.isCancelled { return }
                self.spotlightArtists = filteredArtists
                self.spotlightAlbums = filteredAlbums
                self.spotlightSongs = []
            }
            self.isSpotlightLoading = false
        }
    }
    
    // MARK: - Navigation
    func navigateToAlbum(_ album: AlbumItem) {
        selectAlbumForDetail(album)
        // Avoid duplicate pushes of same album
        if case .album(let current) = navigationStack.last, current.id == album.id {
            requestedDestination = .album(album)
            return
        }
        navigationStack.append(.album(album))
        requestedDestination = .album(album)
    }
    
    func navigateToArtist(_ artist: ArtistItem) {
        selectArtistForDetail(artist)
        if case .artist(let current) = navigationStack.last, current.id == artist.id {
            requestedDestination = .artist(artist)
            return
        }
        navigationStack.append(.artist(artist))
        requestedDestination = .artist(artist)
    }
    
    func navigateToAlbum(for song: SongItem) {
        // 1. Match album by parent ID or direct ID in loaded catalog
        if let parent = song.parent, let match = albums.first(where: { $0.id == parent }) {
            navigateToAlbum(match)
            return
        }
        
        // 2. Match album by title and artist
        if let albumName = song.album, !albumName.isEmpty {
            if let match = albums.first(where: {
                $0.displayTitle.localizedCaseInsensitiveCompare(albumName) == .orderedSame &&
                ($0.displayArtist.localizedCaseInsensitiveCompare(song.displayArtist) == .orderedSame || song.displayArtist == "Unknown Artist")
            }) ?? albums.first(where: {
                $0.displayTitle.localizedCaseInsensitiveCompare(albumName) == .orderedSame
            }) {
                navigateToAlbum(match)
                return
            }
        }
        
        // 3. Fallback to lightweight AlbumItem
        let albumId = song.parent ?? song.album ?? song.id
        let albumName = song.album ?? song.title
        let album = AlbumItem(
            id: albumId,
            name: albumName,
            title: albumName,
            artist: song.artist,
            artistId: song.artistId,
            coverArt: song.coverArt,
            songCount: nil,
            duration: nil,
            year: song.year,
            genre: song.genre,
            bitRate: song.bitRate,
            suffix: song.suffix,
            playCount: nil,
            userRating: nil
        )
        navigateToAlbum(album)
    }
    
    func navigateToArtist(for song: SongItem) {
        let artistName = song.displayArtist
        guard !artistName.isEmpty && artistName != "Unknown Artist" else { return }
        
        // 1. Match by artistId if available
        if let artistId = song.artistId, let match = artists.first(where: { $0.id == artistId }) {
            navigateToArtist(match)
            return
        }
        
        // 2. Match by artist name in loaded catalog
        if let match = artists.first(where: { $0.name.localizedCaseInsensitiveCompare(artistName) == .orderedSame }) {
            navigateToArtist(match)
            return
        }
        
        // 3. Match from album metadata
        if let albumMatch = albums.first(where: { $0.displayArtist.localizedCaseInsensitiveCompare(artistName) == .orderedSame }),
           let artistId = albumMatch.artistId {
            let artist = ArtistItem(id: artistId, name: artistName, albumCount: nil, artistImageUrl: nil)
            navigateToArtist(artist)
            return
        }
        
        // 4. Fallback with artist name
        let artist = ArtistItem(id: song.artistId ?? artistName, name: artistName, albumCount: nil, artistImageUrl: nil)
        navigateToArtist(artist)
    }
    
    func navigateToArtist(for album: AlbumItem) {
        let artistName = album.displayArtist
        guard !artistName.isEmpty && artistName != "Unknown Artist" else { return }
        
        // 1. Match by artistId
        if let artistId = album.artistId, let match = artists.first(where: { $0.id == artistId }) {
            navigateToArtist(match)
            return
        }
        
        // 2. Match by artist name in loaded catalog
        if let match = artists.first(where: { $0.name.localizedCaseInsensitiveCompare(artistName) == .orderedSame }) {
            navigateToArtist(match)
            return
        }
        
        // 3. Fallback with artist name
        let artist = ArtistItem(id: album.artistId ?? artistName, name: artistName, albumCount: nil, artistImageUrl: nil)
        navigateToArtist(artist)
    }
    
    func navigateBack() {
        guard !navigationStack.isEmpty else { return }
        navigationStack.removeLast()
        
        // Restore selected state for previous item if any
        if let previous = navigationStack.last {
            switch previous {
            case .album(let album):
                selectAlbumForDetail(album)
            case .artist(let artist):
                selectArtistForDetail(artist)
            case .smartPlaylist:
                break
            }
        } else {
            selectedAlbumForDetail = nil
            selectedArtistForDetail = nil
        }
    }
    
    func popToRoot() {
        navigationStack.removeAll()
        selectedAlbumForDetail = nil
        selectedArtistForDetail = nil
    }
    
    // MARK: - Album Details
    func selectAlbumForDetail(_ album: AlbumItem) {
        self.selectedAlbumForDetail = album
        self.selectedAlbumTracks = []
        self.isLoadingTracks = true
        
        Task {
            if isConnected {
                let (_, songs) = await navidrome.getAlbum(id: album.id)
                self.selectedAlbumTracks = songs
            } else {
                self.selectedAlbumTracks = generateSampleTracks(for: album)
            }
            self.isLoadingTracks = false
        }
    }
    
    func loadTracksForCarPlay(album: AlbumItem) async -> [SongItem] {
        if isConnected {
            let (_, songs) = await navidrome.getAlbum(id: album.id)
            return songs
        } else {
            return generateSampleTracks(for: album)
        }
    }
    
    // MARK: - Artist Details
    func selectArtistForDetail(_ artist: ArtistItem) {
        self.selectedArtistForDetail = artist
        self.selectedArtistAlbums = []
        self.isLoadingArtistAlbums = true
        
        Task {
            if isConnected {
                let (_, albs) = await navidrome.getArtist(id: artist.id)
                if !albs.isEmpty {
                    self.selectedArtistAlbums = albs
                } else {
                    // Fallback to local catalog match
                    self.selectedArtistAlbums = self.albums.filter {
                        $0.artistId == artist.id || $0.displayArtist.localizedCaseInsensitiveContains(artist.name)
                    }
                }
            } else {
                self.selectedArtistAlbums = self.albums.filter {
                    $0.artistId == artist.id || $0.displayArtist.localizedCaseInsensitiveContains(artist.name)
                }
            }
            self.isLoadingArtistAlbums = false
        }
    }
    
    // MARK: - Playback Control
    func playSong(_ song: SongItem, inAlbum album: AlbumItem?, queue: [SongItem]) {
        self.currentSong = song
        let resolvedAlbum = album ?? self.albums.first(where: { $0.id == song.parent || (song.album != nil && $0.name == song.album) })
        self.currentAlbum = resolvedAlbum
        
        // If queue is provided with multiple items, use it
        if !queue.isEmpty {
            self.queue = queue
            if let idx = self.queue.firstIndex(where: { $0.id == song.id }) {
                self.queueIndex = idx
            } else {
                self.queueIndex = 0
            }
        } else {
            self.queue = [song]
            self.queueIndex = 0
        }
        
        // If queue only has 1 song and an album exists, automatically load and queue the rest of the album
        if self.queue.count <= 1 {
            let targetAlbum = album ?? self.albums.first(where: { $0.id == song.parent || (song.album != nil && $0.name == song.album) })
            if let alb = targetAlbum {
                Task {
                    var songs: [SongItem] = []
                    if self.isConnected {
                        let (_, fetched) = await self.navidrome.getAlbum(id: alb.id)
                        songs = fetched
                    } else {
                        songs = self.generateSampleTracks(for: alb)
                    }
                    if !songs.isEmpty {
                        self.queue = songs
                        if let idx = songs.firstIndex(where: { $0.id == song.id }) {
                            self.queueIndex = idx
                            AudioCacheManager.shared.preloadQueue(
                                queue: songs,
                                startingAfter: idx,
                                count: self.serverConfig.preloadQueueCount,
                                navidrome: self.navidrome
                            )
                        }
                    }
                }
            }
        }
        
        self.isLoadingTrack = true
        
        if isConnected {
            Task {
                if let cachedURL = AudioCacheManager.shared.cachedAudioURL(for: song.id) {
                    mpv.play(url: cachedURL.path)
                    await navidrome.scrobble(songId: song.id, submission: false)
                    syncNowPlaying()
                    self.isLoadingTrack = false
                } else if let streamURL = await navidrome.streamURL(for: song.id) {
                    mpv.play(url: streamURL.absoluteString)
                    await navidrome.scrobble(songId: song.id, submission: false)
                    syncNowPlaying()
                    self.isLoadingTrack = false
                } else {
                    self.isLoadingTrack = false
                    self.showToast("No se pudo obtener el audio de \"\(song.title)\". Revisa la conexión al servidor.")
                    await self.handlePlaybackFailure(for: song)
                }
                
                // Preload the next N tracks in the queue in background
                AudioCacheManager.shared.preloadQueue(
                    queue: self.queue,
                    startingAfter: self.queueIndex,
                    count: self.serverConfig.preloadQueueCount,
                    navidrome: self.navidrome
                )
            }
        } else {
            if let path = song.path, FileManager.default.fileExists(atPath: path) {
                mpv.play(url: path)
            } else {
                let demoStream = "https://archive.org/download/test-audio-sample-flac/96k-24bit.flac"
                mpv.play(url: demoStream)
            }
            self.isLoadingTrack = false
            syncNowPlaying()
        }
    }
    
    // MARK: - Toast Notifications
    func showToast(_ message: String) {
        self.toastMessage = message
        toastTimer?.cancel()
        toastTimer = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
            if !Task.isCancelled {
                self.toastMessage = nil
            }
        }
    }
    
    func hideToast() {
        self.toastMessage = nil
        toastTimer?.cancel()
    }
    
    func playAlbum(_ album: AlbumItem) {
        Task {
            var songs: [SongItem] = []
            if isConnected {
                let (_, fetched) = await navidrome.getAlbum(id: album.id)
                songs = fetched
            } else {
                songs = generateSampleTracks(for: album)
            }
            if let first = songs.first {
                playSong(first, inAlbum: album, queue: songs)
            }
        }
    }
    
    func playPlaylist(_ playlist: PlaylistItem) {
        Task {
            if isConnected {
                let (_, songs) = await navidrome.getPlaylist(id: playlist.id)
                if let first = songs.first {
                    playSong(first, inAlbum: nil, queue: songs)
                }
            }
        }
    }
    
    // MARK: - Smart Playlists Loading & Playback
    func loadSmartPlaylist(_ type: SmartPlaylistType, forceRefresh: Bool = false) async {
        guard isConnected else { return }
        if !forceRefresh && !(smartPlaylistSongs[type]?.isEmpty ?? true) {
            return
        }
        
        await MainActor.run {
            self.isLoadingSmartPlaylist[type] = true
        }
        
        let songs: [SongItem]
        switch type {
        case .recentlyAdded:
            songs = await navidrome.getRecentlyAddedSongs(cachedAlbums: self.recentAlbums.isEmpty ? self.albums : self.recentAlbums, limit: 50)
        case .recentlyPlayed:
            songs = await navidrome.getRecentlyPlayedSongs(cachedAlbums: self.recentlyPlayedAlbums.isEmpty ? self.albums : self.recentlyPlayedAlbums, limit: 50)
        case .topRated:
            songs = await navidrome.getTopRatedSongs(cachedAlbums: self.topRatedAlbums.isEmpty ? self.albums : self.topRatedAlbums, limit: 50)
        case .unplayed:
            songs = await navidrome.getUnplayedSongs(targetCount: 30)
        case .forgottenFavorites:
            songs = await navidrome.getForgottenFavorites(targetCount: 30)
        case .mostPlayed:
            songs = await navidrome.getTopTracks(limit: 50, cachedAlbums: self.albums)
        case .starred:
            songs = await navidrome.getStarredSongs()
        case .discoveryMix:
            songs = await navidrome.getDiscoveryMix(targetCount: 40)
        }
        
        await MainActor.run {
            self.smartPlaylistSongs[type] = songs
            self.isLoadingSmartPlaylist[type] = false
            self.persistSmartPlaylistsCache()
        }
    }
    
    func persistSmartPlaylistsCache() {
        var rawMap: [String: [SongItem]] = [:]
        for (k, v) in smartPlaylistSongs {
            rawMap[k.rawValue] = v
        }
        LibraryCacheManager.shared.saveCache(
            albums: self.albums,
            featuredAlbums: self.featuredAlbums,
            recentAlbums: self.recentAlbums,
            recentlyPlayedAlbums: self.recentlyPlayedAlbums,
            artists: self.artists,
            playlists: self.playlists,
            genres: self.genres,
            smartPlaylists: rawMap
        )
    }
    
    func playSmartPlaylist(_ type: SmartPlaylistType, startingAt index: Int = 0, shuffle: Bool = false) {
        guard let list = smartPlaylistSongs[type], !list.isEmpty else { return }
        let playlistQueue: [SongItem]
        let startIndex: Int
        if shuffle {
            playlistQueue = list.shuffled()
            startIndex = 0
        } else {
            playlistQueue = list
            startIndex = min(max(index, 0), list.count - 1)
        }
        
        let targetSong = playlistQueue[startIndex]
        let targetAlbum = self.albums.first(where: { $0.id == targetSong.parent || (targetSong.album != nil && $0.name == targetSong.album) })
        playSong(targetSong, inAlbum: targetAlbum, queue: playlistQueue)
    }
    
    // MARK: - Audio Cache Management
    var formattedAudioCacheSize: String {
        AudioCacheManager.shared.formattedCacheSize()
    }
    
    func clearAudioCache() {
        AudioCacheManager.shared.clearAudioCache()
        self.objectWillChange.send()
    }
    
    // MARK: - Artwork Cache Management
    var formattedArtworkCacheSize: String {
        ArtworkCacheManager.shared.formattedDiskCacheSize()
    }
    
    func clearArtworkCache() {
        ArtworkCacheManager.shared.clearAllCache()
        self.objectWillChange.send()
    }
    
    func togglePlayPause() {
        mpv.togglePause()
        syncNowPlaying()
    }
    
    func nextTrack() {
        guard !queue.isEmpty else { return }
        if queueIndex + 1 < queue.count {
            queueIndex += 1
            let next = queue[queueIndex]
            let nextAlbum = self.albums.first(where: { $0.id == next.parent || (next.album != nil && $0.name == next.album) }) ?? (next.album == currentAlbum?.name ? currentAlbum : nil)
            playSong(next, inAlbum: nextAlbum, queue: queue)
        }
    }
    
    func previousTrack() {
        guard !queue.isEmpty else { return }
        if mpv.currentTime > 3.0 {
            mpv.seek(to: 0.0)
            syncNowPlaying()
            return
        }
        if queueIndex > 0 {
            queueIndex -= 1
            let prev = queue[queueIndex]
            let prevAlbum = self.albums.first(where: { $0.id == prev.parent || (prev.album != nil && $0.name == prev.album) }) ?? (prev.album == currentAlbum?.name ? currentAlbum : nil)
            playSong(prev, inAlbum: prevAlbum, queue: queue)
        }
    }
    
    // MARK: - Rating System (0-5 Stars)
    func rateSong(_ song: SongItem, rating: Int) {
        let clamped = max(0, min(5, rating))
        
        // 1. Update current song if matching
        if currentSong?.id == song.id {
            currentSong?.userRating = clamped
        }
        
        // 2. Update queue
        for i in queue.indices where queue[i].id == song.id {
            queue[i].userRating = clamped
        }
        
        // 3. Update selected album tracks
        for i in selectedAlbumTracks.indices where selectedAlbumTracks[i].id == song.id {
            selectedAlbumTracks[i].userRating = clamped
        }
        
        // 4. Update all smart playlists (Unplayed, Top Rated, Starred, etc.)
        for (key, tracks) in smartPlaylistSongs {
            var updated = tracks
            var modified = false
            for i in updated.indices where updated[i].id == song.id {
                updated[i].userRating = clamped
                modified = true
            }
            if modified {
                smartPlaylistSongs[key] = updated
            }
        }
        
        // 5. Update search results
        for i in searchSongs.indices where searchSongs[i].id == song.id {
            searchSongs[i].userRating = clamped
        }
        
        // 6. Update spotlight search songs
        for i in spotlightSongs.indices where spotlightSongs[i].id == song.id {
            spotlightSongs[i].userRating = clamped
        }
        
        // 7. Send to Navidrome server
        if isConnected {
            Task {
                _ = await navidrome.setRating(id: song.id, rating: clamped)
            }
        }
    }
    
    // MARK: - Starred / Favorites System
    func toggleStarred(for song: SongItem) {
        let newStarred = !song.isStarred
        let starredTimestamp = newStarred ? ISO8601DateFormatter().string(from: Date()) : nil
        
        // 1. Update current song
        if currentSong?.id == song.id {
            currentSong?.starred = starredTimestamp
        }
        
        // 2. Update queue
        for i in queue.indices where queue[i].id == song.id {
            queue[i].starred = starredTimestamp
        }
        
        // 3. Update selected album tracks
        for i in selectedAlbumTracks.indices where selectedAlbumTracks[i].id == song.id {
            selectedAlbumTracks[i].starred = starredTimestamp
        }
        
        // 4. Update all smart playlists
        for (key, tracks) in smartPlaylistSongs {
            var updated = tracks
            var modified = false
            for i in updated.indices where updated[i].id == song.id {
                updated[i].starred = starredTimestamp
                modified = true
            }
            if modified {
                smartPlaylistSongs[key] = updated
            }
        }
        
        // 5. Update search & spotlight
        for i in searchSongs.indices where searchSongs[i].id == song.id {
            searchSongs[i].starred = starredTimestamp
        }
        for i in spotlightSongs.indices where spotlightSongs[i].id == song.id {
            spotlightSongs[i].starred = starredTimestamp
        }
        
        // 6. Send to Navidrome server
        if isConnected {
            Task {
                _ = await navidrome.setStarred(id: song.id, starred: newStarred)
            }
        }
    }
    
    func rateAlbum(_ album: AlbumItem, rating: Int) {
        let clamped = max(0, min(5, rating))
        
        // 1. Update current album
        if currentAlbum?.id == album.id {
            currentAlbum?.userRating = clamped
        }
        
        // 2. Update selected detail album
        if selectedAlbumForDetail?.id == album.id {
            selectedAlbumForDetail?.userRating = clamped
        }
        
        // 3. Update all collections
        for i in albums.indices where albums[i].id == album.id {
            albums[i].userRating = clamped
        }
        for i in recentAlbums.indices where recentAlbums[i].id == album.id {
            recentAlbums[i].userRating = clamped
        }
        for i in recentlyPlayedAlbums.indices where recentlyPlayedAlbums[i].id == album.id {
            recentlyPlayedAlbums[i].userRating = clamped
        }
        for i in featuredAlbums.indices where featuredAlbums[i].id == album.id {
            featuredAlbums[i].userRating = clamped
        }
        for i in searchAlbums.indices where searchAlbums[i].id == album.id {
            searchAlbums[i].userRating = clamped
        }
        
        // 4. Send to Navidrome server
        if isConnected {
            Task {
                _ = await navidrome.setRating(id: album.id, rating: clamped)
            }
        }
    }
    
    // MARK: - Queue Management
    func addToQueue(_ song: SongItem) {
        queue.append(song)
        if currentSong == nil {
            playSong(song, inAlbum: currentAlbum, queue: queue)
        }
    }
    
    func playNext(_ song: SongItem) {
        if queue.isEmpty {
            playSong(song, inAlbum: currentAlbum, queue: [song])
            return
        }
        let insertIndex = min(queueIndex + 1, queue.count)
        queue.insert(song, at: insertIndex)
    }
    
    func playAlbumNext(_ album: AlbumItem) {
        Task {
            var songs: [SongItem] = []
            if isConnected {
                let (_, fetched) = await navidrome.getAlbum(id: album.id)
                songs = fetched
            } else {
                songs = generateSampleTracks(for: album)
            }
            guard !songs.isEmpty else { return }
            if queue.isEmpty {
                if let first = songs.first {
                    playSong(first, inAlbum: album, queue: songs)
                }
            } else {
                let insertIndex = min(queueIndex + 1, queue.count)
                queue.insert(contentsOf: songs, at: insertIndex)
                showToast("\"\(album.displayTitle)\" añadido a continuación")
            }
        }
    }
    
    func addAlbumToQueue(_ album: AlbumItem) {
        Task {
            var songs: [SongItem] = []
            if isConnected {
                let (_, fetched) = await navidrome.getAlbum(id: album.id)
                songs = fetched
            } else {
                songs = generateSampleTracks(for: album)
            }
            guard !songs.isEmpty else { return }
            if queue.isEmpty {
                if let first = songs.first {
                    playSong(first, inAlbum: album, queue: songs)
                }
            } else {
                queue.append(contentsOf: songs)
                showToast("\"\(album.displayTitle)\" añadido al final de la cola")
            }
        }
    }
    
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        if index == queueIndex {
            nextTrack()
        }
        queue.remove(at: index)
        if index < queueIndex {
            queueIndex = max(0, queueIndex - 1)
        }
    }
    
    func clearQueue() {
        if let current = currentSong {
            queue = [current]
            queueIndex = 0
        } else {
            queue = []
            queueIndex = 0
        }
    }
    
    func playQueueItem(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        let targetSong = queue[index]
        playSong(targetSong, inAlbum: currentAlbum, queue: queue)
    }
    
    func moveQueueItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < queue.count,
              destinationIndex >= 0 && destinationIndex < queue.count,
              sourceIndex != destinationIndex else { return }
        
        // Prevent moving items to or before the currently playing song
        let minUpcoming = queueIndex + 1
        guard sourceIndex >= minUpcoming && destinationIndex >= minUpcoming else { return }
        
        let item = queue.remove(at: sourceIndex)
        queue.insert(item, at: destinationIndex)
        
        if isConnected {
            AudioCacheManager.shared.preloadQueue(
                queue: self.queue,
                startingAfter: self.queueIndex,
                count: self.serverConfig.preloadQueueCount,
                navidrome: self.navidrome
            )
        }
    }
    
    func moveUpcomingQueueItem(at index: Int, direction: Int) {
        let newIndex = index + direction
        moveQueueItem(from: index, to: newIndex)
    }
    
    func moveUpcomingQueueItemToTop(at index: Int) {
        let topIndex = queueIndex + 1
        moveQueueItem(from: index, to: topIndex)
    }
    
    func syncNowPlaying() {
        let artURL = coverArtURL(for: currentSong?.coverArt ?? currentAlbum?.coverArt)
        MediaKeyController.shared.updateNowPlaying(
            song: currentSong,
            duration: mpv.duration,
            currentTime: mpv.currentTime,
            isPaused: mpv.isPaused,
            artworkURL: artURL
        )
    }
    
    private var sessionSalt: String = "mpvg_salt"
    private var sessionToken: String = ""
    private var coverArtURLCache: [String: URL] = [:]
    
    private func updateSessionAuth() {
        let tokenInput = "\(serverConfig.password)\(sessionSalt)"
        let tokenHash = CryptoKit.Insecure.MD5.hash(data: Data(tokenInput.utf8))
        self.sessionToken = tokenHash.map { String(format: "%02hhx", $0) }.joined()
        self.coverArtURLCache.removeAll()
    }
    
    func coverArtURL(for id: String?) -> URL? {
        guard let id = id, !id.isEmpty else { return nil }
        
        if let cached = coverArtURLCache[id] {
            return cached
        }
        
        if let base = serverConfig.cleanURL, !serverConfig.password.isEmpty {
            if sessionToken.isEmpty {
                updateSessionAuth()
            }
            var comp = URLComponents(url: base.appendingPathComponent("rest/getCoverArt.view"), resolvingAgainstBaseURL: false)
            comp?.queryItems = [
                URLQueryItem(name: "u", value: serverConfig.username),
                URLQueryItem(name: "t", value: sessionToken),
                URLQueryItem(name: "s", value: sessionSalt),
                URLQueryItem(name: "v", value: "1.16.1"),
                URLQueryItem(name: "c", value: "mpvg"),
                URLQueryItem(name: "f", value: "json"),
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "size", value: "500")
            ]
            if let url = comp?.url {
                coverArtURLCache[id] = url
                return url
            }
        }
        return nil
    }
    
    var currentArtworkURL: URL? {
        guard let song = currentSong else { return nil }
        if let coverId = song.coverArt, !coverId.isEmpty {
            return coverArtURL(for: coverId)
        }
        if let albumCover = currentAlbum?.coverArt, !albumCover.isEmpty {
            return coverArtURL(for: albumCover)
        }
        if let parentId = song.parent, !parentId.isEmpty {
            return coverArtURL(for: parentId)
        }
        return nil
    }
    
    func artistAvatarURL(for artist: ArtistItem) -> URL? {
        if let raw = artist.artistImageUrl, !raw.isEmpty {
            if let url = URL(string: raw), raw.hasPrefix("http") {
                return url
            } else if raw.hasPrefix("/"), let base = serverConfig.cleanURL {
                return base.appendingPathComponent(raw.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
            }
        }
        if let cover = coverArtURL(for: artist.id) {
            return cover
        }
        if let raw = artist.artistImageUrl, let url = URL(string: raw) {
            return url
        }
        return nil
    }
    
    // MARK: - Curated Sample / Demo Catalog
    func loadSampleCatalog() {
        var sampleList: [AlbumItem] = [
            AlbumItem(
                id: "demo-1",
                name: "Random Access Memories",
                title: "Random Access Memories",
                artist: "Daft Punk",
                artistId: "art-1",
                coverArt: "https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=500&q=80",
                songCount: 13,
                duration: 4460,
                year: 2013,
                genre: "Electronic / Disco",
                bitRate: 9216,
                suffix: "FLAC 24/96",
                playCount: 142
            ),
            AlbumItem(
                id: "demo-2",
                name: "Kind of Blue",
                title: "Kind of Blue (Master)",
                artist: "Miles Davis",
                artistId: "art-2",
                coverArt: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
                songCount: 5,
                duration: 2724,
                year: 1959,
                genre: "Modal Jazz",
                bitRate: 9216,
                suffix: "DSD / DFF",
                playCount: 98
            ),
            AlbumItem(
                id: "demo-3",
                name: "Aja",
                title: "Aja (Remastered)",
                artist: "Steely Dan",
                artistId: "art-3",
                coverArt: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80",
                songCount: 7,
                duration: 2398,
                year: 1977,
                genre: "Jazz Rock",
                bitRate: 4608,
                suffix: "FLAC 24/48",
                playCount: 76
            ),
            AlbumItem(
                id: "demo-4",
                name: "The Dark Side of the Moon",
                title: "The Dark Side of the Moon",
                artist: "Pink Floyd",
                artistId: "art-4",
                coverArt: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80",
                songCount: 10,
                duration: 2580,
                year: 1973,
                genre: "Progressive Rock",
                bitRate: 9216,
                suffix: "FLAC 24/96",
                playCount: 215
            ),
            AlbumItem(
                id: "demo-5",
                name: "OK Computer",
                title: "OK Computer OKNOTOK",
                artist: "Radiohead",
                artistId: "art-5",
                coverArt: "https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80",
                songCount: 12,
                duration: 3192,
                year: 1997,
                genre: "Art Rock",
                bitRate: 1411,
                suffix: "FLAC 16/44.1",
                playCount: 180
            ),
            AlbumItem(
                id: "demo-6",
                name: "Abbey Road",
                title: "Abbey Road (Super Deluxe)",
                artist: "The Beatles",
                artistId: "art-6",
                coverArt: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80",
                songCount: 17,
                duration: 2840,
                year: 1969,
                genre: "Classic Rock",
                bitRate: 9216,
                suffix: "FLAC 24/96",
                playCount: 304
            ),
            AlbumItem(
                id: "demo-7",
                name: "Discovery",
                title: "Discovery",
                artist: "Daft Punk",
                artistId: "art-1",
                coverArt: "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&q=80",
                songCount: 14,
                duration: 3650,
                year: 2001,
                genre: "French House",
                bitRate: 1411,
                suffix: "FLAC 16/44.1",
                playCount: 132
            ),
            AlbumItem(
                id: "demo-8",
                name: "Blue Train",
                title: "Blue Train (The Complete Masters)",
                artist: "John Coltrane",
                artistId: "art-7",
                coverArt: "https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=500&q=80",
                songCount: 5,
                duration: 2540,
                year: 1957,
                genre: "Hard Bop",
                bitRate: 9216,
                suffix: "FLAC 24/192",
                playCount: 65
            )
        ]
        
        if sampleList.count >= 3 {
            sampleList[0].userRating = 5
            sampleList[1].userRating = 5
            sampleList[2].userRating = 4
        }
        
        self.featuredAlbums = Array(sampleList.prefix(4))
        self.recentAlbums = Array(sampleList.suffix(4))
        self.recentlyPlayedAlbums = Array(sampleList.prefix(3))
        self.albums = sampleList
        
        self.artists = [
            ArtistItem(id: "art-1", name: "Daft Punk", albumCount: 4, artistImageUrl: "https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=300&q=80"),
            ArtistItem(id: "art-2", name: "Miles Davis", albumCount: 12, artistImageUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300&q=80"),
            ArtistItem(id: "art-3", name: "Steely Dan", albumCount: 7, artistImageUrl: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300&q=80"),
            ArtistItem(id: "art-4", name: "Pink Floyd", albumCount: 15, artistImageUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&q=80"),
            ArtistItem(id: "art-5", name: "Radiohead", albumCount: 9, artistImageUrl: "https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=300&q=80"),
            ArtistItem(id: "art-6", name: "The Beatles", albumCount: 13, artistImageUrl: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300&q=80"),
            ArtistItem(id: "art-7", name: "John Coltrane", albumCount: 8, artistImageUrl: "https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=300&q=80")
        ]
        
        if let firstAlbum = self.albums.first, let firstTrack = generateSampleTracks(for: firstAlbum).first {
            self.currentSong = firstTrack
            self.currentAlbum = firstAlbum
        }
    }
    
    private func generateSampleTracks(for album: AlbumItem) -> [SongItem] {
        let count = album.songCount ?? 8
        var list: [SongItem] = []
        let titles: [String] = [
            "Give Life Back to Music", "The Game of Love", "Giorgio by Moroder",
            "Within", "Instant Crush", "Lose Yourself to Dance", "Touch",
            "Get Lucky", "Beyond", "Motherboard", "Fragments of Time", "Doin' It Right", "Contact"
        ]
        
        for i in 1...count {
            let songTitle = i <= titles.count ? titles[i - 1] : "Pista \(i)"
            list.append(SongItem(
                id: "\(album.id)-track-\(i)",
                parent: album.id,
                title: songTitle,
                album: album.displayTitle,
                artist: album.displayArtist,
                track: i,
                year: album.year,
                genre: album.genre,
                coverArt: album.coverArt,
                size: 45_000_000,
                contentType: "audio/flac",
                suffix: "FLAC",
                duration: Double(180 + (i * 27) % 240),
                bitRate: album.bitRate ?? 1411,
                path: nil
            ))
        }
        return list
    }
}
