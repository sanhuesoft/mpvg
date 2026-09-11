//
//  HeaderBarView.swift
//  mpvg
//
//  CaskHub-styled top navigation header with title, item count,
//  grid/list switcher, and search input with ⌘F shortcut badge.
//

import SwiftUI

struct HeaderBarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            #if os(macOS)
            if !viewModel.isSidebarVisible {
                Spacer()
                    .frame(width: 52)
                
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        viewModel.isSidebarVisible = true
                    }
                }) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 28, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(ColorTheme.inputBackground.opacity(0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .transition(.scale.combined(with: .opacity))
            }
            #endif
            
            // Back Button when navigated into a detail view
            if !viewModel.navigationStack.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.navigateBack()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Back")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(ColorTheme.terracotta)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ColorTheme.terracottaLight.opacity(0.6))
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Title when navigated into a detail view (directly next to back button)
            if let dest = viewModel.navigationStack.last {
                Text(destinationTitle(dest))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(LocalizedStringKey(viewModel.activeTab.rawValue))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text(itemCountLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Sync Library Button
            Button(action: {
                Task {
                    await viewModel.syncLibrary()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(viewModel.isSyncingLibrary ? 360 : 0))
                        .animation(viewModel.isSyncingLibrary ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: viewModel.isSyncingLibrary)
                    #if os(macOS)
                    Text("Sync")
                        .font(.system(size: 12, weight: .medium))
                    #endif
                }
                .foregroundColor(viewModel.isSyncingLibrary ? ColorTheme.terracotta : ColorTheme.textSecondary)
                .frame(height: 26)
                .padding(.horizontal, 9)
                .background(ColorTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTheme.inputBorder, lineWidth: 1)
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
            .disabled(viewModel.isSyncingLibrary)
            .help("Sync Library with Server")
            
            // Grid / List Toggle (only at root tab view)
            if viewModel.navigationStack.isEmpty {
                HStack(spacing: 2) {
                    Button(action: { viewModel.viewMode = .grid }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(viewModel.viewMode == .grid ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                            .frame(width: 28, height: 26)
                            .background(viewModel.viewMode == .grid ? ColorTheme.cardBackground : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                    
                    Button(action: { viewModel.viewMode = .list }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(viewModel.viewMode == .list ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                            .frame(width: 28, height: 26)
                            .background(viewModel.viewMode == .list ? ColorTheme.cardBackground : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ColorTheme.inputBackground.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            #if os(macOS)
            // Spotlight ⌘K Quick Button
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    viewModel.toggleSpotlight()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Text("Buscar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Text("⌘K")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(ColorTheme.cardBorder.opacity(0.6))
                        .cornerRadius(4)
                }
                .frame(height: 26)
                .padding(.horizontal, 9)
                .background(ColorTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTheme.inputBorder, lineWidth: 1)
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
            .help("Buscador Spotlight (⌘K)")
            #endif

            // Search Bar Pill (Desactivado a favor del buscador Spotlight ⌘K, código conservado)
            if false {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    TextField("Search albums, tracks...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textPrimary)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            #if os(iOS)
                            hideKeyboard()
                            #endif
                        }
                        .frame(minWidth: 90, idealWidth: 150, maxWidth: 200)
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: { viewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // ⌘F Badge
                        HStack(spacing: 1) {
                            Text("⌘F")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(ColorTheme.cardBorder.opacity(0.6))
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(ColorTheme.inputBackground.opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isSearchFocused ? ColorTheme.terracotta.opacity(0.7) : ColorTheme.inputBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearchFocused = true
                }
                
                // Invisible button to bind ⌘F directly to search field focus
                Button(action: {
                    isSearchFocused = true
                }) {
                    EmptyView()
                }
                .keyboardShortcut("f", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(ColorTheme.windowBackground)
        .onChange(of: viewModel.focusSearchTrigger) { _ in
            isSearchFocused = true
        }
        #if os(macOS)
        .onExitCommand {
            isSearchFocused = false
        }
        #endif
    }
    
    private var itemCountLabel: LocalizedStringKey {
        switch viewModel.activeTab {
        case .artists:
            return viewModel.artists.isEmpty ? "" : "\(viewModel.artists.count) artists"
        case .playlists:
            return viewModel.playlists.isEmpty ? "" : "\(viewModel.playlists.count) playlists"
        case .genres:
            return viewModel.genres.isEmpty ? "" : "\(viewModel.genres.count) genres"
        case .recentlyAdded:
            return viewModel.recentAlbums.isEmpty ? "" : "\(viewModel.recentAlbums.count) albums"
        case .recentlyPlayed:
            return viewModel.recentlyPlayedAlbums.isEmpty ? "" : "\(viewModel.recentlyPlayedAlbums.count) albums"
        case .topRated:
            return viewModel.topRatedAlbums.isEmpty ? "" : "\(viewModel.topRatedAlbums.count) albums"
        case .albums:
            return viewModel.albums.isEmpty ? "" : "\(viewModel.albums.count) albums"
        case .unplayed, .forgottenFavorites, .mostPlayed, .starred, .discoveryMix:
            if let type = viewModel.activeTab.asSmartPlaylistType,
               let count = viewModel.smartPlaylistSongs[type]?.count, count > 0 {
                return "\(count) tracks"
            }
            return ""
        case .browse, .settings:
            return ""
        }
    }
    
    private func destinationTitle(_ dest: NavigationDestination) -> String {
        switch dest {
        case .album(let album):
            return album.displayTitle
        case .artist(let artist):
            return artist.name
        case .smartPlaylist(let type):
            return type.title
        }
    }
}
