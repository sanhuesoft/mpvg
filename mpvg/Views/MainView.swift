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
    @ObservedObject private var viewModel = PlayerViewModel.shared
    @AppStorage("appAccentColor") private var appAccentColor: String = "terracotta"
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    var body: some View {
        ZStack {
            #if os(macOS)
            desktopLayout
                .frame(minWidth: 960, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
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
            
            #if os(macOS)
            // Spotlight Search Overlay (⌘K) - Preloaded in hierarchy for instantaneous, fluid animation
            SpotlightSearchView(viewModel: viewModel)
                .opacity(viewModel.isSpotlightPresented ? 1 : 0)
                .scaleEffect(viewModel.isSpotlightPresented ? 1.0 : 0.98)
                .allowsHitTesting(viewModel.isSpotlightPresented)
                .animation(.spring(response: 0.26, dampingFraction: 0.84), value: viewModel.isSpotlightPresented)
                .zIndex(300)
            #endif
        }
        .environment(\.primaryAccentName, appAccentColor)
        .tint(ColorTheme.accent)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.isDisconnectedOverlayVisible)
        #if os(macOS)
        .background(
            Group {
                Button(action: {
                    viewModel.toggleSpotlight()
                }) {
                    EmptyView()
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.selectTab(.settings)
                    }
                }) {
                    EmptyView()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectTab(.settings)
            }
        }
        #endif
    }
    
    // MARK: - Desktop Layout (macOS)
    #if os(macOS)
    private var desktopLayout: some View {
        HStack(spacing: 0) {
            // Left Native Sidebar (Full-Height & Window-Integrated)
            if viewModel.isSidebarVisible {
                SidebarView(viewModel: viewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
                
                Divider()
                    .background(ColorTheme.cardBorder.opacity(0.6))
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
                            case .smartPlaylist(let type):
                                SmartPlaylistDetailView(type: type, viewModel: viewModel)
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
        .ignoresSafeArea(.all, edges: .top)
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
                        case .smartPlaylist(let type):
                            SmartPlaylistDetailView(type: type, viewModel: viewModel)
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