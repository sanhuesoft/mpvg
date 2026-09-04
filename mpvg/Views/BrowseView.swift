//
//  BrowseView.swift
//  mpvg
//
//  Main browse view displaying grouped sections ("Most Popular", "Recently Added")
//  with CaskHub square album cards, circular artist cards, and unified table list views.
//

import SwiftUI

struct BrowseView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    private let albumColumns = [
        GridItem(.adaptive(minimum: 165, maximum: 220), spacing: 14)
    ]
    
    private let artistColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 14)
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.searchQuery.isEmpty {
                    searchSection
                } else {
                    switch viewModel.activeTab {
                    case .browse:
                        defaultBrowseContent
                    case .recentlyAdded:
                        albumSection(title: "Recently Added", albums: viewModel.recentAlbums)
                    case .albums:
                        albumSection(title: "All Albums", albums: viewModel.albums)
                    case .artists:
                        artistsSection
                    case .playlists, .genres:
                        albumSection(title: viewModel.activeTab.rawValue, albums: viewModel.albums)
                    case .settings:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 80)
        }
        .background(ColorTheme.windowBackground)
    }
    
    // MARK: - Default Browse Content
    private var defaultBrowseContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            // Section 1: Most Popular
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Most Popular") {
                    viewModel.activeTab = .albums
                }
                
                if viewModel.viewMode == .grid {
                    LazyVGrid(columns: albumColumns, spacing: 14) {
                        ForEach(viewModel.featuredAlbums) { album in
                            AlbumCardView(album: album, viewModel: viewModel)
                        }
                    }
                } else {
                    albumTableView(albums: viewModel.featuredAlbums)
                }
            }
            
            // Section 2: Recently Added
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Recently Added") {
                    viewModel.activeTab = .recentlyAdded
                }
                
                if viewModel.viewMode == .grid {
                    LazyVGrid(columns: albumColumns, spacing: 14) {
                        ForEach(viewModel.recentAlbums) { album in
                            AlbumCardView(album: album, viewModel: viewModel)
                        }
                    }
                } else {
                    albumTableView(albums: viewModel.recentAlbums)
                }
            }
        }
    }
    
    // MARK: - Artists Section
    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Artists")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                Spacer()
                Text("\(viewModel.artists.count) artists")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textTertiary)
            }
            
            if viewModel.viewMode == .grid {
                LazyVGrid(columns: artistColumns, spacing: 14) {
                    ForEach(viewModel.artists) { artist in
                        ArtistCardView(artist: artist, viewModel: viewModel)
                    }
                }
            } else {
                artistTableView(artists: viewModel.artists)
            }
        }
    }
    
    // MARK: - Generic Album Section
    private func albumSection(title: String, albums: [AlbumItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                Spacer()
            }
            
            if viewModel.viewMode == .grid {
                LazyVGrid(columns: albumColumns, spacing: 14) {
                    ForEach(albums) { album in
                        AlbumCardView(album: album, viewModel: viewModel)
                    }
                }
            } else {
                albumTableView(albums: albums)
            }
        }
    }
    
    // MARK: - Unified Album Table View (List Mode)
    private func albumTableView(albums: [AlbumItem]) -> some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 12) {
                Text("#")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 28, alignment: .center)
                
                Text("ALBUM")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("ARTIST")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 180, alignment: .leading)
                
                Text("YEAR / GENRE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 140, alignment: .leading)
                
                Text("FORMAT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 65, alignment: .center)
                
                Text("TRACKS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 75, alignment: .trailing)
                
                Text("PLAY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            
            Divider()
                .background(ColorTheme.cardBorder.opacity(0.6))
                .padding(.bottom, 4)
            
            // Table Rows (LazyVStack for smooth 60fps scrolling with large libraries)
            LazyVStack(spacing: 2) {
                ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
                    AlbumTableRowView(
                        index: index + 1,
                        album: album,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
    
    // MARK: - Unified Artist Table View (List Mode)
    private func artistTableView(artists: [ArtistItem]) -> some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 12) {
                Text("#")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 28, alignment: .center)
                
                Text("ARTIST")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("ALBUMS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 120, alignment: .trailing)
                
                Text("")
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            
            Divider()
                .background(ColorTheme.cardBorder.opacity(0.6))
                .padding(.bottom, 4)
            
            // Table Rows (LazyVStack for high performance)
            LazyVStack(spacing: 2) {
                ForEach(Array(artists.enumerated()), id: \.element.id) { index, artist in
                    ArtistTableRowView(
                        index: index + 1,
                        artist: artist,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results for \"\(viewModel.searchQuery)\"")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            if viewModel.searchAlbums.isEmpty && viewModel.searchSongs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(ColorTheme.textTertiary)
                    Text("No albums or songs found")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                if !viewModel.searchAlbums.isEmpty {
                    if viewModel.viewMode == .grid {
                        LazyVGrid(columns: albumColumns, spacing: 14) {
                            ForEach(viewModel.searchAlbums) { album in
                                AlbumCardView(album: album, viewModel: viewModel)
                            }
                        }
                    } else {
                        albumTableView(albums: viewModel.searchAlbums)
                    }
                }
                
                if !viewModel.searchSongs.isEmpty {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.searchSongs) { song in
                            SongRowView(
                                song: song,
                                isPlaying: viewModel.currentSong?.id == song.id && !viewModel.mpv.isPaused,
                                onRate: { newRating in
                                    viewModel.rateSong(song, rating: newRating)
                                },
                                onPlay: {
                                    viewModel.playSong(song, inAlbum: nil, queue: viewModel.searchSongs)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Section Header with "View All"
    private func sectionHeader(title: String, onViewAll: @escaping () -> Void) -> some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Spacer()
            
            Button(action: onViewAll) {
                Text("View All")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ColorTheme.terracotta)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
        }
    }
}

// MARK: - Unified Album Table Row View
struct AlbumTableRowView: View {
    let index: Int
    let album: AlbumItem
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovered: Bool = false
    
    var isCurrentlyPlaying: Bool {
        viewModel.currentAlbum?.id == album.id && !viewModel.mpv.isPaused
    }
    
    var isThisAlbumLoaded: Bool {
        viewModel.currentAlbum?.id == album.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Index # or Waveform
            ZStack {
                if isCurrentlyPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ColorTheme.terracotta)
                } else if isHovered {
                    Button(action: {
                        if isThisAlbumLoaded {
                            viewModel.togglePlayPause()
                        } else {
                            viewModel.playAlbum(album)
                        }
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                } else {
                    Text("\(index)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
            .frame(width: 28, alignment: .center)
            
            // Mini Cover Thumbnail + Title
            HStack(spacing: 10) {
                let artURL: URL? = {
                    if let coverId = album.coverArt, let url = viewModel.coverArtURL(for: coverId) {
                        return url
                    } else if let cover = album.coverArt, cover.hasPrefix("http"), let url = URL(string: cover) {
                        return url
                    }
                    return nil
                }()
                
                CachedAsyncImage(url: artURL) {
                    ZStack {
                        ColorTheme.cardBorder.opacity(0.5)
                        Image(systemName: "opticaldisc")
                            .font(.system(size: 13))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                }
                .frame(width: 32, height: 32)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(ColorTheme.cardBorder, lineWidth: 0.8))
                
                Text(album.displayTitle)
                    .font(.system(size: 13, weight: isCurrentlyPlaying ? .bold : .semibold))
                    .foregroundColor(isCurrentlyPlaying ? ColorTheme.terracotta : ColorTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Artist
            Text(album.displayArtist)
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 180, alignment: .leading)
            
            // Year & Genre
            HStack(spacing: 4) {
                if !album.displayYear.isEmpty {
                    Text(album.displayYear)
                }
                if let genre = album.genre, !genre.isEmpty {
                    if !album.displayYear.isEmpty {
                        Text("•")
                    }
                    Text(genre)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.system(size: 11))
            .foregroundColor(ColorTheme.textTertiary)
            .lineLimit(1)
            .frame(width: 140, alignment: .leading)
            
            // Format Badge
            ZStack {
                if let spec = album.suffix, !spec.isEmpty {
                    Text(spec.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ColorTheme.sageGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTheme.sageGreenBg)
                        .cornerRadius(4)
                        .lineLimit(1)
                }
            }
            .frame(width: 65, alignment: .center)
            
            // Track Count
            let count = album.songCount ?? 0
            Group {
                if count == 1 {
                    Text("\(count) track")
                } else {
                    Text("\(count) tracks")
                }
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(ColorTheme.textTertiary)
            .lineLimit(1)
            .frame(width: 75, alignment: .trailing)
            
            // Quick Play Button
            Button(action: {
                if isThisAlbumLoaded {
                    viewModel.togglePlayPause()
                } else {
                    viewModel.playAlbum(album)
                }
            }) {
                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isCurrentlyPlaying ? ColorTheme.sageGreen : ColorTheme.terracotta)
                    .frame(width: 26, height: 24)
                    .background(isCurrentlyPlaying ? ColorTheme.sageGreenBg : ColorTheme.terracottaLight.opacity(0.5))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
            .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isCurrentlyPlaying ? ColorTheme.terracottaLight.opacity(0.35) :
                (isHovered ? ColorTheme.cardBorder.opacity(0.35) : Color.clear)
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            viewModel.navigateToAlbum(album)
        }
        .pointingHandOnHover()
    }
}

// MARK: - Unified Artist Table Row View
struct ArtistTableRowView: View {
    let index: Int
    let artist: ArtistItem
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Index #
            Text("\(index)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(ColorTheme.textTertiary)
                .frame(width: 28, alignment: .center)
            
            // Mini Circular Avatar + Artist Name
            HStack(spacing: 10) {
                let avatarURL = artist.artistImageUrl.flatMap { URL(string: $0) }
                CachedAsyncImage(url: avatarURL) {
                    ZStack {
                        ColorTheme.terracottaLight
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(ColorTheme.cardBorder, lineWidth: 0.8))
                
                Text(artist.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Album Count
            if let count = artist.albumCount, count > 0 {
                Text("\(count) \(count == 1 ? String(localized: "album") : String(localized: "albums"))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 120, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 120, alignment: .trailing)
            }
            
            // Navigation chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isHovered ? ColorTheme.terracotta : ColorTheme.textTertiary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isHovered ? ColorTheme.cardBorder.opacity(0.35) : Color.clear
        )
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            viewModel.navigateToArtist(artist)
        }
        .pointingHandOnHover()
    }
}
