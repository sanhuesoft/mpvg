//
//  BrowseView.swift
//  mpvg
//
//  Main browse view displaying grouped sections ("Most Popular", "Recently Added")
//  with CaskHub square album cards and circular artist cards.
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
                        albumGridSection(title: "Recently Added", albums: viewModel.recentAlbums)
                    case .albums:
                        albumGridSection(title: "All Albums", albums: viewModel.albums)
                    case .artists:
                        artistsGridSection
                    case .playlists, .genres:
                        albumGridSection(title: viewModel.activeTab.rawValue, albums: viewModel.albums)
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
                    VStack(spacing: 4) {
                        ForEach(viewModel.featuredAlbums) { album in
                            albumListRow(album: album)
                        }
                    }
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
                    VStack(spacing: 4) {
                        ForEach(viewModel.recentAlbums) { album in
                            albumListRow(album: album)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Artists Section
    private var artistsGridSection: some View {
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
            
            LazyVGrid(columns: artistColumns, spacing: 14) {
                ForEach(viewModel.artists) { artist in
                    ArtistCardView(artist: artist, viewModel: viewModel)
                }
            }
        }
    }
    
    // MARK: - Generic Album Section
    private func albumGridSection(title: String, albums: [AlbumItem]) -> some View {
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
                VStack(spacing: 4) {
                    ForEach(albums) { album in
                        albumListRow(album: album)
                    }
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
                    LazyVGrid(columns: albumColumns, spacing: 14) {
                        ForEach(viewModel.searchAlbums) { album in
                            AlbumCardView(album: album, viewModel: viewModel)
                        }
                    }
                }
                
                if !viewModel.searchSongs.isEmpty {
                    VStack(spacing: 4) {
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
    
    // MARK: - List Mode Row
    private func albumListRow(album: AlbumItem) -> some View {
        HStack(spacing: 12) {
            Text(album.displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text(album.displayArtist)
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
            
            Spacer()
            
            Text(album.displaySpecs)
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textTertiary)
            
            Button(action: {
                viewModel.playAlbum(album)
            }) {
                Text("▶ Play")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ColorTheme.terracotta)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ColorTheme.terracottaLight.opacity(0.4))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ColorTheme.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.navigateToAlbum(album)
        }
        .pointingHandOnHover()
    }
}
