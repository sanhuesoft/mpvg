//
//  MainView.swift
//  mpvg
//
//  Main application container with modern Apple Music / CaskHub layout:
//  - macOS: Left floating island sidebar, elevated content canvas, and floating crystal player bar
//  - iPadOS: Split layout with floating sidebar for regular size class
//  - iOS: Native TabView + Mini Player for compact iPhone screens
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = PlayerViewModel()
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    var body: some View {
        ZStack {
            #if os(macOS)
            desktopLayout
                .frame(minWidth: 800, minHeight: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            #endif
            
            // Server Disconnected Overlay
            if viewModel.isDisconnectedOverlayVisible && viewModel.activeTab != .settings && !viewModel.showSettingsSheet {
                ConnectionOverlayView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(200)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isDisconnectedOverlayVisible)
    }
    
    // MARK: - Desktop Layout (macOS)
    #if os(macOS)
    private var desktopLayout: some View {
        HStack(spacing: 8) {
            // Left Floating Sidebar — Floating island style
            if viewModel.isSidebarVisible {
                SidebarView(viewModel: viewModel)
                    .padding([.top, .leading, .bottom], 10)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            
            // Main Content View
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HeaderBarView(viewModel: viewModel)
                    
                    Divider().background(ColorTheme.cardBorder.opacity(0.6))
                    
                    ZStack {
                        if viewModel.activeTab == .settings {
                            SettingsView(viewModel: viewModel)
                        } else if let destination = viewModel.navigationStack.last {
                            switch destination {
                            case .album(let album):
                                AlbumDetailView(album: album, viewModel: viewModel)
                                    .transition(.opacity)
                            case .artist(let artist):
                                ArtistDetailView(artist: artist, viewModel: viewModel)
                                    .transition(.opacity)
                            }
                        } else {
                            BrowseView(viewModel: viewModel)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Floating Crystal (Liquid Glass) Player Bar — ONLY over the content!
                PlayerBarView(viewModel: viewModel)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                
                // Toast Notification Overlay
                if let message = viewModel.toastMessage {
                    VStack {
                        ToastNotificationView(message: message, isError: true) {
                            withAnimation(.spring()) {
                                viewModel.hideToast()
                            }
                        }
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTheme.windowBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.windowBackground)
    }
    #endif
    
    // MARK: - Tablet Layout (iPadOS Regular)
    #if os(iOS)
    private var tabletLayout: some View {
        HStack(spacing: 8) {
            SidebarView(viewModel: viewModel)
                .padding([.top, .leading, .bottom], 10)
            
            VStack(spacing: 0) {
                HeaderBarView(viewModel: viewModel)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                
                ZStack {
                    if viewModel.activeTab == .settings {
                        SettingsView(viewModel: viewModel)
                    } else if let destination = viewModel.navigationStack.last {
                        switch destination {
                        case .album(let album):
                            AlbumDetailView(album: album, viewModel: viewModel)
                        case .artist(let artist):
                            ArtistDetailView(artist: artist, viewModel: viewModel)
                        }
                    } else {
                        BrowseView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                PlayerBarView(viewModel: viewModel)
            }
        }
        .background(ColorTheme.windowBackground)
    }
    #endif
}