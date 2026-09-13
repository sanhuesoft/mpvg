//
//  IOSMainView.swift
//  mpvg
//
//  Tailored iPhone and compact iOS layout featuring a native bottom TabView,
//  a docked Mini Player bar, and an interactive Now Playing sheet.
//

import SwiftUI

#if os(iOS)
struct IOSMainView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var selectedTab: Int = 0
    @State private var showNowPlayingSheet: Bool = false
    
    // Per-tab navigation stacks for native iOS push transitions
    @State private var browsePath: [NavigationDestination] = []
    @State private var playlistsPath: [NavigationDestination] = []
    @State private var albumsPath: [NavigationDestination] = []
    @State private var artistsPath: [NavigationDestination] = []
    @State private var searchPath: [NavigationDestination] = []
    
    var body: some View {
        Group {
            if #available(iOS 26.1, *) {
                mainTabView
                    // Native Liquid Glass Now Playing bar — hidden when there is no song playing
                    .tabViewBottomAccessory(isEnabled: viewModel.currentSong != nil) {
                        miniPlayerContent
                    }
                    .sheet(isPresented: $showNowPlayingSheet) {
                        NowPlayingSheetView(viewModel: viewModel)
                    }
                    .sheet(isPresented: $viewModel.showQueueSheet) {
                        QueueView(viewModel: viewModel)
                    }
                    .sheet(isPresented: $viewModel.showSettingsSheet) { settingsSheet }
            } else if #available(iOS 26.0, *) {
                tabViewWithOptionalAccessory
                    .sheet(isPresented: $showNowPlayingSheet) {
                        NowPlayingSheetView(viewModel: viewModel)
                    }
                    .sheet(isPresented: $viewModel.showQueueSheet) {
                        QueueView(viewModel: viewModel)
                    }
                    .sheet(isPresented: $viewModel.showSettingsSheet) { settingsSheet }
            } else {
                // Fallback for iOS 17-25: manual ZStack positioning
                ZStack(alignment: .bottom) {
                    mainTabView
                    if viewModel.currentSong != nil {
                        miniPlayerBar
                            .padding(.horizontal, 16)
                            .padding(.bottom, 58)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .sheet(isPresented: $showNowPlayingSheet) {
                    NowPlayingSheetView(viewModel: viewModel)
                }
                .sheet(isPresented: $viewModel.showQueueSheet) {
                    QueueView(viewModel: viewModel)
                }
                .sheet(isPresented: $viewModel.showSettingsSheet) { settingsSheet }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.currentSong != nil)
        .onChange(of: viewModel.requestedDestination) { destination in
            guard let dest = destination else { return }
            pushDestination(dest)
            viewModel.requestedDestination = nil
        }
    }
    
    private func pushDestination(_ destination: NavigationDestination) {
        switch selectedTab {
        case 0: browsePath.append(destination)
        case 1: playlistsPath.append(destination)
        case 2: albumsPath.append(destination)
        case 3: artistsPath.append(destination)
        default: searchPath.append(destination)
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .album(let album):
            AlbumDetailView(album: album, viewModel: viewModel)
        case .artist(let artist):
            ArtistDetailView(artist: artist, viewModel: viewModel)
        case .smartPlaylist(let type):
            SmartPlaylistDetailView(type: type, viewModel: viewModel)
        }
    }
    
    // MARK: - Shared Tab View
    private var mainTabView: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    // Tap active tab to pop to root
                    switch newTab {
                    case 0: browsePath.removeAll()
                    case 1: playlistsPath.removeAll()
                    case 2: albumsPath.removeAll()
                    case 3: artistsPath.removeAll()
                    case 4: searchPath.removeAll()
                    default: break
                    }
                }
                selectedTab = newTab
            }
        )) {
            NavigationStack(path: $browsePath) {
                BrowseView(viewModel: viewModel)
                    .navigationTitle("Browse")
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        destinationView(for: dest)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { settingsToolbarButton }
                        ToolbarItem(placement: .topBarTrailing) { syncToolbarButton }
                    }
            }
            .tabItem { tabItemView(title: "Browse", systemImage: "sparkles") }
            .tag(0)
            
            NavigationStack(path: $playlistsPath) {
                IOSPlaylistsView(viewModel: viewModel)
                    .navigationTitle("Playlists")
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        destinationView(for: dest)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { settingsToolbarButton }
                        ToolbarItem(placement: .topBarTrailing) { syncToolbarButton }
                    }
            }
            .tabItem { tabItemView(title: "Listas", systemImage: "music.note.list") }
            .tag(1)
            
            NavigationStack(path: $albumsPath) {
                AlbumsGridView(viewModel: viewModel)
                    .navigationTitle("Albums")
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        destinationView(for: dest)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { settingsToolbarButton }
                        ToolbarItem(placement: .topBarTrailing) { syncToolbarButton }
                    }
            }
            .tabItem { tabItemView(title: "Albums", systemImage: "opticaldisc") }
            .tag(2)
            
            NavigationStack(path: $artistsPath) {
                ArtistsGridView(viewModel: viewModel)
                    .navigationTitle("Artists")
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        destinationView(for: dest)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { settingsToolbarButton }
                        ToolbarItem(placement: .topBarTrailing) { syncToolbarButton }
                    }
            }
            .tabItem { tabItemView(title: "Artists", systemImage: "music.mic") }
            .tag(3)
            
            NavigationStack(path: $searchPath) {
                IOSSearchView(viewModel: viewModel)
                    .navigationTitle("Search")
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        destinationView(for: dest)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { settingsToolbarButton }
                    }
            }
            .tabItem { tabItemView(title: "Search", systemImage: "magnifyingglass") }
            .tag(4)
        }
        .id(viewModel.tabBarShowsLabels)
        .accentColor(ColorTheme.terracotta)
    }
    
    // MARK: - Settings Sheet
    private var settingsSheet: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { viewModel.showSettingsSheet = false }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                }
        }
    }
    
    private var settingsToolbarButton: some View {
        Button(action: { viewModel.showSettingsSheet = true }) {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
        }
    }
    
    private var syncToolbarButton: some View {
        Button(action: {
            Task {
                await viewModel.syncLibrary()
            }
        }) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .rotationEffect(.degrees(viewModel.isSyncingLibrary ? 360 : 0))
                .animation(viewModel.isSyncingLibrary ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: viewModel.isSyncingLibrary)
                .foregroundColor(ColorTheme.terracotta)
        }
        .disabled(viewModel.isSyncingLibrary)
    }
    
    @ViewBuilder
    private func tabItemView(title: LocalizedStringKey, systemImage: String) -> some View {
        if viewModel.tabBarShowsLabels {
            Label(title, systemImage: systemImage)
        } else {
            Image(systemName: systemImage)
        }
    }
    
    // MARK: - Mini Player Content (inside tabViewBottomAccessory — no manual background)
    @available(iOS 26.0, *)
    @ViewBuilder
    private var tabViewWithOptionalAccessory: some View {
        if viewModel.currentSong != nil {
            mainTabView
                .tabViewBottomAccessory {
                    miniPlayerContent
                }
        } else {
            mainTabView
        }
    }
    
    /// Used on iOS 26+ inside tabViewBottomAccessory. The system provides the Liquid Glass
    /// material and sizing automatically, matching the tab bar pill exactly.
    @available(iOS 26.0, *)
    private var miniPlayerContent: some View {
        miniPlayerControls
    }
    
    // MARK: - Mini Player Bar (Liquid Glass Aesthetic — iOS 17-25 fallback)
    /// Used on iOS < 26 as a floating pill above the tab bar.
    private var miniPlayerBar: some View {
        miniPlayerControls
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ColorTheme.cardBackground.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
    }
    
    // MARK: - Shared player controls layout (Expanded Height ~1.6x)
    private var miniPlayerControls: some View {
        Button(action: { showNowPlayingSheet = true }) {
            VStack(spacing: 0) {
                // Subtle progress indicator on top
                GeometryReader { geo in
                    let progress = viewModel.mpv.duration > 0 ? (viewModel.mpv.currentTime / viewModel.mpv.duration) : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(ColorTheme.terracotta)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 3)
                    }
                }
                .frame(height: 3)
                
                HStack(spacing: 12) {
                    // Mini Album Cover (Enlarged to 66x66)
                    let artURL: URL? = {
                        if let coverId = viewModel.currentSong?.coverArt ?? viewModel.currentAlbum?.coverArt {
                            return viewModel.coverArtURL(for: coverId)
                        }
                        return nil
                    }()
                    
                    CachedAsyncImage(url: artURL) {
                        ZStack {
                            ColorTheme.cardBorder.opacity(0.5)
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 24))
                                .foregroundColor(ColorTheme.terracotta)
                        }
                    }
                    .frame(width: 66, height: 66)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(ColorTheme.cardBorder, lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    
                    // Metadata & Audio Format Badge
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.currentSong?.title ?? "")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(viewModel.currentSong?.displayArtist ?? "")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            if let suffix = viewModel.currentSong?.suffix?.uppercased(), !suffix.isEmpty {
                                Text(suffix)
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(ColorTheme.terracotta)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(ColorTheme.terracottaLight.opacity(0.6))
                                    .cornerRadius(4)
                            }
                            
                            if let rate = viewModel.mpv.audioSampleRate {
                                Text("\(rate / 1000)kHz")
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundColor(ColorTheme.textTertiary)
                            } else if let bitRate = viewModel.currentSong?.bitRate {
                                Text("\(bitRate)kbps")
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                    .foregroundColor(ColorTheme.textTertiary)
                            }
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Touch-Friendly Playback Controls
                    HStack(spacing: 4) {
                        Button(action: { viewModel.togglePlayPause() }) {
                            Image(systemName: viewModel.mpv.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(ColorTheme.textPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(ColorTheme.textPrimary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Standalone Tab Views for iPhone
struct IOSPlaylistsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    private let albumColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 14)
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                // Section 1: Smart Collections
                VStack(alignment: .leading, spacing: 12) {
                    Text("Smart Playlists")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .tracking(1.2)
                    
                    VStack(spacing: 10) {
                        // 1. Recently Added
                        NavigationLink(value: NavigationDestination.smartPlaylist(.recentlyAdded)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.recentlyAdded.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.recentlyAdded]?.count ?? viewModel.recentAlbums.count) canciones",
                                iconName: SmartPlaylistType.recentlyAdded.iconName,
                                gradientColors: SmartPlaylistType.recentlyAdded.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 2. Recently Played
                        NavigationLink(value: NavigationDestination.smartPlaylist(.recentlyPlayed)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.recentlyPlayed.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.recentlyPlayed]?.count ?? viewModel.recentlyPlayedAlbums.count) canciones",
                                iconName: SmartPlaylistType.recentlyPlayed.iconName,
                                gradientColors: SmartPlaylistType.recentlyPlayed.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 3. Top Rated (4 & 5 stars)
                        NavigationLink(value: NavigationDestination.smartPlaylist(.topRated)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.topRated.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.topRated]?.count ?? viewModel.topRatedAlbums.count) canciones",
                                iconName: SmartPlaylistType.topRated.iconName,
                                gradientColors: SmartPlaylistType.topRated.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 4. No escuchadas
                        NavigationLink(value: NavigationDestination.smartPlaylist(.unplayed)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.unplayed.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.unplayed]?.count ?? 30) canciones",
                                iconName: SmartPlaylistType.unplayed.iconName,
                                gradientColors: SmartPlaylistType.unplayed.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 5. Las Más Escuchadas
                        NavigationLink(value: NavigationDestination.smartPlaylist(.mostPlayed)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.mostPlayed.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.mostPlayed]?.count ?? 50) canciones",
                                iconName: SmartPlaylistType.mostPlayed.iconName,
                                gradientColors: SmartPlaylistType.mostPlayed.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 6. Favoritas
                        NavigationLink(value: NavigationDestination.smartPlaylist(.starred)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.starred.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.starred]?.count ?? 0) canciones",
                                iconName: SmartPlaylistType.starred.iconName,
                                gradientColors: SmartPlaylistType.starred.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 7. Joyas Olvidadas
                        NavigationLink(value: NavigationDestination.smartPlaylist(.forgottenFavorites)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.forgottenFavorites.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.forgottenFavorites]?.count ?? 0) canciones",
                                iconName: SmartPlaylistType.forgottenFavorites.iconName,
                                gradientColors: SmartPlaylistType.forgottenFavorites.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 8. Mix Descubrimiento
                        NavigationLink(value: NavigationDestination.smartPlaylist(.discoveryMix)) {
                            smartCollectionRow(
                                title: SmartPlaylistType.discoveryMix.title,
                                subtitle: "\(viewModel.smartPlaylistSongs[.discoveryMix]?.count ?? 40) canciones",
                                iconName: SmartPlaylistType.discoveryMix.iconName,
                                gradientColors: SmartPlaylistType.discoveryMix.gradientColors
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Section 2: Server Playlists
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Playlists")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                            .tracking(1.2)
                        Spacer()
                        if !viewModel.playlists.isEmpty {
                            Text("\(viewModel.playlists.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ColorTheme.terracotta)
                        }
                    }
                    
                    if viewModel.playlists.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 36))
                                .foregroundColor(ColorTheme.textTertiary.opacity(0.6))
                                .padding(.top, 16)
                            Text("No playlists found")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ColorTheme.textSecondary)
                            Text("Playlists from your server will appear here.")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        LazyVGrid(columns: albumColumns, spacing: 14) {
                            ForEach(viewModel.playlists) { playlist in
                                PlaylistCardView(playlist: playlist, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 60)
        }
        .refreshable {
            await viewModel.syncLibrary()
        }
        .background(ColorTheme.windowBackground)
    }
    
    private func smartCollectionRow(title: String, subtitle: String, iconName: String, gradientColors: [Color]) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: gradientColors.first?.opacity(0.3) ?? .clear, radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text(LocalizedStringKey(subtitle))
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ColorTheme.textTertiary)
        }
        .padding(12)
        .background(ColorTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ColorTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct AlbumsGridView: View {
    @ObservedObject var viewModel: PlayerViewModel
    var customAlbums: [AlbumItem]? = nil
    var title: String? = nil
    
    private var displayAlbums: [AlbumItem] {
        customAlbums ?? viewModel.albums
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 14)
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if displayAlbums.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 40))
                        .foregroundColor(ColorTheme.textTertiary)
                        .padding(.top, 60)
                    Text("No albums found")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(displayAlbums) { album in
                        AlbumCardView(album: album, viewModel: viewModel)
                    }
                }
                .padding(16)
                .padding(.bottom, 60) // Extra padding for mini-player
            }
        }
        .navigationTitle(title != nil ? LocalizedStringKey(title!) : LocalizedStringKey("Albums"))
        .refreshable {
            await viewModel.syncLibrary()
        }
        .background(ColorTheme.windowBackground)
    }
}

struct ArtistsGridView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 14)
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.artists) { artist in
                    ArtistCardView(artist: artist, viewModel: viewModel)
                }
            }
            .padding(16)
            .padding(.bottom, 60)
        }
        .refreshable {
            await viewModel.syncLibrary()
        }
        .background(ColorTheme.windowBackground)
    }
}

struct IOSSearchView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input Bar
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    TextField("Songs, albums, artists...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            hideKeyboard()
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(ColorTheme.cardBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTheme.cardBorder, lineWidth: 1))
                
                if isSearchFocused || !viewModel.searchQuery.isEmpty {
                    Button("Cancel") {
                        isSearchFocused = false
                        viewModel.searchQuery = ""
                        hideKeyboard()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.terracotta)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Search Results or Placeholder
            ScrollView(.vertical, showsIndicators: true) {
                if viewModel.searchQuery.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(ColorTheme.textTertiary)
                            .padding(.top, 60)
                        
                        Text("Search your Navidrome library")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        if !viewModel.searchAlbums.isEmpty {
                            Text("ALBUMS")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(ColorTheme.textTertiary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.searchAlbums) { album in
                                        AlbumCardView(album: album, viewModel: viewModel)
                                            .frame(width: 150)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        if !viewModel.searchSongs.isEmpty {
                            Text("SONGS")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(ColorTheme.textTertiary)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 2) {
                                ForEach(viewModel.searchSongs) { song in
                                    SongRowView(
                                        song: song,
                                        isPlaying: viewModel.currentSong?.id == song.id && !viewModel.mpv.isPaused,
                                        viewModel: viewModel,
                                        onRate: { rating in
                                            viewModel.rateSong(song, rating: rating)
                                        },
                                        onPlay: {
                                            viewModel.playSong(song, inAlbum: nil, queue: viewModel.searchSongs)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ColorTheme.terracotta)
            }
        }
        .background(ColorTheme.windowBackground)
    }
}
#endif

