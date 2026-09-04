//
//  ArtistDetailView.swift
//  mpvg
//
//  Full-page inline artist profile view with discography grid
//  and seamless navigation to albums.
//

import SwiftUI

struct ArtistDetailView: View {
    let artist: ArtistItem
    @ObservedObject var viewModel: PlayerViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 165, maximum: 220), spacing: 14)
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Header Section
                heroHeaderView
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                    .padding(.horizontal, 28)
                
                // Discography Grid Section
                discographySection
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 90) // Clear space for the floating player bar
            }
        }
        .background(ColorTheme.windowBackground)
        .task {
            if viewModel.selectedArtistAlbums.isEmpty || viewModel.selectedArtistForDetail?.id != artist.id {
                viewModel.selectArtistForDetail(artist)
            }
        }
    }
    
    // MARK: - Hero Header View
    private var heroHeaderView: some View {
        HStack(alignment: .center, spacing: 24) {
            // Circular Avatar
            avatarView
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(ColorTheme.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
            
            // Metadata & Controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Artist")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(ColorTheme.terracotta)
                
                Text(artist.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                
                let albumCount = viewModel.selectedArtistAlbums.isEmpty ? (artist.albumCount ?? 0) : viewModel.selectedArtistAlbums.count
                Text("\(albumCount) \(albumCount == 1 ? "album" : "albums") in library")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ColorTheme.textSecondary)
                
                if let firstAlbum = viewModel.selectedArtistAlbums.first {
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.playAlbum(firstAlbum)
                        }) {
                            HStack(spacing: 7) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Play Artist")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ColorTheme.terracotta)
                            .cornerRadius(9)
                            .shadow(color: ColorTheme.terracotta.opacity(0.35), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .pointingHandOnHover()
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Discography Section
    @ViewBuilder
    private var discographySection: some View {
        if viewModel.isLoadingArtistAlbums {
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.1)
                Text("Loading albums...")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else if viewModel.selectedArtistAlbums.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "opticaldisc")
                    .font(.system(size: 32))
                    .foregroundColor(ColorTheme.textTertiary)
                Text("No albums found for this artist")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("DISCOGRAPHY")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(viewModel.selectedArtistAlbums) { album in
                        AlbumCardView(album: album, viewModel: viewModel)
                    }
                }
            }
        }
    }
    
    // MARK: - Avatar View
    @ViewBuilder
    private var avatarView: some View {
        let avatarURL = artist.artistImageUrl.flatMap { URL(string: $0) }
        CachedAsyncImage(url: avatarURL) {
            ZStack {
                LinearGradient(
                    colors: [ColorTheme.terracottaLight, ColorTheme.cardBorder],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundColor(ColorTheme.terracotta)
            }
        }
        .aspectRatio(contentMode: .fill)
    }
}

// Backward-compatibility alias
typealias ArtistDetailSheet = ArtistDetailView
