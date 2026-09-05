//
//  CarPlaySceneDelegate.swift
//  mpvg
//
//  CarPlay template application scene delegate integrating native CarPlay
//  playback controls (CPNowPlayingTemplate) and library browsing templates.
//

#if canImport(CarPlay) && os(iOS)
import Foundation
import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        // 1. Configure CarPlay Native Now Playing Template
        configureNowPlayingTemplate()
        
        // 2. Build Root Browsing Templates with NowPlaying Navigation Button
        let rootTemplate = buildRootTemplate()
        interfaceController.setRootTemplate(rootTemplate, animated: false, completion: nil)
        
        // 3. If audio is actively playing, automatically push the Now Playing screen
        if let vm = PlayerViewModel.shared, vm.currentSong != nil, !vm.mpv.isPaused {
            interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
    
    // MARK: - Now Playing Template Setup
    private func configureNowPlayingTemplate() {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isAlbumArtistButtonEnabled = true
        nowPlaying.isUpNextButtonEnabled = true
        
        // Rating / Like button
        let rateButton = CPNowPlayingImageButton(
            image: UIImage(systemName: "star.fill") ?? UIImage()
        ) { [weak self] _ in
            guard let vm = PlayerViewModel.shared, let song = vm.currentSong else { return }
            let currentRating = song.userRating ?? 0
            let newRating = currentRating >= 5 ? 0 : currentRating + 1
            vm.rateSong(song, rating: newRating)
            self?.updateNowPlayingButtons()
        }
        
        // Next track button
        let nextButton = CPNowPlayingImageButton(
            image: UIImage(systemName: "forward.end.fill") ?? UIImage()
        ) { _ in
            PlayerViewModel.shared?.nextTrack()
        }
        
        nowPlaying.updateNowPlayingButtons([rateButton, nextButton])
    }
    
    private func updateNowPlayingButtons() {
        let nowPlaying = CPNowPlayingTemplate.shared
        guard let song = PlayerViewModel.shared?.currentSong else { return }
        let rating = song.userRating ?? 0
        let iconName = rating > 0 ? "star.fill" : "star"
        
        let rateButton = CPNowPlayingImageButton(
            image: UIImage(systemName: iconName) ?? UIImage()
        ) { [weak self] _ in
            guard let vm = PlayerViewModel.shared, let currentSong = vm.currentSong else { return }
            let cur = currentSong.userRating ?? 0
            let nextRate = cur >= 5 ? 0 : 5
            vm.rateSong(currentSong, rating: nextRate)
            self?.updateNowPlayingButtons()
        }
        
        let nextButton = CPNowPlayingImageButton(
            image: UIImage(systemName: "forward.end.fill") ?? UIImage()
        ) { _ in
            PlayerViewModel.shared?.nextTrack()
        }
        
        nowPlaying.updateNowPlayingButtons([rateButton, nextButton])
    }
    
    // MARK: - Root Navigation Template
    private func buildRootTemplate() -> CPTemplate {
        let nowPlayingTab = buildNowPlayingTab()
        let recentTab = buildRecentAlbumsTab()
        let albumsTab = buildAlbumsTab()
        let artistsTab = buildArtistsTab()
        
        let tabBar = CPTabBarTemplate(templates: [nowPlayingTab, recentTab, albumsTab, artistsTab])
        return tabBar
    }
    
    // MARK: - Now Playing Tab / Quick Player Control
    private func buildNowPlayingTab() -> CPListTemplate {
        let vm = PlayerViewModel.shared
        var items: [CPListItem] = []
        
        if let current = vm?.currentSong {
            let item = CPListItem(
                text: current.title,
                detailText: "\(current.displayArtist) — \(current.displayAlbum)"
            )
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            items.append(item)
            
            let toggleItem = CPListItem(
                text: (vm?.mpv.isPaused ?? true) ? "Reanudar Reproducción" : "Pausar",
                detailText: "Control de reproducción actual"
            )
            toggleItem.setImage(UIImage(systemName: (vm?.mpv.isPaused ?? true) ? "play.fill" : "pause.fill"))
            toggleItem.handler = { _, completion in
                vm?.togglePlayPause()
                completion()
            }
            items.append(toggleItem)
        } else {
            let item = CPListItem(text: "No hay reproducción activa", detailText: "Selecciona un álbum o canción para comenzar")
            item.isEnabled = false
            items.append(item)
        }
        
        let template = CPListTemplate(title: "Reproductor", sections: [CPListSection(items: items)])
        template.tabImage = UIImage(systemName: "play.circle.fill")
        template.trailingNavigationBarButtons = [makeNowPlayingNavButton()]
        return template
    }
    
    // MARK: - Recently Added Albums Tab
    private func buildRecentAlbumsTab() -> CPListTemplate {
        let vm = PlayerViewModel.shared
        let albums = vm?.recentAlbums ?? []
        
        let items: [CPListItem] = albums.prefix(25).map { album in
            let item = CPListItem(text: album.displayTitle, detailText: album.displayArtist)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.openAlbumDetail(album: album)
                completion()
            }
            return item
        }
        
        let template = CPListTemplate(
            title: "Recientes",
            sections: [CPListSection(items: items.isEmpty ? [emptyPlaceholderItem(text: "Sin álbumes recientes")] : items)]
        )
        template.tabImage = UIImage(systemName: "clock.fill")
        template.trailingNavigationBarButtons = [makeNowPlayingNavButton()]
        return template
    }
    
    // MARK: - All Albums Tab
    private func buildAlbumsTab() -> CPListTemplate {
        let vm = PlayerViewModel.shared
        let albums = vm?.albums ?? []
        
        let items: [CPListItem] = albums.prefix(50).map { album in
            let item = CPListItem(text: album.displayTitle, detailText: album.displayArtist)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.openAlbumDetail(album: album)
                completion()
            }
            return item
        }
        
        let template = CPListTemplate(
            title: "Álbumes",
            sections: [CPListSection(items: items.isEmpty ? [emptyPlaceholderItem(text: "Sin álbumes")] : items)]
        )
        template.tabImage = UIImage(systemName: "opticaldisc.fill")
        template.trailingNavigationBarButtons = [makeNowPlayingNavButton()]
        return template
    }
    
    // MARK: - Artists Tab
    private func buildArtistsTab() -> CPListTemplate {
        let vm = PlayerViewModel.shared
        let artists = vm?.artists ?? []
        
        let items: [CPListItem] = artists.prefix(40).map { artist in
            let count = artist.albumCount ?? 0
            let item = CPListItem(
                text: artist.name,
                detailText: count > 0 ? "\(count) \(count == 1 ? "álbum" : "álbumes")" : "Artista"
            )
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.openArtistDetail(artist: artist)
                completion()
            }
            return item
        }
        
        let template = CPListTemplate(
            title: "Artistas",
            sections: [CPListSection(items: items.isEmpty ? [emptyPlaceholderItem(text: "Sin artistas")] : items)]
        )
        template.tabImage = UIImage(systemName: "music.mic")
        template.trailingNavigationBarButtons = [makeNowPlayingNavButton()]
        return template
    }
    
    // MARK: - Album Navigation
    private func openAlbumDetail(album: AlbumItem) {
        guard let vm = PlayerViewModel.shared else { return }
        
        let loadingTemplate = CPListTemplate(
            title: album.displayTitle,
            sections: [CPListSection(items: [emptyPlaceholderItem(text: "Cargando canciones...")])]
        )
        interfaceController?.pushTemplate(loadingTemplate, animated: true, completion: nil)
        
        Task { @MainActor [weak self] in
            let tracks = await vm.loadTracksForCarPlay(album: album)
            let trackItems: [CPListItem] = tracks.enumerated().map { (idx, song) in
                let item = CPListItem(text: song.title, detailText: song.formattedDuration)
                item.handler = { [weak self] _, completion in
                    vm.playSong(song, inAlbum: album, queue: tracks)
                    self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                    completion()
                }
                return item
            }
            
            let detailTemplate = CPListTemplate(
                title: album.displayTitle,
                sections: [CPListSection(items: trackItems.isEmpty ? [self?.emptyPlaceholderItem(text: "Sin pistas disponibles") ?? CPListItem(text: "Vacío", detailText: nil)] : trackItems)]
            )
            detailTemplate.trailingNavigationBarButtons = [self?.makeNowPlayingNavButton() ?? CPBarButton(type: .image, handler: { _ in })]
            
            // Pop the loading and push detail
            self?.interfaceController?.popTemplate(animated: false, completion: nil)
            self?.interfaceController?.pushTemplate(detailTemplate, animated: true, completion: nil)
        }
    }
    
    // MARK: - Artist Navigation
    private func openArtistDetail(artist: ArtistItem) {
        guard let vm = PlayerViewModel.shared else { return }
        let artistAlbums = vm.albums.filter { $0.artistId == artist.id || $0.displayArtist.localizedCaseInsensitiveContains(artist.name) }
        
        let items: [CPListItem] = artistAlbums.map { album in
            let item = CPListItem(text: album.displayTitle, detailText: album.displayYear)
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.openAlbumDetail(album: album)
                completion()
            }
            return item
        }
        
        let template = CPListTemplate(
            title: artist.name,
            sections: [CPListSection(items: items.isEmpty ? [emptyPlaceholderItem(text: "Sin álbumes disponibles")] : items)]
        )
        template.trailingNavigationBarButtons = [makeNowPlayingNavButton()]
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }
    
    // MARK: - Helpers
    private func makeNowPlayingNavButton() -> CPBarButton {
        let btn = CPBarButton(type: .image) { [weak self] _ in
            self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
        btn.image = UIImage(systemName: "waveform")
        return btn
    }
    
    private func emptyPlaceholderItem(text: String) -> CPListItem {
        let item = CPListItem(text: text, detailText: nil)
        item.isEnabled = false
        return item
    }
}
#endif
