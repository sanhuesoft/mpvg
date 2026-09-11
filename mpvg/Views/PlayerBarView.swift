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
    @State private var barWidth: CGFloat = 800
    
    var body: some View {
        let showTimeSlider = barWidth >= 540
        let showVolumeControl = barWidth >= 600
        let showStars = barWidth >= 500
        
        VStack(spacing: 0) {
            // Micro progress line at top of capsule when full scrubber is hidden
            if !showTimeSlider && viewModel.mpv.duration > 0 {
                GeometryReader { pGeo in
                    let progress = viewModel.mpv.duration > 0 ? (viewModel.mpv.currentTime / viewModel.mpv.duration) : 0.0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(ColorTheme.terracotta)
                            .frame(width: max(0, min(pGeo.size.width, pGeo.size.width * CGFloat(progress))), height: 2)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            
            HStack(spacing: 14) {
                // ── Left: Mini Artwork & Track Metadata ──
                HStack(spacing: 10) {
                    let artURL = viewModel.currentArtworkURL
                    
                    ZStack {
                        CachedAsyncImage(url: artURL) {
                            ZStack {
                                ColorTheme.cardBorder.opacity(0.5)
                                Image(systemName: "opticaldisc")
                                    .font(.system(size: 14))
                                    .foregroundColor(ColorTheme.terracotta)
                            }
                        }
                        .id(artURL)
                        
                        if viewModel.isLoadingTrack {
                            Color.black.opacity(0.4)
                            ProgressView()
                                .scaleEffect(0.6)
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
                        if let title = viewModel.currentSong?.title {
                            Text(title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ColorTheme.textPrimary)
                                .lineLimit(1)
                        } else {
                            Text("No track playing")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ColorTheme.textPrimary)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 5) {
                            Text(viewModel.currentSong?.displayArtist ?? "mpvg player")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(ColorTheme.textSecondary)
                                .lineLimit(1)
                            
                            if showStars, let song = viewModel.currentSong {
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
                .frame(minWidth: 120, idealWidth: 170, alignment: .leading)
                
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
                        .pointingHandOnHover()
                        
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
                        .pointingHandOnHover()
                        
                        Button(action: { viewModel.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textSecondary)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .pointingHandOnHover()
                    }
                    
                    if showTimeSlider {
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
                            .frame(minWidth: 70, idealWidth: 120, maxWidth: 160)
                            
                            Text(formatTime(viewModel.mpv.duration))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(ColorTheme.textTertiary)
                                .frame(width: 32, alignment: .leading)
                                .monospacedDigit()
                        }
                    } else if viewModel.mpv.duration > 0 {
                        // Compact time indicator when scrubber is hidden
                        Text(formatTime(viewModel.mpv.currentTime))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
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
                        Group {
                            if !viewModel.mpv.isDeviceConnected && !viewModel.mpv.preferredDeviceName.isEmpty {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(ColorTheme.terracotta)
                            } else if viewModel.mpv.isExclusive {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(ColorTheme.terracotta)
                            } else {
                                Image(systemName: "bolt")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(ColorTheme.textSecondary.opacity(0.75))
                            }
                        }
                        .frame(width: 26, height: 26)
                        .background(
                            viewModel.mpv.isExclusive
                                ? ColorTheme.terracottaLight.opacity(0.8)
                                : ColorTheme.cardBorder.opacity(0.35)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(viewModel.mpv.isExclusive ? ColorTheme.terracotta.opacity(0.3) : ColorTheme.cardBorder, lineWidth: 0.8)
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .help(viewModel.mpv.isExclusive ? "CoreAudio Exclusive Mode (Bit-Perfect)" : "Shared Audio Mode")
                    
                    if showVolumeControl {
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
                            .frame(minWidth: 40, idealWidth: 50, maxWidth: 65)
                        }
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
                .frame(minWidth: showVolumeControl ? 140 : 60, idealWidth: showVolumeControl ? 180 : 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: BarWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(BarWidthPreferenceKey.self) { newWidth in
            self.barWidth = newWidth
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
                .stroke(ColorTheme.cardBorder, lineWidth: 0.8)
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

private struct BarWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 800
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
