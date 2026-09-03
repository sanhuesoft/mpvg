//
//  ArtistCardView.swift
//  mpvg
//
//  Artist item with circular portrait avatar as hero element
//  and a clean name and album count strip below.
//

import SwiftUI

struct ArtistCardView: View {
    let artist: ArtistItem
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Circular Artist Portrait (Hero Element)
            ZStack {
                avatarView
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(ColorTheme.cardBorder, lineWidth: 1.5)
                    )
                
                if isHovered {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 110, height: 110)
                    
                    Image(systemName: "music.mic")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 6)
            
            // Info Strip Below Portrait
            VStack(spacing: 3) {
                Text(artist.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                
                if let count = artist.albumCount, count > 0 {
                    Text("\(count) \(count == 1 ? "album" : "albums")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                } else {
                    Text("Artist")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
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
            // Filter search by artist name
            viewModel.searchQuery = artist.name
        }
    }
    
    @ViewBuilder
    private var avatarView: some View {
        let avatarURL = artist.artistImageUrl.flatMap { URL(string: $0) }
        CachedAsyncImage(url: avatarURL) {
            placeholderAvatar
        }
        .aspectRatio(contentMode: .fill)
    }
    
    private var placeholderAvatar: some View {
        ZStack {
            LinearGradient(
                colors: [ColorTheme.terracottaLight, ColorTheme.cardBorder],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 36))
                .foregroundColor(ColorTheme.terracotta)
        }
    }
}
