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
                    .frame(width: 76)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        viewModel.isSidebarVisible.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 28, height: 26)
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
            .frame(height: 54)
            .padding(.horizontal, 14)
            #else
            Color.clear.frame(height: 12)
            #endif
            
            // Search field shortcut in floating sidebar (Desactivado a favor de Spotlight ⌘K, código conservado)
            if false {
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
            }
            
            // Navigation Sections with Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    // INICIO
                    SidebarRowItem(
                        iconName: "sparkles",
                        label: "Browse",
                        iconTint: ColorTheme.accent,
                        isSelected: viewModel.activeTab == .browse
                    ) {
                        viewModel.selectTab(.browse)
                    }
                    
                    // SMART PLAYLISTS
                    sidebarSection(title: "LISTAS INTELIGENTES") {
                        SidebarRowItem(
                            iconName: "clock.arrow.circlepath",
                            label: "Recently Added",
                            count: viewModel.recentAlbums.isEmpty ? nil : "\(viewModel.recentAlbums.count)",
                            iconTint: Color(hex: "3B82F6"),
                            isSelected: viewModel.activeTab == .recentlyAdded
                        ) {
                            viewModel.selectTab(.recentlyAdded)
                        }
                        
                        SidebarRowItem(
                            iconName: "play.circle.fill",
                            label: "Recently Played",
                            count: viewModel.recentlyPlayedAlbums.isEmpty ? nil : "\(viewModel.recentlyPlayedAlbums.count)",
                            iconTint: Color(hex: "06B6D4"),
                            isSelected: viewModel.activeTab == .recentlyPlayed
                        ) {
                            viewModel.selectTab(.recentlyPlayed)
                        }
                        
                        SidebarRowItem(
                            iconName: "star.fill",
                            label: "Top Rated",
                            count: viewModel.topRatedAlbums.isEmpty ? nil : "\(viewModel.topRatedAlbums.count)",
                            iconTint: Color(hex: "F59E0B"),
                            isSelected: viewModel.activeTab == .topRated
                        ) {
                            viewModel.selectTab(.topRated)
                        }
                        
                        SidebarRowItem(
                            iconName: "sparkles",
                            label: "No escuchadas",
                            count: viewModel.smartPlaylistSongs[.unplayed]?.isEmpty == false ? "\(viewModel.smartPlaylistSongs[.unplayed]!.count)" : nil,
                            iconTint: Color(hex: "8B5CF6"),
                            isSelected: viewModel.activeTab == .unplayed
                        ) {
                            viewModel.selectTab(.unplayed)
                        }
                        
                        SidebarRowItem(
                            iconName: "flame.fill",
                            label: "Las Más Escuchadas",
                            count: viewModel.smartPlaylistSongs[.mostPlayed]?.isEmpty == false ? "\(viewModel.smartPlaylistSongs[.mostPlayed]!.count)" : nil,
                            iconTint: Color(hex: "EF4444"),
                            isSelected: viewModel.activeTab == .mostPlayed
                        ) {
                            viewModel.selectTab(.mostPlayed)
                        }
                        
                        SidebarRowItem(
                            iconName: "star.fill",
                            label: "Favoritas",
                            count: viewModel.smartPlaylistSongs[.starred]?.isEmpty == false ? "\(viewModel.smartPlaylistSongs[.starred]!.count)" : nil,
                            iconTint: Color(hex: "EC4899"),
                            isSelected: viewModel.activeTab == .starred
                        ) {
                            viewModel.selectTab(.starred)
                        }
                        
                        SidebarRowItem(
                            iconName: "clock.badge.checkmark",
                            label: "Joyas Olvidadas",
                            count: viewModel.smartPlaylistSongs[.forgottenFavorites]?.isEmpty == false ? "\(viewModel.smartPlaylistSongs[.forgottenFavorites]!.count)" : nil,
                            iconTint: Color(hex: "F97316"),
                            isSelected: viewModel.activeTab == .forgottenFavorites
                        ) {
                            viewModel.selectTab(.forgottenFavorites)
                        }
                        
                        SidebarRowItem(
                            iconName: "shuffle",
                            label: "Mix Descubrimiento",
                            count: viewModel.smartPlaylistSongs[.discoveryMix]?.isEmpty == false ? "\(viewModel.smartPlaylistSongs[.discoveryMix]!.count)" : nil,
                            iconTint: Color(hex: "10B981"),
                            isSelected: viewModel.activeTab == .discoveryMix
                        ) {
                            viewModel.selectTab(.discoveryMix)
                        }
                    }
                    
                    // LIBRARY
                    sidebarSection(title: "BIBLIOTECA") {
                        SidebarRowItem(
                            iconName: "square.stack",
                            label: "Albums",
                            count: "\(viewModel.albums.count)",
                            iconTint: ColorTheme.accent,
                            isSelected: viewModel.activeTab == .albums
                        ) {
                            viewModel.selectTab(.albums)
                        }
                        
                        SidebarRowItem(
                            iconName: "music.mic",
                            label: "Artists",
                            count: "\(viewModel.artists.count)",
                            iconTint: Color(hex: "2A90CB"),
                            isSelected: viewModel.activeTab == .artists
                        ) {
                            viewModel.selectTab(.artists)
                        }
                        
                        SidebarRowItem(
                            iconName: "music.note.list",
                            label: "Playlists",
                            count: viewModel.playlists.isEmpty ? nil : "\(viewModel.playlists.count)",
                            iconTint: Color(hex: "3EB174"),
                            isSelected: viewModel.activeTab == .playlists
                        ) {
                            viewModel.selectTab(.playlists)
                        }
                        
                        SidebarRowItem(
                            iconName: "guitars",
                            label: "Genres",
                            count: viewModel.genres.isEmpty ? nil : "\(viewModel.genres.count)",
                            iconTint: Color(hex: "D79719"),
                            isSelected: viewModel.activeTab == .genres
                        ) {
                            viewModel.selectTab(.genres)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            
            Spacer(minLength: 0)
            
            // Native Bottom Status Bar (matching HIG)
            VStack(spacing: 0) {
                Divider()
                    .background(ColorTheme.cardBorder.opacity(0.6))
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.amber)
                        .frame(width: 7, height: 7)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(serverDisplayText)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(ColorTheme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Text(viewModel.isConnected ? LocalizedStringKey("Connected") : LocalizedStringKey("Disconnected"))
                            .font(.system(size: 9.5))
                            .foregroundColor(ColorTheme.textTertiary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    SidebarSettingsButton(
                        isSelected: viewModel.activeTab == .settings,
                        action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                viewModel.selectTab(.settings)
                            }
                        }
                    )
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
            }
        }
        .frame(width: 240)
        .frame(maxHeight: .infinity)
        #if os(macOS)
        .background(sidebarNativeBackground.ignoresSafeArea(.all, edges: .top))
        #else
        .background(sidebarNativeBackground)
        #endif
    }
    
    private var serverDisplayText: String {
        if let host = URL(string: viewModel.serverConfig.urlString)?.host, !host.isEmpty {
            return host
        }
        return viewModel.isConnected ? "music.ssft.cl" : "Local Library"
    }
    
    @ViewBuilder
    private var sidebarNativeBackground: some View {
        #if os(macOS)
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            .overlay(ColorTheme.sidebarBackground.opacity(0.5))
        #else
        ColorTheme.sidebarBackground
        #endif
    }
    
    // MARK: - Section Header Helper
    private func sidebarSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(ColorTheme.textTertiary)
                .tracking(0.6)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 3)
            
            content()
        }
    }
}

// MARK: - Individual Sidebar Row (Native macOS Style with App Theme Colors)
private struct SidebarRowItem: View {
    let iconName: String
    let label: String
    var count: String? = nil
    var badge: String? = nil
    var iconTint: Color = ColorTheme.accent
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // SF Symbol icon with theme tint
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : iconTint)
                    .frame(width: 20, alignment: .center)
                
                Text(LocalizedStringKey(label))
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : ColorTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isSelected ? .white : ColorTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : ColorTheme.accentLight.opacity(0.8))
                        .cornerRadius(4)
                } else if let count = count, !count.isEmpty {
                    Text(count)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? Color.white.opacity(0.9) : ColorTheme.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected
                          ? ColorTheme.accent
                          : (isHovered ? ColorTheme.cardBackground.opacity(0.65) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandOnHover()
        .onHover { hovering in
            self.isHovered = hovering
        }
    }
}

// MARK: - Sidebar Settings Button
private struct SidebarSettingsButton: View {
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "gearshape.fill" : "gearshape")
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? ColorTheme.accent : (isHovered ? ColorTheme.textPrimary : ColorTheme.textSecondary))
                .frame(width: 24, height: 24)
                .background(isHovered ? ColorTheme.cardBackground.opacity(0.7) : Color.clear)
                .cornerRadius(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(",", modifiers: .command)
        .pointingHandOnHover()
        .onHover { hovering in
            isHovered = hovering
        }
        .help(LocalizedStringKey("Settings (⌘,)"))
    }
}

