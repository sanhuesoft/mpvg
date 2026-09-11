//
//  SpotlightSearchView.swift
//  mpvg
//
//  Spotlight-style floating music search modal invoked via CMD + K (⌘K) on macOS.
//  Includes filter badges (Artistas, Álbumes, Canciones) right below the search input.
//  Supports keyboard navigation (↑ / ↓ arrows to select, Return to open/play).
//

import SwiftUI
#if os(macOS)
import AppKit

enum SpotlightResultItem: Identifiable, Equatable {
    case artist(ArtistItem)
    case album(AlbumItem)
    case song(SongItem)
    
    var id: String {
        switch self {
        case .artist(let a): return "artist-\(a.id)"
        case .album(let a): return "album-\(a.id)"
        case .song(let s): return "song-\(s.id)"
        }
    }
}

struct SpotlightSearchView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hoveredItemId: String? = nil
    @State private var selectedItemId: String? = nil
    @State private var keyMonitor: Any? = nil
    
    // Flattened ordered list of all visible results
    private var flattenedResults: [SpotlightResultItem] {
        var items: [SpotlightResultItem] = []
        if shouldShowArtists {
            items.append(contentsOf: viewModel.spotlightArtists.map { .artist($0) })
        }
        if shouldShowAlbums {
            items.append(contentsOf: viewModel.spotlightAlbums.map { .album($0) })
        }
        if shouldShowSongs {
            items.append(contentsOf: viewModel.spotlightSongs.map { .song($0) })
        }
        return items
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent backdrop blur that dismisses when clicked
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.closeSpotlight()
                }
            
            // Floating Spotlight Palette Window
            VStack(spacing: 0) {
                // Top Search Bar Section
                searchHeaderView
                
                Divider()
                    .background(ColorTheme.cardBorder.opacity(0.7))
                
                // Category Filter Badges
                badgesBarView
                
                Divider()
                    .background(ColorTheme.cardBorder.opacity(0.4))
                
                // Results List / Empty State / Loading State
                contentAreaView
                
                Divider()
                    .background(ColorTheme.cardBorder.opacity(0.7))
                
                // Footer Shortcut Hints
                footerBarView
            }
            .frame(width: 620)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ColorTheme.cardBackground.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ColorTheme.cardBorderHover.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 32, x: 0, y: 16)
            .padding(.top, 70)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: viewModel.isSpotlightPresented) { _, isPresented in
            if isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    isSearchFieldFocused = true
                }
                selectedItemId = flattenedResults.first?.id
                setupKeyMonitor()
            } else {
                isSearchFieldFocused = false
                selectedItemId = nil
                removeKeyMonitor()
            }
        }
        .onChange(of: flattenedResults) { _, newResults in
            if let current = selectedItemId, newResults.contains(where: { $0.id == current }) {
                // Keep current selection if still valid
            } else {
                selectedItemId = newResults.first?.id
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .onExitCommand {
            if viewModel.isSpotlightPresented {
                viewModel.closeSpotlight()
            }
        }
    }
    
    // MARK: - Search Header
    private var searchHeaderView: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(viewModel.spotlightQuery.isEmpty ? ColorTheme.textTertiary : ColorTheme.terracotta)
            
            TextField("Buscar artistas, álbumes, canciones...", text: $viewModel.spotlightQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(ColorTheme.textPrimary)
                .focused($isSearchFieldFocused)
            
            if viewModel.isSpotlightLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }
            
            if !viewModel.spotlightQuery.isEmpty {
                Button(action: {
                    viewModel.spotlightQuery = ""
                    viewModel.performSpotlightSearch(query: "")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
            }
            
            // ESC Badge
            Text("ESC")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(ColorTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(ColorTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
                )
                .cornerRadius(5)
                .onTapGesture {
                    viewModel.closeSpotlight()
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
    
    // MARK: - Category Filter Badges
    private var badgesBarView: some View {
        HStack(spacing: 8) {
            ForEach(SpotlightScope.allCases) { scope in
                let isSelected = viewModel.spotlightScope == scope
                let count = resultCount(for: scope)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        if isSelected {
                            // If clicked again, deselect to search across all options
                            viewModel.spotlightScope = nil
                        } else {
                            viewModel.spotlightScope = scope
                        }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: scope.iconName)
                            .font(.system(size: 11, weight: .semibold))
                        
                        Text(scope.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        
                        if let c = count, c > 0 {
                            Text("\(c)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(isSelected ? Color.white.opacity(0.25) : ColorTheme.cardBorder.opacity(0.7))
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(isSelected ? .white : ColorTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? ColorTheme.terracotta : ColorTheme.inputBackground.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? ColorTheme.terracotta : ColorTheme.cardBorder.opacity(0.7), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
            }
            
            Spacer()
            
            // Clear filter indicator if active
            if viewModel.spotlightScope != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.spotlightScope = nil
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 11))
                        Text("Ver todo")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(ColorTheme.terracotta)
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ColorTheme.sidebarBackground.opacity(0.45))
    }
    
    // MARK: - Content Area
    @ViewBuilder
    private var contentAreaView: some View {
        let trimmed = viewModel.spotlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            emptyQueryView
        } else if hasNoResults {
            noResultsView(query: trimmed)
        } else {
            resultsScrollView
        }
    }
    
    private var emptyQueryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(ColorTheme.textTertiary.opacity(0.7))
            
            Text("Busca artistas, álbumes y canciones")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text("Escribe un término o selecciona un badge para filtrar la búsqueda.")
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 28)
    }
    
    private func noResultsView(query: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 34))
                .foregroundColor(ColorTheme.textTertiary)
            
            Text("Sin resultados para \"\(query)\"")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
            
            if let scope = viewModel.spotlightScope {
                Text("No se encontraron resultados en \(scope.rawValue). Prueba quitando el filtro para buscar en todas las categorías.")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Verifica la ortografía o intenta buscar con otro término.")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
            }
        }
        .padding(.vertical, 28)
    }
    
    // MARK: - Results List
    private var resultsScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    // Section: Artistas
                    if shouldShowArtists && !viewModel.spotlightArtists.isEmpty {
                        sectionContainer(title: "ARTISTAS", count: viewModel.spotlightArtists.count) {
                            ForEach(viewModel.spotlightArtists) { artist in
                                let id = "artist-\(artist.id)"
                                artistRow(artist, isSelected: selectedItemId == id)
                                    .id(id)
                            }
                        }
                    }
                    
                    // Section: Álbumes
                    if shouldShowAlbums && !viewModel.spotlightAlbums.isEmpty {
                        sectionContainer(title: "ÁLBUMES", count: viewModel.spotlightAlbums.count) {
                            ForEach(viewModel.spotlightAlbums) { album in
                                let id = "album-\(album.id)"
                                albumRow(album, isSelected: selectedItemId == id)
                                    .id(id)
                            }
                        }
                    }
                    
                    // Section: Canciones
                    if shouldShowSongs && !viewModel.spotlightSongs.isEmpty {
                        sectionContainer(title: "CANCIONES", count: viewModel.spotlightSongs.count) {
                            ForEach(viewModel.spotlightSongs) { song in
                                let id = "song-\(song.id)"
                                songRow(song, isSelected: selectedItemId == id)
                                    .id(id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 340)
            .onChange(of: selectedItemId) { _, newId in
                if let id = newId {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        scrollProxy.scrollTo(id, anchor: nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Section Container
    private func sectionContainer<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                
                Text("•  \(count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary.opacity(0.8))
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            
            VStack(spacing: 2) {
                content()
            }
        }
    }
    
    // MARK: - Artist Row
    private func artistRow(_ artist: ArtistItem, isSelected: Bool) -> some View {
        let isHovered = hoveredItemId == "artist-\(artist.id)"
        let isActive = isSelected || isHovered
        
        return Button(action: {
            viewModel.navigateToArtist(artist)
            viewModel.closeSpotlight()
        }) {
            HStack(spacing: 12) {
                // Circular Avatar
                let avatarURL = viewModel.artistAvatarURL(for: artist)
                CachedAsyncImage(url: avatarURL) {
                    Circle()
                        .fill(ColorTheme.cardBorder.opacity(0.5))
                        .overlay(
                            Image(systemName: "music.mic")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textSecondary)
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? ColorTheme.terracotta.opacity(0.7) : ColorTheme.cardBorder, lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist.name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textPrimary)
                        .lineLimit(1)
                    
                    if let count = artist.albumCount, count > 0 {
                        Text("\(count) \(count == 1 ? "álbum" : "álbumes")")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textTertiary)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? ColorTheme.terracottaLight.opacity(0.8) : (isHovered ? ColorTheme.inputBackground : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? ColorTheme.terracotta.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointingHandOnHover()
        .onHover { hovering in
            if hovering {
                selectedItemId = "artist-\(artist.id)"
                hoveredItemId = "artist-\(artist.id)"
            } else if hoveredItemId == "artist-\(artist.id)" {
                hoveredItemId = nil
            }
        }
    }
    
    // MARK: - Album Row
    private func albumRow(_ album: AlbumItem, isSelected: Bool) -> some View {
        let isHovered = hoveredItemId == "album-\(album.id)"
        let isActive = isSelected || isHovered
        let artURL: URL? = {
            if let coverId = album.coverArt, let url = viewModel.coverArtURL(for: coverId) {
                return url
            } else if let cover = album.coverArt, cover.hasPrefix("http"), let url = URL(string: cover) {
                return url
            }
            return nil
        }()
        
        return Button(action: {
            viewModel.navigateToAlbum(album)
            viewModel.closeSpotlight()
        }) {
            HStack(spacing: 12) {
                // Square Cover Art
                CachedAsyncImage(url: artURL) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ColorTheme.cardBorder.opacity(0.5))
                        .overlay(
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 14))
                                .foregroundColor(ColorTheme.textSecondary)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? ColorTheme.terracotta.opacity(0.7) : ColorTheme.cardBorder, lineWidth: 0.8)
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.displayTitle)
                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(album.displayArtist)
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textSecondary)
                            .lineLimit(1)
                        
                        if let year = album.year, year > 0 {
                            Text("•  \(String(year))")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // Play Album Button on active (hover / selected)
                if isActive {
                    Button(action: {
                        viewModel.playAlbum(album)
                        viewModel.closeSpotlight()
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                    .buttonStyle(.plain)
                    .help("Reproducir álbum")
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? ColorTheme.terracotta : ColorTheme.textTertiary)
                    .opacity(isActive ? 0.7 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? ColorTheme.terracottaLight.opacity(0.8) : (isHovered ? ColorTheme.inputBackground : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? ColorTheme.terracotta.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointingHandOnHover()
        .onHover { hovering in
            if hovering {
                selectedItemId = "album-\(album.id)"
                hoveredItemId = "album-\(album.id)"
            } else if hoveredItemId == "album-\(album.id)" {
                hoveredItemId = nil
            }
        }
    }
    
    // MARK: - Song Row
    private func songRow(_ song: SongItem, isSelected: Bool) -> some View {
        let isHovered = hoveredItemId == "song-\(song.id)"
        let isActive = isSelected || isHovered
        let isCurrent = viewModel.currentSong?.id == song.id && !viewModel.mpv.isPaused
        
        return Button(action: {
            viewModel.playSong(song, inAlbum: nil, queue: viewModel.spotlightSongs)
            viewModel.closeSpotlight()
        }) {
            HStack(spacing: 12) {
                // Play Icon / Waveform indicator
                ZStack {
                    if isCurrent {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorTheme.terracotta)
                    } else if isActive {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.terracotta)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
                .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 13, weight: (isCurrent || isSelected) ? .bold : .medium))
                        .foregroundColor(isCurrent ? ColorTheme.terracotta : (isSelected ? ColorTheme.terracotta : ColorTheme.textPrimary))
                        .lineLimit(1)
                    
                    Text("\(song.displayArtist) • \(song.displayAlbum)")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Format badge
                if !song.formatBadge.isEmpty {
                    Text(song.formatBadge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(ColorTheme.cardBorder.opacity(0.4))
                        .cornerRadius(4)
                }
                
                // Duration
                Text(song.formattedDuration)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? ColorTheme.terracottaLight.opacity(0.8) : (isHovered ? ColorTheme.inputBackground : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? ColorTheme.terracotta.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointingHandOnHover()
        .onHover { hovering in
            if hovering {
                selectedItemId = "song-\(song.id)"
                hoveredItemId = "song-\(song.id)"
            } else if hoveredItemId == "song-\(song.id)" {
                hoveredItemId = nil
            }
        }
    }
    
    // MARK: - Footer Bar
    private var footerBarView: some View {
        HStack(spacing: 12) {
            shortcutHint(key: "↑↓", label: "Navegar")
            shortcutHint(key: "↵", label: "Abrir / Reproducir")
            shortcutHint(key: "ESC", label: "Cerrar")
            shortcutHint(key: "⌘K", label: "Alternar")
            
            Spacer()
            
            Text("Usa el teclado o clic para seleccionar")
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(ColorTheme.sidebarBackground.opacity(0.4))
    }
    
    private func shortcutHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(ColorTheme.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(ColorTheme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
                )
                .cornerRadius(4)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textSecondary)
        }
    }
    
    // MARK: - Keyboard Navigation Engine
    private func moveSelection(by delta: Int) {
        let items = flattenedResults
        guard !items.isEmpty else { return }
        
        guard let currentId = selectedItemId,
              let currentIndex = items.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = delta > 0 ? items.first?.id : items.last?.id
            return
        }
        
        let nextIndex = currentIndex + delta
        if nextIndex >= 0 && nextIndex < items.count {
            selectedItemId = items[nextIndex].id
        }
    }
    
    @discardableResult
    private func activateSelectedItem() -> Bool {
        guard let id = selectedItemId ?? flattenedResults.first?.id,
              let item = flattenedResults.first(where: { $0.id == id }) else {
            return false
        }
        
        switch item {
        case .artist(let artist):
            viewModel.navigateToArtist(artist)
            viewModel.closeSpotlight()
        case .album(let album):
            viewModel.navigateToAlbum(album)
            viewModel.closeSpotlight()
        case .song(let song):
            viewModel.playSong(song, inAlbum: nil, queue: viewModel.spotlightSongs)
            viewModel.closeSpotlight()
        }
        return true
    }
    
    private func setupKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            guard viewModel.isSpotlightPresented else { return event }
            
            switch event.keyCode {
            case 125: // Down Arrow
                if !flattenedResults.isEmpty {
                    moveSelection(by: 1)
                    return nil
                }
            case 126: // Up Arrow
                if !flattenedResults.isEmpty {
                    moveSelection(by: -1)
                    return nil
                }
            case 36: // Return / Enter
                if activateSelectedItem() {
                    return nil
                }
            default:
                break
            }
            return event
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    // MARK: - Helpers
    private var shouldShowArtists: Bool {
        viewModel.spotlightScope == nil || viewModel.spotlightScope == .artists
    }
    
    private var shouldShowAlbums: Bool {
        viewModel.spotlightScope == nil || viewModel.spotlightScope == .albums
    }
    
    private var shouldShowSongs: Bool {
        viewModel.spotlightScope == nil || viewModel.spotlightScope == .songs
    }
    
    private var hasNoResults: Bool {
        let artistsCount = shouldShowArtists ? viewModel.spotlightArtists.count : 0
        let albumsCount = shouldShowAlbums ? viewModel.spotlightAlbums.count : 0
        let songsCount = shouldShowSongs ? viewModel.spotlightSongs.count : 0
        return (artistsCount + albumsCount + songsCount) == 0 && !viewModel.isSpotlightLoading
    }
    
    private func resultCount(for scope: SpotlightScope) -> Int? {
        guard !viewModel.spotlightQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        switch scope {
        case .artists:
            return viewModel.spotlightArtists.count
        case .albums:
            return viewModel.spotlightAlbums.count
        case .songs:
            return viewModel.spotlightSongs.count
        }
    }
}
#endif
