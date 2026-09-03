//
//  PlayerBarView.swift
//  mpvg
//
//  Floating crystal (liquid glass) player bar inspired by Apple Music macOS.
//  Features frosted glass translucency, live track artwork, scrub controls,
//  elapsed/remaining time counters, CoreAudio Exclusive Mode indicator, and queue access.
//

import SwiftUI

struct PlayerBarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isDraggingSlider: Bool = false
    @State private var dragValue: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Subtle progress bar on top edge of crystal bar
            GeometryReader { geo in
                let current = isDraggingSlider ? dragValue : viewModel.mpv.currentTime
                let total = viewModel.mpv.duration
                let progress = total > 0 ? max(0.0, min(1.0, current / total)) : 0.0
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(ColorTheme.cardBorder.opacity(0.3))
                        .frame(height: 2)
                    
                    Rectangle()
                        .fill(ColorTheme.terracotta)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: 2)
                }
            }
            .frame(height: 2)
            
            HStack(spacing: 16) {
                // ── Left: Mini Artwork & Track Metadata ──
                HStack(spacing: 10) {
                    let artURL: URL? = {
                        if let coverId = viewModel.currentSong?.coverArt ?? viewModel.currentAlbum?.coverArt {
                            return viewModel.coverArtURL(for: coverId)
                        }
                        return nil
                    }()
                    
                    CachedAsyncImage(url: artURL) {
                        ZStack {
                            ColorTheme.cardBorder.opacity(0.5)
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 14))
                                .foregroundColor(ColorTheme.terracotta)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentSong?.title ?? "No track playing")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            Text(viewModel.currentSong?.displayArtist ?? "mpvg player")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(ColorTheme.textSecondary)
                                .lineLimit(1)
                            
                            if let song = viewModel.currentSong {
                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundColor(ColorTheme.textTertiary)
                                
                                StarRatingView(
                                    rating: song.rating,
                                    size: 9,
                                    spacing: 2,
                                    interactive: true
                                ) { newRating in
                                    viewModel.rateSong(song, rating: newRating)
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 200, alignment: .leading)
                
                Spacer(minLength: 6)
                
                // ── Center: Transport Controls & Scrubber ──
                HStack(spacing: 12) {
                    // Transport Buttons
                    HStack(spacing: 10) {
                        Button(action: { viewModel.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textSecondary)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { viewModel.togglePlayPause() }) {
                            Image(systemName: viewModel.mpv.isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(ColorTheme.terracotta)
                                .clipShape(Circle())
                                .shadow(color: ColorTheme.terracotta.opacity(0.35), radius: 4, x: 0, y: 1.5)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                        
                        Button(action: { viewModel.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textSecondary)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Track Scrubber with Live Elapsed & Duration counters
                    HStack(spacing: 6) {
                        let displayedTime = isDraggingSlider ? dragValue : viewModel.mpv.currentTime
                        
                        Text(formatTime(displayedTime))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                            .frame(width: 32, alignment: .trailing)
                            .monospacedDigit()
                        
                        Slider(
                            value: Binding(
                                get: { isDraggingSlider ? dragValue : viewModel.mpv.currentTime },
                                set: { val in
                                    dragValue = val
                                    if !isDraggingSlider {
                                        viewModel.mpv.seek(to: val)
                                    }
                                }
                            ),
                            in: 0...max(viewModel.mpv.duration, 1.0),
                            onEditingChanged: { editing in
                                isDraggingSlider = editing
                                if !editing {
                                    viewModel.mpv.seek(to: dragValue)
                                }
                            }
                        )
                        .accentColor(ColorTheme.terracotta)
                        .tint(ColorTheme.terracotta)
                        .frame(width: 140)
                        
                        Text(formatTime(viewModel.mpv.duration))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                            .frame(width: 32, alignment: .leading)
                            .monospacedDigit()
                    }
                }
                
                Spacer(minLength: 6)
                
                // ── Right: CoreAudio Exclusive / DAC & Volume & Queue ──
                HStack(spacing: 10) {
                    // Exclusive Audio Status / Device Menu
                    Menu {
                        if let warning = viewModel.mpv.deviceWarning {
                            Text("⚠️ \(warning)")
                                .foregroundColor(ColorTheme.terracotta)
                            Divider()
                        }
                        
                        Button(action: { viewModel.mpv.toggleExclusive() }) {
                            Label(
                                viewModel.mpv.isExclusive ? "Disable Exclusive Mode" : "Enable Exclusive Mode",
                                systemImage: viewModel.mpv.isExclusive ? "bolt.slash" : "bolt.fill"
                            )
                        }
                        
                        Divider()
                        
                        Text("Output device:")
                        ForEach(viewModel.mpv.availableDevices) { dev in
                            Button(action: { viewModel.mpv.setDevice(dev.id) }) {
                                HStack {
                                    Text(dev.displayName)
                                    if viewModel.mpv.currentDevice == dev.id && viewModel.mpv.isDeviceConnected {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if !viewModel.mpv.isDeviceConnected && !viewModel.mpv.preferredDeviceName.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(ColorTheme.terracotta)
                                
                                Text("DAC OFF")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(ColorTheme.terracotta)
                            } else if viewModel.mpv.isExclusive {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(ColorTheme.terracotta)
                                
                                Text("EXCLUSIVE")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(ColorTheme.terracotta)
                            } else {
                                Text("SHARED")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(ColorTheme.textTertiary)
                            }
                            
                            if let rate = viewModel.mpv.audioSampleRate {
                                Text("• \(rate / 1000)kHz")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(ColorTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(viewModel.mpv.isExclusive ? ColorTheme.terracottaLight.opacity(0.8) : ColorTheme.cardBorder.opacity(0.4))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    
                    // Volume Control with Terracotta Accent
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.mpv.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.mpv.volume },
                                set: { viewModel.mpv.setVolume($0) }
                            ),
                            in: 0...100
                        )
                        .accentColor(ColorTheme.terracotta)
                        .tint(ColorTheme.terracotta)
                        .frame(width: 60)
                    }
                    
                    // Queue Button (Opens Playing Queue Popover)
                    Button(action: {
                        viewModel.showQueueSheet.toggle()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12, weight: .bold))
                            if viewModel.queue.count > 1 {
                                Text("\(viewModel.queue.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundColor(viewModel.showQueueSheet ? ColorTheme.terracotta : ColorTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(viewModel.showQueueSheet ? ColorTheme.terracottaLight.opacity(0.8) : ColorTheme.cardBorder.opacity(0.4))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $viewModel.showQueueSheet, arrowEdge: .top) {
                        QueueView(viewModel: viewModel)
                    }
                }
                .frame(minWidth: 220, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ColorTheme.cardBackground.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 5)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let min = total / 60
        let sec = total % 60
        return String(format: "%02d:%02d", min, sec)
    }
}
