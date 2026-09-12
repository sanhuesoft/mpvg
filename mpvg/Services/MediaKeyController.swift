//
//  MediaKeyController.swift
//  mpvg
//
//  Integrates System Media Keys (Play/Pause, Next, Previous, Scrubber)
//  and MPNowPlayingInfoCenter for macOS Control Center, iOS Lock Screen & Apple CarPlay.
//

import Foundation
import MediaPlayer
import CoreGraphics

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MediaKeyController {
    static let shared = MediaKeyController()
    
    private weak var viewModel: PlayerViewModel?
    private var isConfigured = false
    
    func configure(with viewModel: PlayerViewModel) {
        guard !isConfigured else { return }
        self.viewModel = viewModel
        self.isConfigured = true
        
        #if canImport(UIKit)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif
        
        let center = MPRemoteCommandCenter.shared()
        
        // Play / Pause / Toggle
        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let vm = self?.viewModel else { return .commandFailed }
            Task { @MainActor in
                if vm.mpv.isPaused {
                    vm.togglePlayPause()
                }
            }
            return .success
        }
        
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            guard let vm = self?.viewModel else { return .commandFailed }
            Task { @MainActor in
                if !vm.mpv.isPaused {
                    vm.togglePlayPause()
                }
            }
            return .success
        }
        
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let vm = self?.viewModel else { return .commandFailed }
            Task { @MainActor in
                vm.togglePlayPause()
            }
            return .success
        }
        
        // Next & Previous
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let vm = self?.viewModel else { return .commandFailed }
            Task { @MainActor in
                vm.nextTrack()
            }
            return .success
        }
        
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let vm = self?.viewModel else { return .commandFailed }
            Task { @MainActor in
                vm.previousTrack()
            }
            return .success
        }
        
        // Scrubber / Seek
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent,
                  let vm = self?.viewModel else { return .commandFailed }
            Task { @MainActor in
                vm.mpv.seek(to: posEvent.positionTime)
            }
            return .success
        }
    }
    
    func updateNowPlaying(
        song: SongItem?,
        duration: Double,
        currentTime: Double,
        isPaused: Bool,
        artworkURL: URL?
    ) {
        guard let song = song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            #if canImport(UIKit)
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            #endif
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.displayArtist,
            MPMediaItemPropertyAlbumTitle: song.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : (song.duration ?? 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        
        if let trackNum = song.track {
            info[MPMediaItemPropertyAlbumTrackNumber] = trackNum
        }
        
        #if canImport(UIKit)
        MPNowPlayingInfoCenter.default().playbackState = isPaused ? .paused : .playing
        #endif
        
        // 1. Try immediate synchronous cache lookup for artwork
        var artworkApplied = false
        if let url = artworkURL {
            if let cachedImg = ArtworkCacheManager.shared.syncImage(for: url) {
                let imgSize = cachedImg.size
                let artwork = MPMediaItemArtwork(boundsSize: imgSize) { _ in cachedImg }
                info[MPMediaItemPropertyArtwork] = artwork
                artworkApplied = true
            }
        }
        
        // 2. Fallback placeholder artwork so CarPlay Now Playing is never blank or dark
        if !artworkApplied {
            #if canImport(UIKit)
            if let placeholder = createPlaceholderArtwork(title: song.title, artist: song.displayArtist) {
                let artwork = MPMediaItemArtwork(boundsSize: placeholder.size) { _ in placeholder }
                info[MPMediaItemPropertyArtwork] = artwork
            }
            #endif
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // 3. Asynchronously fetch high-resolution artwork via ArtworkCacheManager and update
        if let url = artworkURL, !artworkApplied {
            Task { @MainActor in
                if let img = await ArtworkCacheManager.shared.image(for: url) {
                    let imgSize = img.size
                    let artwork = MPMediaItemArtwork(boundsSize: imgSize) { _ in img }
                    
                    var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    current[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                }
            }
        }
    }
    
    #if canImport(UIKit)
    private func createPlaceholderArtwork(title: String, artist: String) -> UIImage? {
        let size = CGSize(width: 500, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            
            // Rich dark gradient background
            let colors = [
                UIColor(red: 0.22, green: 0.16, blue: 0.28, alpha: 1.0).cgColor,
                UIColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 1.0).cgColor
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
                cg.drawLinearGradient(gradient, start: CGPoint.zero, end: CGPoint(x: 500, y: 500), options: [])
            }
            
            // Musical waveform / note symbol
            let config = UIImage.SymbolConfiguration(pointSize: 150, weight: .regular)
            if let noteImg = UIImage(systemName: "music.note", withConfiguration: config)?.withTintColor(.white.withAlphaComponent(0.65), renderingMode: .alwaysOriginal) {
                let rect = CGRect(
                    x: (500 - noteImg.size.width) / 2,
                    y: (500 - noteImg.size.height) / 2,
                    width: noteImg.size.width,
                    height: noteImg.size.height
                )
                noteImg.draw(in: rect)
            }
        }
    }
    #endif
}
