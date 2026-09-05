//
//  SidebarView.swift
//  mpvg
//
//  macOS Music-styled sidebar featuring:
//  - Translucent material background with warm ambient tint
//  - Top traffic-light spacing with sidebar collapse toggle
//  - Navigation items with refined icons and terracotta pill selection
//  - User profile badge at the bottom
//

import SwiftUI

#if os(macOS)
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#endif

struct SidebarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            #if os(macOS)
            // Top Window Spacing with Sidebar Toggle
            HStack(alignment: .center) {
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        viewModel.isSidebarVisible.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 26, height: 24)
                        .background(ColorTheme.cardBackground.opacity(0.7))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(height: 38)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            #endif
            
            // Search field shortcut in sidebar (Apple Music style)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textTertiary)
                
                TextField("Search...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textPrimary)
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ColorTheme.cardBackground.opacity(0.8))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            
            // Navigation Sections
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // DISCOVER
                    sidebarSection(title: "DISCOVER") {
                        SidebarRowItem(
                            iconName: "house.fill",
                            label: "Browse",
                            isSelected: viewModel.activeTab == .browse
                        ) {
                            viewModel.activeTab = .browse
                        }
                        
                        SidebarRowItem(
                            iconName: "clock.arrow.circlepath",
                            label: "Recently Added",
                            count: viewModel.recentAlbums.isEmpty ? nil : "\(viewModel.recentAlbums.count)",
                            isSelected: viewModel.activeTab == .recentlyAdded
                        ) {
                            viewModel.activeTab = .recentlyAdded
                        }
                        
                        SidebarRowItem(
                            iconName: "play.circle",
                            label: "Recently Played",
                            count: viewModel.recentlyPlayedAlbums.isEmpty ? nil : "\(viewModel.recentlyPlayedAlbums.count)",
                            isSelected: viewModel.activeTab == .recentlyPlayed
                        ) {
                            viewModel.activeTab = .recentlyPlayed
                        }
                        
                        SidebarRowItem(
                            iconName: "star.fill",
                            label: "Top Rated",
                            count: viewModel.topRatedAlbums.isEmpty ? nil : "\(viewModel.topRatedAlbums.count)",
                            isSelected: viewModel.activeTab == .topRated
                        ) {
                            viewModel.activeTab = .topRated
                        }
                    }
                    
                    // LIBRARY
                    sidebarSection(title: "LIBRARY") {
                        SidebarRowItem(
                            iconName: "square.stack",
                            label: "Albums",
                            count: "\(viewModel.albums.count)",
                            isSelected: viewModel.activeTab == .albums
                        ) {
                            viewModel.activeTab = .albums
                        }
                        
                        SidebarRowItem(
                            iconName: "music.mic",
                            label: "Artists",
                            count: "\(viewModel.artists.count)",
                            isSelected: viewModel.activeTab == .artists
                        ) {
                            viewModel.activeTab = .artists
                        }
                        
                        SidebarRowItem(
                            iconName: "music.note.list",
                            label: "Playlists",
                            count: viewModel.playlists.isEmpty ? nil : "\(viewModel.playlists.count)",
                            isSelected: viewModel.activeTab == .playlists
                        ) {
                            viewModel.activeTab = .playlists
                        }
                        
                        SidebarRowItem(
                            iconName: "guitars",
                            label: "Genres",
                            count: viewModel.genres.isEmpty ? nil : "\(viewModel.genres.count)",
                            isSelected: viewModel.activeTab == .genres
                        ) {
                            viewModel.activeTab = .genres
                        }
                    }
                    
                    // SYSTEM
                    sidebarSection(title: "SYSTEM") {
                        SidebarRowItem(
                            iconName: "gearshape.fill",
                            label: "Settings",
                            badge: viewModel.mpv.isExclusive ? "⚡ Hi-Res" : nil,
                            isSelected: viewModel.activeTab == .settings
                        ) {
                            viewModel.activeTab = .settings
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            
            Spacer(minLength: 0)
            
            // User profile pill at the bottom (Apple Music style)
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "B45309"), ColorTheme.terracotta],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Text("FS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Fabián Sanhueza")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text(viewModel.isConnected ? "music.ssft.cl" : "Local Library")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.textTertiary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(ColorTheme.cardBackground.opacity(0.6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 220)
        .background(sidebarBackgroundView)
    }
    
    @ViewBuilder
    private var sidebarBackgroundView: some View {
        #if os(macOS)
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            .overlay(ColorTheme.sidebarBackground.opacity(0.7))
        #else
        ColorTheme.sidebarBackground
        #endif
    }
    
    // MARK: - Section Header Helper
    private func sidebarSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ColorTheme.textTertiary)
                .tracking(0.6)
                .padding(.horizontal, 12)
                .padding(.bottom, 3)
            
            content()
        }
    }
}

// MARK: - Individual Sidebar Row
private struct SidebarRowItem: View {
    let iconName: String
    let label: String
    var count: String? = nil
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textSecondary)
                    .frame(width: 18, alignment: .center)
                
                Text(LocalizedStringKey(label))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textPrimary)
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorTheme.terracotta)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(ColorTheme.terracottaLight.opacity(0.7))
                        .cornerRadius(4)
                } else if let count = count, !count.isEmpty {
                    Text(count)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected
                          ? ColorTheme.terracottaLight.opacity(0.9)
                          : (isHovered ? ColorTheme.cardBorder.opacity(0.4) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? ColorTheme.terracotta.opacity(0.2) : Color.clear, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandOnHover()
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovered = isHovering
            }
        }
    }
}
