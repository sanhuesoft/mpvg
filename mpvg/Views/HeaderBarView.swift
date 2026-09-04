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
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        viewModel.isSidebarVisible = true
                    }
                }) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 28, height: 26)
                        .background(ColorTheme.inputBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ColorTheme.inputBorder, lineWidth: 1)
                        )
                        .cornerRadius(8)
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
            
            // Title & Count / Breadcrumbs
            if let dest = viewModel.navigationStack.last {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(LocalizedStringKey(viewModel.activeTab.rawValue))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Text("›")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Text(destinationTitle(dest))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .lineLimit(1)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(LocalizedStringKey(viewModel.activeTab.rawValue))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text(itemCountLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
            
            Spacer()
            
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
                .background(ColorTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTheme.inputBorder, lineWidth: 1)
                )
                .cornerRadius(8)
            }
            
            // Search Bar Pill
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
                    .frame(width: 180)
                
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
            .background(ColorTheme.inputBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isSearchFocused ? ColorTheme.terracotta.opacity(0.6) : ColorTheme.inputBorder, lineWidth: 1)
            )
            .cornerRadius(9)
            .keyboardShortcut("f", modifiers: .command)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
    
    private var itemCountLabel: LocalizedStringKey {
        switch viewModel.activeTab {
        case .artists:
            return "\(viewModel.artists.count) artists"
        default:
            return "\(viewModel.albums.count) albums"
        }
    }
    
    private func destinationTitle(_ dest: NavigationDestination) -> String {
        switch dest {
        case .album(let album):
            return album.displayTitle
        case .artist(let artist):
            return artist.name
        }
    }
}
