//
//  MainView.swift
//  mpvg
//
//  Main application container with adaptive layout:
//  - macOS: Desktop CaskHub layout with Sidebar, Header, and Bottom Player
//  - iPadOS: Split layout for regular size class
//  - iOS: Native TabView + Mini Player for compact iPhone screens
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = PlayerViewModel()
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    var body: some View {
        #if os(macOS)
        desktopLayout
            .frame(minWidth: 980, minHeight: 640)
            .task {
                viewModel.mpv.start()
            }
            .onDisappear {
                viewModel.mpv.stop()
            }
        #else
        Group {
            if horizontalSizeClass == .compact {
                IOSMainView(viewModel: viewModel)
            } else {
                tabletLayout
            }
        }
        .task {
            viewModel.mpv.start()
        }
        .onDisappear {
            viewModel.mpv.stop()
        }
        #endif
    }
    
    // MARK: - Desktop Layout (macOS)
    private var desktopLayout: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
            
            Rectangle()
                .fill(ColorTheme.cardBorder)
                .frame(width: 1)
            
            VStack(spacing: 0) {
                HeaderBarView(viewModel: viewModel)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                ZStack {
                    if viewModel.activeTab == .settings {
                        SettingsView(viewModel: viewModel)
                    } else {
                        BrowseView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                PlayerBarView(viewModel: viewModel)
            }
        }
        .background(ColorTheme.windowBackground)
        .sheet(item: $viewModel.selectedAlbumForDetail) { album in
            AlbumDetailSheet(album: album, viewModel: viewModel)
        }
    }
    
    // MARK: - Tablet Layout (iPadOS Regular)
    #if os(iOS)
    private var tabletLayout: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
            
            Rectangle()
                .fill(ColorTheme.cardBorder)
                .frame(width: 1)
            
            VStack(spacing: 0) {
                HeaderBarView(viewModel: viewModel)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                ZStack {
                    if viewModel.activeTab == .settings {
                        SettingsView(viewModel: viewModel)
                    } else {
                        BrowseView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                PlayerBarView(viewModel: viewModel)
            }
        }
        .background(ColorTheme.windowBackground)
        .sheet(item: $viewModel.selectedAlbumForDetail) { album in
            AlbumDetailSheet(album: album, viewModel: viewModel)
        }
    }
    #endif
}