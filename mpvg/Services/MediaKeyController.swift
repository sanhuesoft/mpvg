//
//  MediaKeyController.swift
//  mpvg
//
//  Integrates macOS System Media Keys (Play/Pause, Next, Previous, Scrubber)
//  and MPNowPlayingInfoCenter for macOS Control Center & Menu Bar widgets.
//

import Foundation
import MediaPlayer
import AppKit

@MainActor
final class MediaKeyController {
    static let shared = MediaKeyController()
    
    private weak var viewModel: PlayerViewModel?
    private var isConfigured = false
    
    func configure(with viewModel: PlayerViewModel) {
        guard !isConfigured else { return }
        self.viewModel = viewModel
        self.isConfigured = true
        
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
        
        // Position Scrubber
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let vm = self?.viewModel,
                  let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
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
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.displayArtist,
            MPMediaItemPropertyAlbumTitle: song.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : (song.duration ?? 0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0.0 : 1.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // Load artwork asynchronously
        if let url = artworkURL {
            Task.detached(priority: .utility) {
                if let data = try? Data(contentsOf: url),
                   let nsImage = NSImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                    Task { @MainActor in
                        var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        current[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                    }
                }
            }
        }
    }
}
