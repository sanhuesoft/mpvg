//
//  StarRatingView.swift
//  mpvg
//
//  Interactive 5-star rating view for songs and albums in Navidrome / Subsonic.
//

import SwiftUI

struct StarRatingView: View {
    let rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 12
    var spacing: CGFloat = 2
    var interactive: Bool = true
    var onRate: ((Int) -> Void)? = nil
    
    @State private var hoveredStar: Int? = nil
    
    private var displayRating: Int {
        if let hovered = hoveredStar {
            return hovered
        }
        return rating
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { star in
                let isFilled = star <= displayRating
                
                Button(action: {
                    guard interactive else { return }
                    if rating == star {
                        onRate?(0) // Toggle off to clear rating
                    } else {
                        onRate?(star)
                    }
                }) {
                    Image(systemName: isFilled ? "star.fill" : "star")
                        .font(.system(size: size, weight: isFilled ? .semibold : .regular))
                        .foregroundColor(isFilled ? ColorTheme.terracotta : ColorTheme.textTertiary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!interactive)
                .pointingHandOnHover()
                #if os(macOS)
                .onHover { isHovering in
                    guard interactive else { return }
                    if isHovering {
                        self.hoveredStar = star
                    } else if self.hoveredStar == star {
                        self.hoveredStar = nil
                    }
                }
                #endif
            }
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { isHovering in
            if !isHovering {
                self.hoveredStar = nil
            }
        }
        #endif
    }
}
