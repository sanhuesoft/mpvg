//
//  SongRowView.swift
//  mpvg
//
//  List view row item for tracks in Browse or Album view with interactive rating.
//

import SwiftUI

struct SongRowView: View {
    let song: SongItem
    let isPlaying: Bool
    var onRate: ((Int) -> Void)? = nil
    let onPlay: () -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
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
            
            // 5-Star Rating (Visible if rated or hovered)
            if song.rating > 0 || isHovered {
                StarRatingView(
                    rating: song.rating,
                    size: 10,
                    spacing: 2,
                    interactive: true,
                    onRate: onRate
                )
                .transition(.opacity)
            }
            
            // Format Badge
            Text(song.formatBadge)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ColorTheme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ColorTheme.cardBorder.opacity(0.5))
                .cornerRadius(4)
            
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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovered = hovering
            }
        }
        .onTapGesture {
            onPlay()
        }
    }
}
