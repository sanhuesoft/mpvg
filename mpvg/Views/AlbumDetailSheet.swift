//
//  AlbumDetailView.swift
//  mpvg
//
//  Full-page inline album detail view with tracklist, metadata,
//  hero header, and direct playback controls.
//

import SwiftUI

struct AlbumDetailView: View {
    let album: AlbumItem
    @ObservedObject var viewModel: PlayerViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    private var isCompact: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Header Section
                heroHeaderView
                    .padding(.horizontal, isCompact ? 18 : 28)
                    .padding(.top, isCompact ? 14 : 20)
                    .padding(.bottom, isCompact ? 18 : 24)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                    .padding(.horizontal, isCompact ? 18 : 28)
                
                // Tracklist Header & Songs
                tracklistSection
                    .padding(.horizontal, isCompact ? 16 : 28)
                    .padding(.top, 16)
                    .padding(.bottom, 90) // Clear space for the floating player bar
            }
        }
        .background(ColorTheme.windowBackground)
        .task {
            if viewModel.selectedAlbumTracks.isEmpty || viewModel.selectedAlbumForDetail?.id != album.id {
                viewModel.selectAlbumForDetail(album)
            }
        }
    }
    
    // MARK: - Hero Header View
    @ViewBuilder
    private var heroHeaderView: some View {
        if isCompact {
            compactHeroHeaderView
        } else {
            horizontalHeroHeaderView
        }
    }
    
    // MARK: - Compact Hero Header (iPhone)
    private var compactHeroHeaderView: some View {
        VStack(alignment: .center, spacing: 14) {
            // Prominent Centered Artwork
            artworkView
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ColorTheme.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
            
            // Metadata Stack
            VStack(alignment: .center, spacing: 6) {
                Text("Album")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(ColorTheme.terracotta)
                    .textCase(.uppercase)
                
                Text(album.displayTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Button(action: {
                    if let artistItem = viewModel.artists.first(where: { $0.id == album.artistId || $0.name == album.artist }) {
                        viewModel.navigateToArtist(artistItem)
                    } else {
                        let tempArtist = ArtistItem(
                            id: album.artistId ?? "art-\(album.displayArtist.hashValue)",
                            name: album.displayArtist,
                            albumCount: 1,
                            artistImageUrl: nil
                        )
                        viewModel.navigateToArtist(tempArtist)
                    }
                }) {
                    Text(album.displayArtist)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTheme.terracotta)
                }
                .buttonStyle(.plain)
                
                // Specs & Metadata Row
                HStack(spacing: 6) {
                    if !album.displayYear.isEmpty {
                        Text(album.displayYear)
                    }
                    if let genre = album.genre, !genre.isEmpty {
                        Text("•")
                        Text(genre)
                            .lineLimit(1)
                    }
                    if let count = album.songCount {
                        Text("•")
                        Text("\(count) \(count == 1 ? "track" : "tracks")")
                    }
                    if !album.formattedDuration.isEmpty {
                        Text("•")
                        Text(album.formattedDuration)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                
                // Star Rating & Hi-Res Badge
                HStack(spacing: 8) {
                    StarRatingView(
                        rating: viewModel.selectedAlbumForDetail?.rating ?? album.rating,
                        size: 14,
                        spacing: 3,
                        interactive: true
                    ) { newRating in
                        viewModel.rateAlbum(album, rating: newRating)
                    }
                    
                    let curRating = viewModel.selectedAlbumForDetail?.rating ?? album.rating
                    if curRating > 0 {
                        Text("\(curRating)/5")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                    
                    if let spec = album.suffix, !spec.isEmpty {
                        Text(spec)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorTheme.sageGreen)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(ColorTheme.sageGreenBg)
                            .cornerRadius(5)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            
            // Action Buttons (Equally balanced side-by-side)
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.playAlbum(album)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Play Album")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .background(ColorTheme.terracotta)
                    .cornerRadius(10)
                    .shadow(color: ColorTheme.terracotta.opacity(0.35), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    viewModel.addAlbumToQueue(album)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add to Queue")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(ColorTheme.textPrimary)
                    .padding(.vertical, 10)
                    .background(ColorTheme.inputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ColorTheme.cardBorder, lineWidth: 1)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Desktop / Tablet Hero Header
    private var horizontalHeroHeaderView: some View {
        HStack(alignment: .bottom, spacing: 24) {
            // Large Cover Artwork
            artworkView
                .frame(width: 170, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTheme.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
            
            // Metadata & Controls
            VStack(alignment: .leading, spacing: 8) {
                // Type badge
                Text("Album")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(ColorTheme.terracotta)
                
                // Album Title
                Text(album.displayTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(2)
                
                // Artist Name (Clickable to navigate to artist page)
                Button(action: {
                    if let artistItem = viewModel.artists.first(where: { $0.id == album.artistId || $0.name == album.artist }) {
                        viewModel.navigateToArtist(artistItem)
                    } else {
                        let tempArtist = ArtistItem(
                            id: album.artistId ?? "art-\(album.displayArtist.hashValue)",
                            name: album.displayArtist,
                            albumCount: 1,
                            artistImageUrl: nil
                        )
                        viewModel.navigateToArtist(tempArtist)
                    }
                }) {
                    Text(album.displayArtist)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTheme.terracotta)
                        .underline(false)
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                
                // Specs & Metadata row
                HStack(spacing: 8) {
                    if !album.displayYear.isEmpty {
                        Text(album.displayYear)
                    }
                    if let genre = album.genre, !genre.isEmpty {
                        Text("•")
                        Text(genre)
                    }
                    if let count = album.songCount {
                        Text("•")
                        if count == 1 {
                            Text("\(count) track")
                        } else {
                            Text("\(count) tracks")
                        }
                    }
                    if !album.formattedDuration.isEmpty {
                        Text("•")
                        Text(album.formattedDuration)
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(ColorTheme.textSecondary)
                
                // Star Rating & Hi-Res Badge
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        StarRatingView(
                            rating: viewModel.selectedAlbumForDetail?.rating ?? album.rating,
                            size: 14,
                            spacing: 3,
                            interactive: true
                        ) { newRating in
                            viewModel.rateAlbum(album, rating: newRating)
                        }
                        
                        let curRating = viewModel.selectedAlbumForDetail?.rating ?? album.rating
                        if curRating > 0 {
                            Text("\(curRating)/5")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(ColorTheme.terracotta)
                        }
                    }
                    
                    if let spec = album.suffix, !spec.isEmpty {
                        Text(spec)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(ColorTheme.sageGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(ColorTheme.sageGreenBg)
                            .cornerRadius(6)
                    }
                }
                .padding(.top, 2)
                
                // Play & Queue Action Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.playAlbum(album)
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Play Album")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(ColorTheme.terracotta)
                        .cornerRadius(9)
                        .shadow(color: ColorTheme.terracotta.opacity(0.35), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                    
                    Button(action: {
                        viewModel.addAlbumToQueue(album)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Add to Queue")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(ColorTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(ColorTheme.inputBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(ColorTheme.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Tracklist Section
    @ViewBuilder
    private var tracklistSection: some View {
        if viewModel.isLoadingTracks {
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.1)
                Text("Loading tracks...")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else if viewModel.selectedAlbumTracks.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 32))
                    .foregroundColor(ColorTheme.textTertiary)
                Text("No tracks found for this album")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Table Columns Header
                HStack(spacing: 12) {
                    Text("#")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 24, alignment: .center)
                    
                    Text("TITLE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Spacer()
                    
                    Text("FORMAT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 70, alignment: .center)
                    
                    Text("RATING")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 75, alignment: .trailing)
                    
                    Text("TIME")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                
                Divider()
                    .background(ColorTheme.cardBorder.opacity(0.6))
                    .padding(.bottom, 4)
                
                // Track Rows
                VStack(spacing: 2) {
                    ForEach(viewModel.selectedAlbumTracks) { song in
                        SongRowView(
                            song: song,
                            isPlaying: viewModel.currentSong?.id == song.id && !viewModel.mpv.isPaused,
                            viewModel: viewModel,
                            onRate: { newRating in
                                viewModel.rateSong(song, rating: newRating)
                            },
                            onPlay: {
                                viewModel.playSong(song, inAlbum: album, queue: viewModel.selectedAlbumTracks)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Artwork Helpers
    @ViewBuilder
    private var artworkView: some View {
        let artURL: URL? = {
            if let coverId = album.coverArt, let url = viewModel.coverArtURL(for: coverId) {
                return url
            } else if let cover = album.coverArt, cover.hasPrefix("http"), let url = URL(string: cover) {
                return url
            }
            return nil
        }()
        
        CachedAsyncImage(url: artURL) {
            placeholderArtwork
        }
        .aspectRatio(1.0, contentMode: .fill)
    }
    
    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [ColorTheme.terracottaLight, ColorTheme.cardBorder],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "opticaldisc")
                .font(.system(size: 54))
                .foregroundColor(ColorTheme.terracotta)
        }
    }
}

// Backward-compatibility alias
typealias AlbumDetailSheet = AlbumDetailView
