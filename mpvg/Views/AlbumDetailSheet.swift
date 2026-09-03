//
//  AlbumDetailSheet.swift
//  mpvg
//
//  Detailed album sheet with tracklist, metadata, and direct playback.
//

import SwiftUI

struct AlbumDetailSheet: View {
    let album: AlbumItem
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 20) {
                // Large Cover Art
                artworkView
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(ColorTheme.cardBorder, lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                
                // Metadata
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(album.displayTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(album.displayArtist)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorTheme.terracotta)
                    
                    HStack(spacing: 8) {
                        if !album.displayYear.isEmpty {
                            Text(album.displayYear)
                        }
                        if let genre = album.genre {
                            Text("•")
                            Text(genre)
                        }
                        if let count = album.songCount {
                            Text("•")
                            Text("\(count) pistas")
                        }
                        if !album.formattedDuration.isEmpty {
                            Text("•")
                            Text(album.formattedDuration)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
                    
                    Spacer()
                    
                    // Buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.playAlbum(album)
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("Reproducir Álbum")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ColorTheme.terracotta)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        if let spec = album.suffix, !spec.isEmpty {
                            Text(spec)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(ColorTheme.sageGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(ColorTheme.sageGreenBg)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(24)
            .background(ColorTheme.sidebarBackground)
            
            Divider()
                .background(ColorTheme.cardBorder)
            
            // Tracklist
            if viewModel.isLoadingTracks {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Cargando pistas...")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedAlbumTracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 28))
                        .foregroundColor(ColorTheme.textTertiary)
                    Text("No se encontraron pistas para este álbum")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 2) {
                        ForEach(viewModel.selectedAlbumTracks) { song in
                            SongRowView(
                                song: song,
                                isPlaying: viewModel.currentSong?.id == song.id && !viewModel.mpv.isPaused,
                                onPlay: {
                                    viewModel.playSong(song, inAlbum: album, queue: viewModel.selectedAlbumTracks)
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 580, height: 480)
        .background(ColorTheme.cardBackground)
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
        .aspectRatio(contentMode: .fill)
    }
    
    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [ColorTheme.terracottaLight, ColorTheme.cardBorder],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "opticaldisc")
                .font(.system(size: 40))
                .foregroundColor(ColorTheme.terracotta)
        }
    }
}
