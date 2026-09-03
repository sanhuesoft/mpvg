//
//  AlbumCardView.swift
//  mpvg
//
//  Album item with large square cover art as the hero element,
//  hover playback controls, and a clean metadata strip below.
//

import SwiftUI

struct AlbumCardView: View {
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
        VStack(alignment: .leading, spacing: 8) {
            // Hero Cover Art (Perfect 1:1 Square)
            ZStack(alignment: .bottomTrailing) {
                artworkView
                    .aspectRatio(1.0, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ColorTheme.cardBorder, lineWidth: 1)
                    )
                
                // Hover Overlay with Play Button & Info Button
                if isHovered || isCurrentlyPlaying {
                    ZStack {
                        Color.black.opacity(isHovered ? 0.35 : 0.15)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        // Top right info button
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    viewModel.selectAlbumForDetail(album)
                                }) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(radius: 3)
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                            }
                            Spacer()
                        }
                        
                        // Center Play / Pause Button
                        Button(action: {
                            if isThisAlbumLoaded {
                                viewModel.togglePlayPause()
                            } else {
                                viewModel.playAlbum(album)
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isCurrentlyPlaying ? ColorTheme.sageGreen : ColorTheme.terracotta)
                                    .frame(width: 42, height: 42)
                                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                                
                                Image(systemName: isCurrentlyPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: isCurrentlyPlaying ? 0 : 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Metadata Strip Below Cover
            VStack(alignment: .leading, spacing: 3) {
                Text(album.displayTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                
                Text(album.displayArtist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorTheme.textSecondary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if !album.displayYear.isEmpty {
                        Text(album.displayYear)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    
                    if let genre = album.genre, !genre.isEmpty {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(ColorTheme.textTertiary)
                        Text(genre)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ColorTheme.textTertiary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if album.rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(ColorTheme.terracotta)
                            Text("\(album.rating)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(ColorTheme.terracotta)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(ColorTheme.terracottaLight.opacity(0.6))
                        .cornerRadius(4)
                    }
                    
                    if isCurrentlyPlaying {
                        HStack(spacing: 3) {
                            Circle().fill(ColorTheme.sageGreen).frame(width: 5, height: 5)
                            Text("Playing")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(ColorTheme.sageGreen)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(ColorTheme.sageGreenBg)
                        .cornerRadius(4)
                    } else if let suffix = album.suffix, !suffix.isEmpty {
                        Text(suffix)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(ColorTheme.terracotta)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(ColorTheme.terracottaLight.opacity(0.5))
                            .cornerRadius(3)
                    }
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .background(ColorTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHovered ? ColorTheme.cardBorderHover : ColorTheme.cardBorder, lineWidth: 1.2)
        )
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 8 : 3, x: 0, y: isHovered ? 3 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            viewModel.selectAlbumForDetail(album)
        }
    }
    
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
                .font(.system(size: 36))
                .foregroundColor(ColorTheme.terracotta)
        }
        .aspectRatio(1.0, contentMode: .fill)
    }
}
