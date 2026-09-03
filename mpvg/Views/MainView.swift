//
//  MainView.swift
//  mpvg
//
//  Main application container with modern Apple Music / CaskHub layout:
//  - macOS: Left integrated sidebar, elevated rounded content canvas, and floating crystal player bar
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
    #if os(macOS)
    private var desktopLayout: some View {
        HStack(spacing: 0) {
            // Left Sidebar — Unobstructed, full vertical height
            if viewModel.isSidebarVisible {
                SidebarView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            
            // Main Content Island Card containing the Floating Player Bar inside
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HeaderBarView(viewModel: viewModel)
                    
                    Divider().background(ColorTheme.cardBorder.opacity(0.6))
                    
                    ZStack {
                        if viewModel.activeTab == .settings {
                            SettingsView(viewModel: viewModel)
                        } else {
                            BrowseView(viewModel: viewModel)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Floating Crystal (Liquid Glass) Player Bar — ONLY over the content!
                PlayerBarView(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .background(ColorTheme.cardBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ColorTheme.cardBorder, lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
            .padding(.trailing, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .padding(.leading, viewModel.isSidebarVisible ? 10 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.windowBackground)
        .sheet(item: $viewModel.selectedAlbumForDetail) { album in
            AlbumDetailSheet(album: album, viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedArtistForDetail) { artist in
            ArtistDetailSheet(artist: artist, viewModel: viewModel)
        }
    }
    #endif
    
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
        .sheet(item: $viewModel.selectedArtistForDetail) { artist in
            ArtistDetailSheet(artist: artist, viewModel: viewModel)
        }
    }
    #endif
}