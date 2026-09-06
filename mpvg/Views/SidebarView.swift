//
//  SidebarView.swift
//  mpvg
//
//  Native macOS Floating Island Sidebar:
//  - Elevated floating rounded panel with translucent blur & soft shadow
//  - Integrated traffic-light alignment & collapse toggle
//  - Sleek search input with instant clear button
//  - Circular colored icon badges matching screenshot style with app color palette
//  - Elevated selection card with subtle border & shadow
//  - Anchored user profile card at the bottom
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
            // Top Window Spacing with Traffic Light Alignment & Sidebar Toggle
            HStack(alignment: .center, spacing: 0) {
                // Reserved breathing room for native window traffic lights
                Spacer()
                    .frame(width: 70)
                
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
                        .background(ColorTheme.cardBackground.opacity(0.8))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .help("Hide Sidebar")
            }
            .frame(height: 38)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            #else
            Color.clear.frame(height: 12)
            #endif
            
            // Search field shortcut in floating sidebar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
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
            .padding(.vertical, 7)
            .background(ColorTheme.cardBackground.opacity(0.85))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
            )
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 12)
            
            // Navigation Sections with Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // DISCOVER
                    sidebarSection(title: "DISCOVER") {
                        SidebarRowItem(
                            iconName: "house.fill",
                            label: "Browse",
                            iconTint: ColorTheme.terracotta,
                            iconBgTint: ColorTheme.terracottaLight,
                            isSelected: viewModel.activeTab == .browse
                        ) {
                            viewModel.selectTab(.browse)
                        }
                        
                        SidebarRowItem(
                            iconName: "clock.arrow.circlepath",
                            label: "Recently Added",
                            count: viewModel.recentAlbums.isEmpty ? nil : "\(viewModel.recentAlbums.count)",
                            iconTint: ColorTheme.blue,
                            iconBgTint: ColorTheme.blueBg,
                            isSelected: viewModel.activeTab == .recentlyAdded
                        ) {
                            viewModel.selectTab(.recentlyAdded)
                        }
                        
                        SidebarRowItem(
                            iconName: "play.circle",
                            label: "Recently Played",
                            count: viewModel.recentlyPlayedAlbums.isEmpty ? nil : "\(viewModel.recentlyPlayedAlbums.count)",
                            iconTint: ColorTheme.sageGreen,
                            iconBgTint: ColorTheme.sageGreenBg,
                            isSelected: viewModel.activeTab == .recentlyPlayed
                        ) {
                            viewModel.selectTab(.recentlyPlayed)
                        }
                        
                        SidebarRowItem(
                            iconName: "star.fill",
                            label: "Top Rated",
                            count: viewModel.topRatedAlbums.isEmpty ? nil : "\(viewModel.topRatedAlbums.count)",
                            iconTint: ColorTheme.amber,
                            iconBgTint: ColorTheme.amberBg,
                            isSelected: viewModel.activeTab == .topRated
                        ) {
                            viewModel.selectTab(.topRated)
                        }
                    }
                    
                    // LIBRARY
                    sidebarSection(title: "LIBRARY") {
                        SidebarRowItem(
                            iconName: "square.stack",
                            label: "Albums",
                            count: "\(viewModel.albums.count)",
                            iconTint: ColorTheme.terracotta,
                            iconBgTint: ColorTheme.terracottaLight,
                            isSelected: viewModel.activeTab == .albums
                        ) {
                            viewModel.selectTab(.albums)
                        }
                        
                        SidebarRowItem(
                            iconName: "music.mic",
                            label: "Artists",
                            count: "\(viewModel.artists.count)",
                            iconTint: ColorTheme.blue,
                            iconBgTint: ColorTheme.blueBg,
                            isSelected: viewModel.activeTab == .artists
                        ) {
                            viewModel.selectTab(.artists)
                        }
                        
                        SidebarRowItem(
                            iconName: "music.note.list",
                            label: "Playlists",
                            count: viewModel.playlists.isEmpty ? nil : "\(viewModel.playlists.count)",
                            iconTint: ColorTheme.sageGreen,
                            iconBgTint: ColorTheme.sageGreenBg,
                            isSelected: viewModel.activeTab == .playlists
                        ) {
                            viewModel.selectTab(.playlists)
                        }
                        
                        SidebarRowItem(
                            iconName: "guitars",
                            label: "Genres",
                            count: viewModel.genres.isEmpty ? nil : "\(viewModel.genres.count)",
                            iconTint: ColorTheme.amber,
                            iconBgTint: ColorTheme.amberBg,
                            isSelected: viewModel.activeTab == .genres
                        ) {
                            viewModel.selectTab(.genres)
                        }
                    }
                    
                    // SYSTEM
                    sidebarSection(title: "SYSTEM") {
                        SidebarRowItem(
                            iconName: "gearshape.fill",
                            label: "Settings",
                            badge: viewModel.mpv.isExclusive ? "⚡ Hi-Res" : nil,
                            iconTint: ColorTheme.textSecondary,
                            iconBgTint: ColorTheme.cardBorder,
                            isSelected: viewModel.activeTab == .settings
                        ) {
                            viewModel.selectTab(.settings)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            
            Spacer(minLength: 0)
            
            // Anchored User Profile Card at the bottom
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "B45309"), ColorTheme.terracotta],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                    
                    Text("FS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Fabián Sanhueza")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.amber)
                            .frame(width: 5, height: 5)
                        
                        Text(viewModel.isConnected ? "music.ssft.cl" : "Local Library")
                            .font(.system(size: 9.5))
                            .foregroundColor(ColorTheme.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(ColorTheme.cardBackground.opacity(0.75))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: 232)
        .background(sidebarFloatingBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTheme.cardBorder.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var sidebarFloatingBackground: some View {
        #if os(macOS)
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            .overlay(ColorTheme.sidebarBackground.opacity(0.82))
        #else
        ColorTheme.sidebarBackground
        #endif
    }
    
    // MARK: - Section Header Helper
    private func sidebarSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(ColorTheme.textTertiary)
                .tracking(0.6)
                .padding(.horizontal, 10)
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
    var iconTint: Color = ColorTheme.terracotta
    var iconBgTint: Color = ColorTheme.terracottaLight
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                // Circular icon container matching floating sidebar style
                ZStack {
                    Circle()
                        .fill(isSelected ? iconTint : (isHovered ? iconBgTint.opacity(0.8) : iconBgTint.opacity(0.45)))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : iconTint)
                }
                
                Text(LocalizedStringKey(label))
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ColorTheme.textPrimary : ColorTheme.textSecondary)
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(ColorTheme.terracotta)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(ColorTheme.terracottaLight.opacity(0.7))
                        .cornerRadius(5)
                } else if let count = count, !count.isEmpty {
                    Text(count)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(isSelected ? ColorTheme.terracottaLight.opacity(0.5) : Color.clear)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                          ? ColorTheme.cardBackground
                          : (isHovered ? ColorTheme.cardBackground.opacity(0.55) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? ColorTheme.cardBorder : Color.clear, lineWidth: 0.8)
            )
            .shadow(color: isSelected ? Color.black.opacity(0.04) : Color.clear, radius: 3, x: 0, y: 1)
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
