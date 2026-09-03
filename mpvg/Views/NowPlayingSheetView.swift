//
//  NowPlayingSheetView.swift
//  mpvg
//
//  Audiophile Now Playing screen for iOS and iPadOS with CaskHub warm aesthetic,
//  hero 1:1 album art, interactive scrubber, Hi-Res DAC status, and volume controls.
//

import SwiftUI

struct NowPlayingSheetView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var isDraggingSlider = false
    @State private var dragSliderValue: Double = 0.0
    
    private var displayTime: Double {
        isDraggingSlider ? dragSliderValue : viewModel.mpv.currentTime
    }
    
    var body: some View {
        ZStack {
            ColorTheme.windowBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar / Dismiss Handle
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ColorTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(ColorTheme.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(ColorTheme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("NOW PLAYING")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                            .tracking(1.5)
                        
                        if let albumName = viewModel.currentAlbum?.name {
                            Text(albumName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.textPrimary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Route / Device Indicator
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.mpv.isExclusive ? "bolt.fill" : "hifispeaker.fill")
                            .font(.system(size: 11))
                            .foregroundColor(viewModel.mpv.isExclusive ? ColorTheme.terracotta : ColorTheme.textSecondary)
                    }
                    .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer(minLength: 16)
                
                // Hero 1:1 Square Album Cover
                let artURL: URL? = {
                    if let coverId = viewModel.currentSong?.coverArt ?? viewModel.currentAlbum?.coverArt {
                        return viewModel.coverArtURL(for: coverId)
                    }
                    return nil
                }()
                
                CachedAsyncImage(url: artURL) {
                    ZStack {
                        LinearGradient(
                            colors: [ColorTheme.terracottaLight, ColorTheme.cardBorder],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "opticaldisc")
                            .font(.system(size: 64))
                            .foregroundColor(ColorTheme.terracotta)
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .frame(maxWidth: 320, maxHeight: 320)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(ColorTheme.cardBorder, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 36)
                
                Spacer(minLength: 24)
                
                // Song Metadata & Audiophile Badge
                VStack(spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentSong?.title ?? "Not playing")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(ColorTheme.textPrimary)
                                .lineLimit(1)
                            
                            Text(viewModel.currentSong?.displayArtist ?? "Select a track")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorTheme.textSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    
                    // Audio Quality Badge
                    HStack {
                        HStack(spacing: 5) {
                            if viewModel.mpv.isExclusive {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(ColorTheme.terracotta)
                                
                                Text("HI-RES LOSSLESS")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundColor(ColorTheme.terracotta)
                            } else {
                                Text("LOSSLESS")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(ColorTheme.textSecondary)
                            }
                            
                            if let rate = viewModel.mpv.audioSampleRate {
                                Text("• \(rate / 1000)kHz")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(ColorTheme.textSecondary)
                            }
                            
                            if !viewModel.mpv.currentDevice.isEmpty {
                                Text("• \(viewModel.mpv.currentDevice)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(ColorTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(viewModel.mpv.isExclusive ? ColorTheme.terracottaLight : ColorTheme.cardBorder.opacity(0.5))
                        .cornerRadius(6)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 28)
                
                Spacer(minLength: 16)
                
                // Interactive Scrubber
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { self.displayTime },
                            set: { newValue in
                                self.dragSliderValue = newValue
                            }
                        ),
                        in: 0...max(viewModel.mpv.duration, 1.0),
                        onEditingChanged: { editing in
                            self.isDraggingSlider = editing
                            if !editing {
                                viewModel.mpv.seek(to: self.dragSliderValue)
                            }
                        }
                    )
                    .accentColor(ColorTheme.terracotta)
                    
                    HStack {
                        Text(formatSeconds(displayTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Spacer()
                        
                        let remaining = max(0, viewModel.mpv.duration - displayTime)
                        Text("-\(formatSeconds(remaining))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 28)
                
                Spacer(minLength: 16)
                
                // Transport Controls
                HStack(spacing: 36) {
                    Button(action: { viewModel.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 26))
                            .foregroundColor(ColorTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(ColorTheme.terracotta)
                                .frame(width: 68, height: 68)
                                .shadow(color: ColorTheme.terracotta.opacity(0.35), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: viewModel.mpv.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                                .offset(x: viewModel.mpv.isPaused ? 2 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 26))
                            .foregroundColor(ColorTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer(minLength: 20)
                
                // Volume Slider
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Slider(
                        value: Binding(
                            get: { viewModel.mpv.volume },
                            set: { viewModel.mpv.setVolume($0) }
                        ),
                        in: 0...100
                    )
                    .accentColor(ColorTheme.terracotta)
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }
    
    private func formatSeconds(_ secs: Double) -> String {
        guard !secs.isNaN && secs >= 0 else { return "00:00" }
        let total = Int(secs)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
