//
//  MainView.swift
//  mpvg
//
//  Main application container with CaskHub layout:
//  Sidebar, Top Header, Responsive Content Grid, and Bottom Player/Status bar.
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = PlayerViewModel()
    
    var body: some View {
        HStack(spacing: 0) {
            // CaskHub Left Sidebar
            SidebarView(viewModel: viewModel)
            
            // Vertical Divider
            Rectangle()
                .fill(ColorTheme.cardBorder)
                .frame(width: 1)
            
            // Main Content Area
            VStack(spacing: 0) {
                // Top Header Bar
                HeaderBarView(viewModel: viewModel)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                // Content Views
                ZStack {
                    if viewModel.activeTab == .settings {
                        SettingsView(viewModel: viewModel)
                    } else {
                        BrowseView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Player & Status Bar
                PlayerBarView(viewModel: viewModel)
            }
        }
        .background(ColorTheme.windowBackground)
        .frame(minWidth: 980, minHeight: 640)
        .sheet(item: $viewModel.selectedAlbumForDetail) { album in
            AlbumDetailSheet(album: album, viewModel: viewModel)
        }
        .task {
            viewModel.mpv.start()
        }
        .onDisappear {
            viewModel.mpv.stop()
        }
    }
}