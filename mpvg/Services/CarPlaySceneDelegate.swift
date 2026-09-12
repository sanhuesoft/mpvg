//
//  CarPlaySceneDelegate.swift
//  mpvg
//
//  CarPlay template application scene delegate integrating native CarPlay
//  playback controls (CPNowPlayingTemplate), player hub, and queue management.
//

#if canImport(CarPlay) && os(iOS)
import Foundation
import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPNowPlayingTemplateObserver {
    private var interfaceController: CPInterfaceController?
    private var rootListTemplate: CPListTemplate?
    private var isObserverRegistered = false
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        
        // 1. Ensure audio engine is ready
        PlayerViewModel.shared.mpv.start()
        
        // 2. Configure CarPlay Native Now Playing Template
        configureNowPlayingTemplate()
        
        // 3. Immediately sync Now Playing metadata & artwork
        PlayerViewModel.shared.syncNowPlaying()
        
        // 4. Build & set Root Player Template
        let rootTemplate = buildRootPlayerTemplate()
        self.rootListTemplate = rootTemplate
        interfaceController.setRootTemplate(rootTemplate, animated: false, completion: nil)
        
        // 5. Register Notification for live playback state updates
        setupPlaybackObserver()
        
        // 5. If audio is actively playing, automatically push the full Now Playing screen
        let vm = PlayerViewModel.shared
        if vm.currentSong != nil && !vm.mpv.isPaused {
            interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.rootListTemplate = nil
        NotificationCenter.default.removeObserver(self, name: .playbackStateDidChange, object: nil)
    }
    
    // MARK: - Playback State Observation
    private func setupPlaybackObserver() {
        NotificationCenter.default.removeObserver(self, name: .playbackStateDidChange, object: nil)
        NotificationCenter.default.addObserver(
            forName: .playbackStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackStateChange()
        }
    }
    
    private func handlePlaybackStateChange() {
        updateNowPlayingButtons()
        refreshRootTemplate()
    }
    
    // MARK: - Now Playing Template Setup
    private func configureNowPlayingTemplate() {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.isAlbumArtistButtonEnabled = true
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.upNextTitle = "Cola"
        
        if !isObserverRegistered {
            nowPlaying.add(self)
            isObserverRegistered = true
        }
        
        updateNowPlayingButtons()
    }
    
    private func updateNowPlayingButtons() {
        let nowPlaying = CPNowPlayingTemplate.shared
        let vm = PlayerViewModel.shared
        let song = vm.currentSong
        
        // 1. Rating / Like Button
        let rating = song?.userRating ?? 0
        let starIcon = rating > 0 ? "star.fill" : "star"
        let rateButton = CPNowPlayingImageButton(
            image: UIImage(systemName: starIcon) ?? UIImage()
        ) { [weak self] _ in
            guard let currentSong = PlayerViewModel.shared.currentSong else { return }
            let curRating = currentSong.userRating ?? 0
            let newRating = curRating >= 5 ? 0 : 5
            PlayerViewModel.shared.rateSong(currentSong, rating: newRating)
            self?.updateNowPlayingButtons()
        }
        
        // 2. Queue Button
        let queueButton = CPNowPlayingImageButton(
            image: UIImage(systemName: "list.bullet") ?? UIImage()
        ) { [weak self] _ in
            guard let self = self else { return }
            let queueTemplate = self.buildQueueTemplate()
            self.interfaceController?.pushTemplate(queueTemplate, animated: true, completion: nil)
        }
        
        nowPlaying.updateNowPlayingButtons([rateButton, queueButton])
    }
    
    // MARK: - CPNowPlayingTemplateObserver
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        let queueTemplate = buildQueueTemplate()
        interfaceController?.pushTemplate(queueTemplate, animated: true, completion: nil)
    }
    
    func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        let vm = PlayerViewModel.shared
        guard let current = vm.currentSong else { return }
        
        // If current album exists, display album tracks
        let targetAlbum = vm.currentAlbum ?? vm.albums.first(where: {
            $0.id == current.parent || (current.album != nil && $0.name == current.album)
        })
        
        if let album = targetAlbum {
            openAlbumDetail(album: album)
        }
    }
    
    // MARK: - Root Player Hub Template
    private func buildRootPlayerTemplate() -> CPListTemplate {
        let sections = makePlayerSections()
        let template = CPListTemplate(title: "Reproductor", sections: sections)
        template.trailingNavigationBarButtons = [makeNowPlayingNavButton()]
        return template
    }
    
    private func refreshRootTemplate() {
        guard let root = rootListTemplate else { return }
        root.updateSections(makePlayerSections())
    }
    
    private func makePlayerSections() -> [CPListSection] {
        let vm = PlayerViewModel.shared
        var sections: [CPListSection] = []
        
        // --- SECTION 1: Now Playing Item ---
        var nowPlayingItems: [CPListItem] = []
        if let current = vm.currentSong {
            let item = CPListItem(
                text: current.title,
                detailText: "\(current.displayArtist) — \(current.displayAlbum)"
            )
            item.setImage(UIImage(systemName: vm.mpv.isPaused ? "pause.circle.fill" : "play.circle.fill"))
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, completion in
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            nowPlayingItems.append(item)
        } else {
            let item = CPListItem(
                text: "No hay reproducción activa",
                detailText: "Inicia la reproducción desde la cola o tu iPhone"
            )
            item.isEnabled = false
            nowPlayingItems.append(item)
        }
        sections.append(CPListSection(items: nowPlayingItems, header: "Reproduciendo ahora", sectionIndexTitle: nil))
        
        // --- SECTION 2: Playback Controls ---
        var controlItems: [CPListItem] = []
        let isPaused = vm.mpv.isPaused
        let playPauseItem = CPListItem(
            text: isPaused ? "Reanudar" : "Pausar",
            detailText: isPaused ? "Toca para reproducir" : "Toca para pausar"
        )
        playPauseItem.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill"))
        playPauseItem.handler = { _, completion in
            PlayerViewModel.shared.togglePlayPause()
            completion()
        }
        controlItems.append(playPauseItem)
        
        let nextItem = CPListItem(
            text: "Pista siguiente",
            detailText: nil
        )
        nextItem.setImage(UIImage(systemName: "forward.fill"))
        nextItem.handler = { _, completion in
            PlayerViewModel.shared.nextTrack()
            completion()
        }
        controlItems.append(nextItem)
        
        let prevItem = CPListItem(
            text: "Pista anterior",
            detailText: nil
        )
        prevItem.setImage(UIImage(systemName: "backward.fill"))
        prevItem.handler = { _, completion in
            PlayerViewModel.shared.previousTrack()
            completion()
        }
        controlItems.append(prevItem)
        
        sections.append(CPListSection(items: controlItems, header: "Controles", sectionIndexTitle: nil))
        
        // --- SECTION 3: Up Next / Queue Preview ---
        let queue = vm.queue
        let currentIndex = vm.queueIndex
        var queueItems: [CPListItem] = []
        
        if !queue.isEmpty {
            let upcoming = Array(queue.enumerated())
            let slice = upcoming.prefix(20)
            
            for (idx, song) in slice {
                let isCurrent = idx == currentIndex
                let item = CPListItem(
                    text: isCurrent ? "▶ \(song.title)" : song.title,
                    detailText: "\(song.displayArtist) • \(song.formattedDuration)"
                )
                if isCurrent {
                    item.setImage(UIImage(systemName: "speaker.wave.2.fill"))
                }
                item.handler = { [weak self] _, completion in
                    let album = vm.currentAlbum ?? vm.albums.first(where: {
                        $0.id == song.parent || (song.album != nil && $0.name == song.album)
                    })
                    vm.playSong(song, inAlbum: album, queue: queue)
                    self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                    completion()
                }
                queueItems.append(item)
            }
        }
        
        if queueItems.isEmpty {
            let emptyItem = CPListItem(text: "Cola vacía", detailText: "No hay pistas en espera")
            emptyItem.isEnabled = false
            queueItems.append(emptyItem)
        }
        
        sections.append(CPListSection(items: queueItems, header: "A continuación", sectionIndexTitle: nil))
        
        return sections
    }
    
    // MARK: - Dedicated Queue Template
    private func buildQueueTemplate() -> CPListTemplate {
        let vm = PlayerViewModel.shared
        let queue = vm.queue
        let currentIndex = vm.queueIndex
        var items: [CPListItem] = []
        
        for (idx, song) in queue.enumerated() {
            let isCurrent = idx == currentIndex
            let item = CPListItem(
                text: isCurrent ? "▶ \(song.title)" : song.title,
                detailText: "\(song.displayArtist) • \(song.formattedDuration)"
            )
            if isCurrent {
                item.setImage(UIImage(systemName: "speaker.wave.2.fill"))
            }
            item.handler = { [weak self] _, completion in
                let album = vm.currentAlbum ?? vm.albums.first(where: {
                    $0.id == song.parent || (song.album != nil && $0.name == song.album)
                })
                vm.playSong(song, inAlbum: album, queue: queue)
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
                completion()
            }
            items.append(item)
        }
        
        if items.isEmpty {
            let emptyItem = CPListItem(text: "Cola de reproducción vacía", detailText: nil)
            emptyItem.isEnabled = false
            items.append(emptyItem)
        }
        
        let template = CPListTemplate(title: "Cola de reproducción", sections: [CPListSection(items: items)])
        template.trailingNavigationBarButtons = [makeNowPlayingNavButton()]
        return template
    }
    
    // MARK: - Album Detail Navigation
    private func openAlbumDetail(album: AlbumItem) {
        let vm = PlayerViewModel.shared
        
        let loadingTemplate = CPListTemplate(
            title: album.displayTitle,
            sections: [CPListSection(items: [CPListItem(text: "Cargando canciones...", detailText: nil)])]
        )
        interfaceController?.pushTemplate(loadingTemplate, animated: true, completion: nil)
        
        Task { @MainActor [weak self] in
            let tracks = await vm.loadTracksForCarPlay(album: album)
            let trackItems: [CPListItem] = tracks.map { song in
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
                sections: [CPListSection(items: trackItems.isEmpty ? [CPListItem(text: "Sin pistas disponibles", detailText: nil)] : trackItems)]
            )
            detailTemplate.trailingNavigationBarButtons = [self?.makeNowPlayingNavButton() ?? CPBarButton(type: .image, handler: { _ in })]
            
            self?.interfaceController?.popTemplate(animated: false, completion: nil)
            self?.interfaceController?.pushTemplate(detailTemplate, animated: true, completion: nil)
        }
    }
    
    // MARK: - Helpers
    private func makeNowPlayingNavButton() -> CPBarButton {
        let btn = CPBarButton(type: .image) { [weak self] _ in
            self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
        }
        btn.image = UIImage(systemName: "waveform")
        return btn
    }
}
#endif
