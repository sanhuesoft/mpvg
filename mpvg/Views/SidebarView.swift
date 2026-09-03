//
//  SidebarView.swift
//  mpvg
//
//  CaskHub-styled native sidebar with translucent warm latte background,
//  category groupings, right-aligned count metrics, and terracotta pill selection states.
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
            // Window Header: Traffic Lights spacing & Sidebar collapse icon
            HStack(alignment: .center) {
                Spacer()
                
                // Sidebar Collapse / Toggle Icon Button (CaskHub Style)
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        viewModel.isSidebarVisible.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 26, height: 22)
                        .background(ColorTheme.cardBackground.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ColorTheme.cardBorder, lineWidth: 1)
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // App Branding (CaskHub Keg / Vinyl Record Branding)
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "A35133"), ColorTheme.terracotta],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1.5)
                    
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("CaskHub")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(ColorTheme.textPrimary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
            
            // Navigation Sections
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // DISCOVER
                    sidebarSection(title: "DISCOVER") {
                        SidebarRowItem(tab: .browse, label: "Browse", count: nil, isSelected: viewModel.activeTab == .browse) {
                            viewModel.activeTab = .browse
                        }
                        SidebarRowItem(tab: .featured, label: "Featured", count: nil, isSelected: viewModel.activeTab == .featured) {
                            viewModel.activeTab = .featured
                        }
                        SidebarRowItem(tab: .recentlyAdded, label: "Recently Added", count: nil, isSelected: viewModel.activeTab == .recentlyAdded) {
                            viewModel.activeTab = .recentlyAdded
                        }
                    }
                    
                    // LIBRARY
                    sidebarSection(title: "LIBRARY") {
                        SidebarRowItem(tab: .albums, label: "Albums", count: "\(viewModel.albums.count)", isSelected: viewModel.activeTab == .albums) {
                            viewModel.activeTab = .albums
                        }
                        SidebarRowItem(tab: .artists, label: "Artists", count: "\(viewModel.artists.count)", isSelected: viewModel.activeTab == .artists) {
                            viewModel.activeTab = .artists
                        }
                        SidebarRowItem(tab: .playlists, label: "Playlists", count: "12", isSelected: viewModel.activeTab == .playlists) {
                            viewModel.activeTab = .playlists
                        }
                        SidebarRowItem(tab: .genres, label: "Genres", count: "24", isSelected: viewModel.activeTab == .genres) {
                            viewModel.activeTab = .genres
                        }
                    }
                    
                    // SYSTEM & SETUP
                    sidebarSection(title: "SETTINGS & ENGINE") {
                        SidebarRowItem(tab: .settings, label: "Settings", count: viewModel.mpv.isExclusive ? "⚡" : nil, isSelected: viewModel.activeTab == .settings) {
                            viewModel.activeTab = .settings
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: 240)
        .background(sidebarBackgroundView)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ColorTheme.cardBorder, lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 3)
        .padding(.leading, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private var sidebarBackgroundView: some View {
        #if os(macOS)
        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
            .overlay(ColorTheme.sidebarBackground.opacity(0.85))
        #else
        ColorTheme.sidebarBackground
        #endif
    }
    
    // MARK: - Section Header Helper
    private func sidebarSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ColorTheme.textTertiary)
                .tracking(0.8)
                .padding(.horizontal, 10)
                .padding(.bottom, 2)
            
            content()
        }
    }
}

// MARK: - Individual Sidebar Row with Hover and Selection
private struct SidebarRowItem: View {
    let tab: SidebarTab
    let label: String
    let count: String?
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textSecondary)
                    .frame(width: 18, alignment: .center)
                
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textPrimary)
                
                Spacer()
                
                if let count = count, !count.isEmpty {
                    Text(count)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? ColorTheme.terracottaLight.opacity(0.85) : (isHovered ? ColorTheme.cardBorder.opacity(0.4) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? ColorTheme.terracotta.opacity(0.2) : Color.clear, lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
