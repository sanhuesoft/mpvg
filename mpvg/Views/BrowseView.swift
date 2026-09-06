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
                    case .recentlyPlayed:
                        albumSection(title: "Recently Played", albums: viewModel.recentlyPlayedAlbums)
                    case .topRated:
                        albumSection(title: "Top Rated", albums: viewModel.topRatedAlbums)
                    case .albums:
                        albumSection(title: "All Albums", albums: viewModel.albums)
                    case .artists:
                        artistsSection
                    case .playlists:
                        playlistsSection
                    case .genres:
                        genresSection
                    case .settings:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 80)
        }
        .refreshable {
            await viewModel.syncLibrary()
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
            
            // Section 3: Recently Played
            if !viewModel.recentlyPlayedAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "Recently Played") {
                        viewModel.activeTab = .recentlyPlayed
                    }
                    
                    if viewModel.viewMode == .grid {
                        LazyVGrid(columns: albumColumns, spacing: 14) {
                            ForEach(viewModel.recentlyPlayedAlbums) { album in
                                AlbumCardView(album: album, viewModel: viewModel)
                            }
                        }
                    } else {
                        albumTableView(albums: viewModel.recentlyPlayedAlbums)
                    }
                }
            }
            
            // Section 4: Top Rated (4 & 5 stars)
            if !viewModel.topRatedAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "Top Rated") {
                        viewModel.activeTab = .topRated
                    }
                    
                    if viewModel.viewMode == .grid {
                        LazyVGrid(columns: albumColumns, spacing: 14) {
                            ForEach(viewModel.topRatedAlbums) { album in
                                AlbumCardView(album: album, viewModel: viewModel)
                            }
                        }
                    } else {
                        albumTableView(albums: viewModel.topRatedAlbums)
                    }
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
    
    // MARK: - Playlists Section
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Playlists")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                Spacer()
                if !viewModel.playlists.isEmpty {
                    Text("\(viewModel.playlists.count) playlists")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
            
            if viewModel.playlists.isEmpty {
                emptyStateView(
                    icon: "music.note.list",
                    title: "No playlists found",
                    message: "Playlists from your server will appear here."
                )
            } else {
                if viewModel.viewMode == .grid {
                    LazyVGrid(columns: albumColumns, spacing: 14) {
                        ForEach(viewModel.playlists) { playlist in
                            PlaylistCardView(playlist: playlist, viewModel: viewModel)
                        }
                    }
                } else {
                    playlistTableView(playlists: viewModel.playlists)
                }
            }
        }
    }
    
    // MARK: - Genres Section
    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Genres")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                Spacer()
                if !viewModel.genres.isEmpty {
                    Text("\(viewModel.genres.count) genres")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
            
            if viewModel.genres.isEmpty {
                emptyStateView(
                    icon: "tag",
                    title: "No genres found",
                    message: "Music genres defined in your library will appear here."
                )
            } else {
                if viewModel.viewMode == .grid {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        ForEach(viewModel.genres) { genre in
                            GenreCardView(genre: genre, viewModel: viewModel)
                        }
                    }
                } else {
                    genreTableView(genres: viewModel.genres)
                }
            }
        }
    }
    
    // MARK: - Empty State View
    private func emptyStateView(icon: String, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(ColorTheme.textTertiary.opacity(0.6))
                .padding(.bottom, 2)
            
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(ColorTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
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
    
    // MARK: - Playlist Table View (List Mode)
    private func playlistTableView(playlists: [PlaylistItem]) -> some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 12) {
                Text("#")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 28, alignment: .center)
                
                Text("PLAYLIST")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("TRACKS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 100, alignment: .trailing)
                
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
            
            LazyVStack(spacing: 2) {
                ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
                    PlaylistTableRowView(
                        index: index + 1,
                        playlist: playlist,
                        viewModel: viewModel
                    )
                }
            }
        }
    }
    
    // MARK: - Genre Table View (List Mode)
    private func genreTableView(genres: [GenreItem]) -> some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 12) {
                Text("#")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 28, alignment: .center)
                
                Text("GENRE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("ALBUMS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 100, alignment: .trailing)
                
                Text("TRACKS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            
            Divider()
                .background(ColorTheme.cardBorder.opacity(0.6))
                .padding(.bottom, 4)
            
            LazyVStack(spacing: 2) {
                ForEach(Array(genres.enumerated()), id: \.element.id) { index, genre in
                    GenreTableRowView(
                        index: index + 1,
                        genre: genre,
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
                                viewModel: viewModel,
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
        .contextMenu {
            Button {
                if isThisAlbumLoaded {
                    viewModel.togglePlayPause()
                } else {
                    viewModel.playAlbum(album)
                }
            } label: {
                Label(isCurrentlyPlaying ? "Pausar álbum" : "Reproducir álbum", systemImage: isCurrentlyPlaying ? "pause.fill" : "play.fill")
            }
            
            Divider()
            
            Button {
                viewModel.playAlbumNext(album)
            } label: {
                Label("Añadir a continuación", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Button {
                viewModel.addAlbumToQueue(album)
            } label: {
                Label("Añadir al final de la cola", systemImage: "text.line.last.and.arrowtriangle.forward")
            }
            
            Divider()
            
            if !album.displayArtist.isEmpty && album.displayArtist != "Unknown Artist" {
                Button {
                    viewModel.navigateToArtist(for: album)
                } label: {
                    Label("Ver artista", systemImage: "music.mic")
                }
            }
        }
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
                let avatarURL = viewModel.artistAvatarURL(for: artist)
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

// MARK: - Playlist Card View
struct PlaylistCardView: View {
    let playlist: PlaylistItem
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let coverId = playlist.coverArt, let url = viewModel.coverArtURL(for: coverId) {
                    CachedAsyncImage(url: url) {
                        placeholder
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(10)
                } else {
                    placeholder
                }
                
                if isHovered {
                    Color.black.opacity(0.25)
                        .cornerRadius(10)
                    
                    Button(action: {
                        viewModel.playPlaylist(playlist)
                    }) {
                        Circle()
                            .fill(ColorTheme.terracotta)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .offset(x: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                
                if let count = playlist.songCount {
                    Text("\(count) \(count == 1 ? String(localized: "track") : String(localized: "tracks"))")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(ColorTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? ColorTheme.cardBorderHover : ColorTheme.cardBorder, lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 3, x: 0, y: isHovered ? 3 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
        .pointingHandOnHover()
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(ColorTheme.terracottaLight.opacity(0.35))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: "music.note.list")
                    .font(.system(size: 36))
                    .foregroundColor(ColorTheme.terracotta.opacity(0.7))
            )
    }
}

// MARK: - Playlist Table Row View
struct PlaylistTableRowView: View {
    let index: Int
    let playlist: PlaylistItem
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(ColorTheme.textTertiary)
                .frame(width: 28, alignment: .center)
            
            HStack(spacing: 10) {
                let artURL: URL? = {
                    if let coverId = playlist.coverArt, let url = viewModel.coverArtURL(for: coverId) {
                        return url
                    }
                    return nil
                }()
                
                CachedAsyncImage(url: artURL) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ColorTheme.terracottaLight.opacity(0.35))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.terracotta)
                        )
                }
                .frame(width: 32, height: 32)
                .cornerRadius(5)
                
                Text(playlist.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let count = playlist.songCount {
                Text("\(count) \(count == 1 ? String(localized: "track") : String(localized: "tracks"))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 100, alignment: .trailing)
            } else {
                Text("-")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 100, alignment: .trailing)
            }
            
            Button(action: {
                viewModel.playPlaylist(playlist)
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isHovered ? ColorTheme.terracotta : ColorTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
            .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            isHovered ? ColorTheme.cardBorder.opacity(0.35) : Color.clear
        )
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovered = hovering
            }
        }
    }
}

// MARK: - Genre Card View
struct GenreCardView: View {
    let genre: GenreItem
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: {
            viewModel.searchQuery = genre.value
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(ColorTheme.terracottaLight.opacity(0.6))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "tag.fill")
                            .font(.system(size: 15))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                    Spacer()
                }
                
                Text(genre.value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if let albums = genre.albumCount, albums > 0 {
                        Text("\(albums) \(albums == 1 ? String(localized: "album") : String(localized: "albums"))")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textSecondary)
                    } else if let songs = genre.songCount, songs > 0 {
                        Text("\(songs) \(songs == 1 ? String(localized: "track") : String(localized: "tracks"))")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textSecondary)
                    } else {
                        Text("Genre")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? ColorTheme.cardBorderHover : ColorTheme.cardBorder, lineWidth: 1)
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 3, x: 0, y: isHovered ? 3 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
        .pointingHandOnHover()
    }
}

// MARK: - Genre Table Row View
struct GenreTableRowView: View {
    let index: Int
    let genre: GenreItem
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: {
            viewModel.searchQuery = genre.value
        }) {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 28, alignment: .center)
                
                HStack(spacing: 10) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.terracotta)
                    
                    Text(genre.value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTheme.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if let count = genre.albumCount, count > 0 {
                    Text("\(count) \(count == 1 ? String(localized: "album") : String(localized: "albums"))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 100, alignment: .trailing)
                } else {
                    Text("-")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 100, alignment: .trailing)
                }
                
                if let count = genre.songCount, count > 0 {
                    Text("\(count) \(count == 1 ? String(localized: "track") : String(localized: "tracks"))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 100, alignment: .trailing)
                } else {
                    Text("-")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 100, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isHovered ? ColorTheme.cardBorder.opacity(0.35) : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isHovered = hovering
            }
        }
        .pointingHandOnHover()
    }
}
