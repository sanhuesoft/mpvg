//
//  MediaKeyController.swift
//  mpvg
//
//  Integrates System Media Keys (Play/Pause, Next, Previous, Scrubber)
//  and MPNowPlayingInfoCenter for macOS Control Center & iOS Lock Screen.
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
            return
        }
        
        let info: [String: Any] = [
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
                guard let data = try? Data(contentsOf: url) else { return }
                
                #if canImport(AppKit)
                guard let img = NSImage(data: data) else { return }
                let imgSize = img.size
                let artwork = MPMediaItemArtwork(boundsSize: imgSize) { _ in img }
                #elseif canImport(UIKit)
                guard let img = UIImage(data: data) else { return }
                let imgSize = img.size
                let artwork = MPMediaItemArtwork(boundsSize: imgSize) { _ in img }
                #endif
                
                Task { @MainActor in
                    var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    current[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = current
                }
            }
        }
    }
}
