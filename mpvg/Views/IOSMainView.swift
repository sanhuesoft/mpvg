//
//  IOSMainView.swift
//  mpvg
//
//  Tailored iPhone and compact iOS layout featuring a native bottom TabView,
//  a docked Mini Player bar, and an interactive Now Playing sheet.
//

import SwiftUI

struct IOSMainView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var selectedTab: Int = 0
    @State private var showNowPlayingSheet: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Tab Navigation
            TabView(selection: $selectedTab) {
                NavigationStack {
                    BrowseView(viewModel: viewModel)
                        .navigationTitle("Browse")
                }
                .tabItem {
                    Label("Browse", systemImage: "sparkles")
                }
                .tag(0)
                
                NavigationStack {
                    AlbumsGridView(viewModel: viewModel)
                        .navigationTitle("Albums")
                }
                .tabItem {
                    Label("Albums", systemImage: "opticaldisc")
                }
                .tag(1)
                
                NavigationStack {
                    ArtistsGridView(viewModel: viewModel)
                        .navigationTitle("Artists")
                }
                .tabItem {
                    Label("Artists", systemImage: "music.mic")
                }
                .tag(2)
                
                NavigationStack {
                    IOSSearchView(viewModel: viewModel)
                        .navigationTitle("Search")
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(3)
                
                NavigationStack {
                    SettingsView(viewModel: viewModel)
                        .navigationTitle("Settings")
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
            }
            .accentColor(ColorTheme.terracotta)
            
            // Docked Mini Player (Visible when a song is loaded)
            if viewModel.currentSong != nil {
                miniPlayerBar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 54) // Sits neatly above the iOS TabBar
            }
        }
        .sheet(isPresented: $showNowPlayingSheet) {
            NowPlayingSheetView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedAlbumForDetail) { album in
            AlbumDetailSheet(album: album, viewModel: viewModel)
        }
    }
    
    // MARK: - Mini Player Bar
    private var miniPlayerBar: some View {
        Button(action: { showNowPlayingSheet = true }) {
            VStack(spacing: 0) {
                // Subtle progress indicator on top
                GeometryReader { geo in
                    let progress = viewModel.mpv.duration > 0 ? (viewModel.mpv.currentTime / viewModel.mpv.duration) : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(ColorTheme.cardBorder)
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(ColorTheme.terracotta)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 2)
                    }
                }
                .frame(height: 2)
                
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
                            ColorTheme.cardBorder
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 16))
                                .foregroundColor(ColorTheme.terracotta)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ColorTheme.cardBorder, lineWidth: 1))
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentSong?.title ?? "")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(viewModel.currentSong?.displayArtist ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Mini Controls
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.mpv.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18))
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ColorTheme.cardBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ColorTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Standalone Tab Views for iPhone
struct AlbumsGridView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 14)
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.albums) { album in
                    AlbumCardView(album: album, viewModel: viewModel)
                }
            }
            .padding(16)
            .padding(.bottom, 60) // Extra padding for mini-player
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
        .background(ColorTheme.windowBackground)
    }
}

struct IOSSearchView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ColorTheme.textSecondary)
                
                TextField("Songs, albums, artists...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
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
        }
        .background(ColorTheme.windowBackground)
    }
}
