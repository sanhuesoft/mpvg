//
//  SidebarView.swift
//  mpvg
//
//  CaskHub-inspired sidebar with warm latte background, category groupings,
//  count badges, and terracotta pill selection states.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Traffic Light Area & Window Controls
            HStack {
                Spacer()
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13))
                    .foregroundColor(ColorTheme.textTertiary)
            }
            .frame(height: 28)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            // App Branding Header
            HStack(spacing: 10) {
                // App Logo Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [ColorTheme.terracotta, ColorTheme.terracottaHover],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("NaviHub")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Sidebar Navigation Sections
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // DISCOVER
                    sidebarSection(title: "DISCOVER") {
                        sidebarRow(tab: .browse, label: "Browse", count: nil)
                        sidebarRow(tab: .featured, label: "Featured", count: nil)
                        sidebarRow(tab: .topCharts, label: "Top Charts", count: nil)
                        sidebarRow(tab: .recentlyAdded, label: "Recently Added", count: nil)
                    }
                    
                    // LIBRARY
                    sidebarSection(title: "LIBRARY") {
                        sidebarRow(tab: .albums, label: "Albums", count: "\(viewModel.albums.count)")
                        sidebarRow(tab: .artists, label: "Artists", count: "342")
                        sidebarRow(tab: .playlists, label: "Playlists", count: "12")
                        sidebarRow(tab: .genres, label: "Genres", count: "24")
                    }
                    
                    // AUDIO & SYSTEM
                    sidebarSection(title: "AUDIO & SETUP") {
                        sidebarRow(tab: .settings, label: "Settings", count: viewModel.mpv.isExclusive ? "⚡" : nil)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: 220)
        .background(ColorTheme.sidebarBackground)
    }
    
    // MARK: - Section Helper
    private func sidebarSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ColorTheme.textTertiary)
                .tracking(1.0)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            
            content()
        }
    }
    
    // MARK: - Row Helper
    private func sidebarRow(tab: SidebarTab, label: String, count: String?) -> some View {
        let isSelected = viewModel.activeTab == tab
        
        return Button(action: {
            viewModel.activeTab = tab
        }) {
            HStack(spacing: 8) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18, alignment: .center)
                
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                Spacer()
                
                if let count = count, !count.isEmpty {
                    Text(count)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            isSelected ? Color.white.opacity(0.4) : Color.clear
                        )
                        .cornerRadius(4)
                }
            }
            .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected ? ColorTheme.selectedPill : Color.clear
            )
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
