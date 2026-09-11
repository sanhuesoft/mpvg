//
//  SongRowView.swift
//  mpvg
//
//  List view row item for tracks in Browse or Album view with interactive rating
//  and native right-click context menu (Play Next, Add to Queue, Go to Artist, Go to Album).
//

import SwiftUI

struct SongRowView: View {
    let song: SongItem
    let isPlaying: Bool
    var viewModel: PlayerViewModel? = nil
    var onRate: ((Int) -> Void)? = nil
    var onToggleStar: (() -> Void)? = nil
    let onPlay: () -> Void
    @State private var isHovered: Bool = false
    
    private var effectiveRating: Int {
        if let current = viewModel?.currentSong, current.id == song.id {
            return current.rating
        }
        return song.rating
    }
    
    private var effectiveIsStarred: Bool {
        if let current = viewModel?.currentSong, current.id == song.id {
            return current.isStarred
        }
        return song.isStarred
    }
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Track # or Playing indicator
                ZStack {
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorTheme.terracotta)
                    } else if isHovered {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.terracotta)
                    } else {
                        Text(song.displayTrackNumber)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
                .frame(width: 24)
                
                // Title & Artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 13, weight: isPlaying ? .bold : .medium))
                        .foregroundColor(isPlaying ? ColorTheme.terracotta : ColorTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(song.displayArtist) • \(song.displayAlbum)")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Format Badge (FLAC, FLAC Hi-Res, etc.)
                Text(song.formatBadge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ColorTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorTheme.cardBorder.opacity(0.5))
                    .cornerRadius(4)
                
                // Heart & 5-Star Rating (Positioned strictly between format badge and duration)
                HStack(spacing: 4) {
                    // Heart Button (Favoritos) - always visible next to stars when starred or hovered
                    Button(action: {
                        if let onToggleStar = onToggleStar {
                            onToggleStar()
                        } else if let vm = viewModel {
                            vm.toggleStarred(for: song)
                        }
                    }) {
                        Image(systemName: effectiveIsStarred ? "heart.fill" : "heart")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(effectiveIsStarred ? ColorTheme.accent : ColorTheme.textTertiary)
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                    .help(effectiveIsStarred ? LocalizedStringKey("Remove from Favorites") : LocalizedStringKey("Add to Favorites"))
                    .opacity((effectiveIsStarred || isHovered) ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.12), value: effectiveIsStarred || isHovered)
                    
                    // 5-Star Rating
                    ZStack(alignment: .trailing) {
                        if effectiveRating > 0 || isHovered {
                            StarRatingView(
                                rating: effectiveRating,
                                size: 11,
                                spacing: 2,
                                interactive: true,
                                onRate: onRate
                            )
                            .transition(.opacity)
                        }
                    }
                    .frame(width: 75, alignment: .trailing)
                }
                .frame(width: 100, alignment: .trailing)
                
                // Duration
                Text(song.formattedDuration)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isPlaying ? ColorTheme.terracottaLight.opacity(0.3) :
                    (isHovered ? ColorTheme.cardBackground : Color.clear)
            )
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovered = hovering
            }
        }
        .pointingHandOnHover()
        .contextMenu {
            contextMenuContent
        }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            onPlay()
        } label: {
            Label("Reproducir", systemImage: "play.fill")
        }
        
        Divider()
        
        Button {
            viewModel?.playNext(song)
            viewModel?.showToast("\"\(song.title)\" añadida a continuación")
        } label: {
            Label("Añadir a continuación", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        
        Button {
            viewModel?.addToQueue(song)
            viewModel?.showToast("\"\(song.title)\" añadida al final de la cola")
        } label: {
            Label("Añadir al final de la cola", systemImage: "text.line.last.and.arrowtriangle.forward")
        }
        
        Divider()
        
        if !song.displayArtist.isEmpty && song.displayArtist != "Unknown Artist" {
            Button {
                viewModel?.navigateToArtist(for: song)
            } label: {
                Label("Ver artista", systemImage: "music.mic")
            }
        }
        
        if !song.displayAlbum.isEmpty && song.displayAlbum != "Unknown Album" {
            Button {
                viewModel?.navigateToAlbum(for: song)
            } label: {
                Label("Ver álbum", systemImage: "square.stack")
            }
        }
    }
}
