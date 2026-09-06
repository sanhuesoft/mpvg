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
    @State private var showSettingsSheet: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Tab Navigation
            TabView(selection: $selectedTab) {
                NavigationStack {
                    BrowseView(viewModel: viewModel)
                        .navigationTitle("Browse")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                settingsToolbarButton
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                syncToolbarButton
                            }
                        }
                }
                .tabItem {
                    tabItemView(title: "Browse", systemImage: "sparkles")
                }
                .tag(0)
                
                NavigationStack {
                    IOSPlaylistsView(viewModel: viewModel)
                        .navigationTitle("Playlists")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                settingsToolbarButton
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                syncToolbarButton
                            }
                        }
                }
                .tabItem {
                    tabItemView(title: "Listas", systemImage: "music.note.list")
                }
                .tag(1)
                
                NavigationStack {
                    AlbumsGridView(viewModel: viewModel)
                        .navigationTitle("Albums")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                settingsToolbarButton
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                syncToolbarButton
                            }
                        }
                }
                .tabItem {
                    tabItemView(title: "Albums", systemImage: "opticaldisc")
                }
                .tag(2)
                
                NavigationStack {
                    ArtistsGridView(viewModel: viewModel)
                        .navigationTitle("Artists")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                settingsToolbarButton
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                syncToolbarButton
                            }
                        }
                }
                .tabItem {
                    tabItemView(title: "Artists", systemImage: "music.mic")
                }
                .tag(3)
                
                NavigationStack {
                    IOSSearchView(viewModel: viewModel)
                        .navigationTitle("Search")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                settingsToolbarButton
                            }
                        }
                }
                .tabItem {
                    tabItemView(title: "Search", systemImage: "magnifyingglass")
                }
                .tag(4)
            }
            .id(viewModel.tabBarShowsLabels)
            .accentColor(ColorTheme.terracotta)
            
            // Docked Mini Player (Visible when a song is loaded)
            if viewModel.currentSong != nil {
                miniPlayerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 58) // Floating seamlessly above the iOS TabBar with matching margins
            }
        }
        .sheet(isPresented: $showNowPlayingSheet) {
            NowPlayingSheetView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedAlbumForDetail) { album in
            AlbumDetailSheet(album: album, viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedArtistForDetail) { artist in
            ArtistDetailSheet(artist: artist, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showQueueSheet) {
            QueueView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showSettingsSheet = false
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(ColorTheme.terracotta)
                        }
                    }
            }
        }
    }
    
    private var settingsToolbarButton: some View {
        Button(action: { showSettingsSheet = true }) {
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
    
    // MARK: - Mini Player Bar (Liquid Glass Aesthetic)
    private var miniPlayerBar: some View {
        Button(action: { showNowPlayingSheet = true }) {
            VStack(spacing: 0) {
                // Subtle progress indicator on top
                GeometryReader { geo in
                    let progress = viewModel.mpv.duration > 0 ? (viewModel.mpv.currentTime / viewModel.mpv.duration) : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(ColorTheme.cardBorder.opacity(0.4))
                            .frame(height: 2.5)
                        
                        Rectangle()
                            .fill(ColorTheme.terracotta)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 2.5)
                    }
                }
                .frame(height: 2.5)
                
                HStack(spacing: 12) {
                    // Mini Album Cover
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
                                .font(.system(size: 16))
                                .foregroundColor(ColorTheme.terracotta)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentSong?.title ?? "")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(viewModel.currentSong?.displayArtist ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Mini Controls
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.mpv.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ColorTheme.cardBackground.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 5)
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
                        NavigationLink(destination: AlbumsGridView(
                            viewModel: viewModel,
                            customAlbums: viewModel.recentAlbums,
                            title: "Recently Added"
                        )) {
                            smartCollectionRow(
                                title: "Recently Added",
                                subtitle: "\(viewModel.recentAlbums.count) \(viewModel.recentAlbums.count == 1 ? String(localized: "album") : String(localized: "albums"))",
                                iconName: "clock.arrow.circlepath",
                                gradientColors: [Color(hex: "E07A5F"), Color(hex: "B45309")]
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 2. Recently Played
                        NavigationLink(destination: AlbumsGridView(
                            viewModel: viewModel,
                            customAlbums: viewModel.recentlyPlayedAlbums,
                            title: "Recently Played"
                        )) {
                            smartCollectionRow(
                                title: "Recently Played",
                                subtitle: "\(viewModel.recentlyPlayedAlbums.count) \(viewModel.recentlyPlayedAlbums.count == 1 ? String(localized: "album") : String(localized: "albums"))",
                                iconName: "play.circle.fill",
                                gradientColors: [Color(hex: "D97706"), Color(hex: "9A3412")]
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 3. Top Rated (4 & 5 stars)
                        NavigationLink(destination: AlbumsGridView(
                            viewModel: viewModel,
                            customAlbums: viewModel.topRatedAlbums,
                            title: "Top Rated"
                        )) {
                            smartCollectionRow(
                                title: "Top Rated",
                                subtitle: "\(viewModel.topRatedAlbums.count) \(viewModel.topRatedAlbums.count == 1 ? String(localized: "album") : String(localized: "albums")) (4 & 5 stars)",
                                iconName: "star.fill",
                                gradientColors: [Color(hex: "F59E0B"), Color(hex: "D97706")]
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

