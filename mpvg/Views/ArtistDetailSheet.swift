//
//  ArtistDetailSheet.swift
//  mpvg
//
//  Detailed artist sheet with artist profile, discography albums grid, and quick playback.
//

import SwiftUI

struct ArtistDetailSheet: View {
    let artist: ArtistItem
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 190), spacing: 14)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 18) {
                // Circular Avatar
                avatarView
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(ColorTheme.cardBorder, lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                
                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(artist.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Artist")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTheme.terracotta)
                    
                    let albumCount = viewModel.selectedArtistAlbums.isEmpty ? (artist.albumCount ?? 0) : viewModel.selectedArtistAlbums.count
                    Text("\(albumCount) \(albumCount == 1 ? "album" : "albums") in library")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
            .padding(20)
            .background(ColorTheme.sidebarBackground)
            
            Divider()
                .background(ColorTheme.cardBorder)
            
            // Albums Content
            if viewModel.isLoadingArtistAlbums {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading albums...")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedArtistAlbums.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 28))
                        .foregroundColor(ColorTheme.textTertiary)
                    Text("No albums found for this artist")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DISCOGRAPHY")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                        
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(viewModel.selectedArtistAlbums) { album in
                                AlbumCardView(album: album, viewModel: viewModel)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 580, height: 480)
        #else
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
        .background(ColorTheme.cardBackground)
        .task {
            if viewModel.selectedArtistAlbums.isEmpty || viewModel.selectedArtistForDetail?.id != artist.id {
                viewModel.selectArtistForDetail(artist)
            }
        }
    }
    
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
                    .font(.system(size: 32))
                    .foregroundColor(ColorTheme.terracotta)
            }
        }
        .aspectRatio(contentMode: .fill)
    }
}
