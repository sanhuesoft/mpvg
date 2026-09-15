//
//  PlayerBarView.swift
//  mpvg
//
//  Floating crystal (liquid glass) player capsule inspired by Apple Music macOS.
//  Features a sleek rounded pill shape, Apple-style monochrome transport controls,
//  clean centered track info and scrubber, CoreAudio AirPlay/Exclusive selector,
//  volume slider, and queue popover.
//

import SwiftUI

#if os(macOS)
import AppKit

private struct LiquidGlassRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
#endif

struct PlayerBarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isDraggingSlider: Bool = false
    @State private var dragValue: Double = 0.0
    @State private var barWidth: CGFloat = 800
    @State private var showRemainingTime: Bool = false
    @State private var previousVolume: Double = 50.0
    
    var body: some View {
        let showFullTransport = barWidth >= 520
        let showTimeSlider = barWidth >= 480
        let showVolumeControl = barWidth >= 620
        
        HStack(spacing: 0) {
            // ── Left: Transport Controls (Apple Music Style) ──
            HStack(spacing: 12) {
                if showFullTransport {
                    // Shuffle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.toggleShuffle()
                        }
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: viewModel.isShuffleEnabled ? .bold : .regular))
                            .foregroundColor(viewModel.isShuffleEnabled ? ColorTheme.accent : Color.primary.opacity(0.55))
                            .frame(width: 24, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                    .help(viewModel.isShuffleEnabled ? "Aleatorio activado" : "Aleatorio desactivado")
                }
                
                // Previous
                Button(action: { viewModel.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.primary.opacity(0.65))
                        .frame(width: 26, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .help("Pista anterior")
                
                // Play / Pause (Clean bold glyph, no red circle)
                Button(action: { viewModel.togglePlayPause() }) {
                    Image(systemName: viewModel.mpv.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.primary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .pointingHandOnHover()
                .help(viewModel.mpv.isPaused ? "Reproducir" : "Pausar")
                
                // Next
                Button(action: { viewModel.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.primary.opacity(0.65))
                        .frame(width: 26, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .help("Pista siguiente")
                
                if showFullTransport {
                    // Repeat
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.cycleRepeatMode()
                        }
                    }) {
                        Image(systemName: viewModel.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 13, weight: viewModel.repeatMode != .off ? .bold : .regular))
                            .foregroundColor(viewModel.repeatMode != .off ? ColorTheme.accent : Color.primary.opacity(0.55))
                            .frame(width: 24, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                    .help(repeatTooltip)
                }
            }
            .frame(minWidth: showFullTransport ? 140 : 90, alignment: .leading)
            
            Spacer(minLength: 12)
            
            // ── Center: Song Information & Apple Scrubber (No cover, No Apple logo) ──
            VStack(spacing: 3) {
                if let song = viewModel.currentSong {
                    HStack(spacing: 5) {
                        Text(song.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.primary)
                            .lineLimit(1)
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(Color.primary.opacity(0.35))
                        
                        Text(song.displayArtist)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.primary.opacity(0.65))
                            .lineLimit(1)
                        
                        // Favorite Heart
                        Button(action: {
                            viewModel.toggleStarred(for: song)
                        }) {
                            Image(systemName: song.isStarred ? "heart.fill" : "heart")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(song.isStarred ? ColorTheme.accent : Color.primary.opacity(0.35))
                                .frame(width: 14, height: 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHandOnHover()
                        .help(song.isStarred ? "Quitar de Favoritas" : "Añadir a Favoritas")
                    }
                    
                    if showTimeSlider {
                        HStack(spacing: 6) {
                            let displayedTime = isDraggingSlider ? dragValue : viewModel.mpv.currentTime
                            
                            Text(formatTime(displayedTime))
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.primary.opacity(0.45))
                                .frame(width: 32, alignment: .trailing)
                                .monospacedDigit()
                            
                            AppleScrubberBar(
                                currentTime: displayedTime,
                                duration: max(viewModel.mpv.duration, 1.0),
                                isDragging: $isDraggingSlider,
                                dragValue: $dragValue,
                                onSeek: { newTime in
                                    viewModel.mpv.seek(to: newTime)
                                }
                            )
                            .frame(height: 12)
                            
                            Button(action: {
                                showRemainingTime.toggle()
                            }) {
                                let remaining = max(0, viewModel.mpv.duration - displayedTime)
                                Text(showRemainingTime ? "-\(formatTime(remaining))" : formatTime(viewModel.mpv.duration))
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.primary.opacity(0.45))
                                    .frame(width: 36, alignment: .leading)
                                    .monospacedDigit()
                            }
                            .buttonStyle(.plain)
                            .pointingHandOnHover()
                            .help("Alternar tiempo restante / duración total")
                        }
                    }
                } else {
                    // Stopped / Idle state: centered minimalist text matching Apple Music typography
                    Text("Ninguna canción en reproducción")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.primary.opacity(0.60))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 400)
            
            Spacer(minLength: 12)
            
            // ── Right: Utilities (Queue, Output Device / AirPlay, Volume) ──
            HStack(spacing: 10) {
                // Queue Button
                Button(action: {
                    viewModel.showQueueSheet.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 13, weight: .medium))
                        if viewModel.queue.count > 1 {
                            Text("\(viewModel.queue.count)")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: true)
                        }
                    }
                    .foregroundColor(viewModel.showQueueSheet ? ColorTheme.accent : Color.primary.opacity(0.65))
                    .frame(height: 28)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
                .help("Cola de reproducción")
                .popover(isPresented: $viewModel.showQueueSheet, arrowEdge: .top) {
                    QueueView(viewModel: viewModel)
                }
                
                // AirPlay / Audio Output Device Menu
                Menu {
                    if let warning = viewModel.mpv.deviceWarning {
                        Text("⚠️ \(warning)")
                            .foregroundColor(ColorTheme.terracotta)
                        Divider()
                    }
                    
                    Button(action: { viewModel.mpv.toggleExclusive() }) {
                        Label(
                            viewModel.mpv.isExclusive ? "Desactivar Modo Exclusivo (Bit-Perfect)" : "Activar Modo Exclusivo (Bit-Perfect)",
                            systemImage: viewModel.mpv.isExclusive ? "bolt.slash" : "bolt.fill"
                        )
                    }
                    
                    Divider()
                    
                    Text("Dispositivo de salida:")
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
                    ZStack(alignment: .topTrailing) {
                        if !viewModel.mpv.isDeviceConnected && !viewModel.mpv.preferredDeviceName.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(ColorTheme.accent)
                        } else {
                            Image(systemName: "airplayaudio")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(viewModel.mpv.isExclusive ? ColorTheme.accent : Color.primary.opacity(0.65))
                        }
                        
                        if viewModel.mpv.isExclusive {
                            Circle()
                                .fill(ColorTheme.accent)
                                .frame(width: 5, height: 5)
                                .offset(x: 4, y: -2)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .pointingHandOnHover()
                .help(viewModel.mpv.isExclusive ? "CoreAudio Modo Exclusivo (Bit-Perfect)" : "Dispositivo de salida")
                
                // Volume Control (Speaker + Slider)
                if showVolumeControl {
                    HStack(spacing: 5) {
                        Button(action: {
                            if viewModel.mpv.volume > 0 {
                                previousVolume = viewModel.mpv.volume
                                viewModel.mpv.setVolume(0)
                            } else {
                                viewModel.mpv.setVolume(previousVolume > 0 ? previousVolume : 50)
                            }
                        }) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.primary.opacity(0.65))
                                .frame(width: 16, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHandOnHover()
                        .help(viewModel.mpv.volume == 0 ? "Reactivar audio" : "Silenciar")
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.mpv.volume },
                                set: { viewModel.mpv.setVolume($0) }
                            ),
                            in: 0...100
                        )
                        .accentColor(Color.primary.opacity(0.65))
                        .tint(Color.primary.opacity(0.65))
                        .controlSize(.mini)
                        .frame(width: 65)
                    }
                } else {
                    // Compact speaker icon button when narrow
                    Button(action: {
                        if viewModel.mpv.volume > 0 {
                            previousVolume = viewModel.mpv.volume
                            viewModel.mpv.setVolume(0)
                        } else {
                            viewModel.mpv.setVolume(previousVolume > 0 ? previousVolume : 50)
                        }
                    }) {
                        Image(systemName: volumeIcon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.primary.opacity(0.65))
                            .frame(width: 24, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHandOnHover()
                    .help(viewModel.mpv.volume == 0 ? "Reactivar audio" : "Silenciar")
                }
            }
            .frame(minWidth: showVolumeControl ? 150 : 80, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .frame(height: 50)
        .frame(maxWidth: 860)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: BarWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(BarWidthPreferenceKey.self) { newWidth in
            self.barWidth = newWidth
        }
        // Authentic Apple Music Liquid Glass Capsule
        .background(
            ZStack {
                #if os(macOS)
                LiquidGlassRepresentable(material: .popover, blendingMode: .withinWindow)
                    .clipShape(Capsule())
                #else
                Capsule()
                    .fill(.ultraThinMaterial)
                #endif
                
                // Luminous translucent tint (pure white glass in light mode, deep glass in dark mode)
                Capsule()
                    .fill(Color.dynamic(light: "FFFFFF", dark: "242426").opacity(0.72))
            }
        )
        // Specular reflection / Rim light (Apple top-edge reflection)
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(0.95), location: 0.0),
                            Gradient.Stop(color: Color.white.opacity(0.40), location: 0.35),
                            Gradient.Stop(color: Color.white.opacity(0.12), location: 0.75),
                            Gradient.Stop(color: Color.black.opacity(0.06), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.0
                )
        )
        // Inner specular top glow
        .overlay(
            Capsule()
                .inset(by: 1.0)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(0.55), location: 0.0),
                            Gradient.Stop(color: Color.clear, location: 0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        )
        .clipShape(Capsule())
        // Dual-depth shadow (soft ambient + crisp contact)
        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Helpers
    private var volumeIcon: String {
        let vol = viewModel.mpv.volume
        if vol == 0 {
            return "speaker.slash.fill"
        } else if vol < 33 {
            return "speaker.fill"
        } else if vol < 66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
    
    private var repeatTooltip: String {
        switch viewModel.repeatMode {
        case .off: return "Repetición desactivada"
        case .all: return "Repetir todo"
        case .one: return "Repetir una canción"
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let min = total / 60
        let sec = total % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

// MARK: - Apple-Style Sleek Scrubber Bar
struct AppleScrubberBar: View {
    let currentTime: Double
    let duration: Double
    @Binding var isDragging: Bool
    @Binding var dragValue: Double
    let onSeek: (Double) -> Void
    
    @State private var isHovered: Bool = false
    
    private var progress: Double {
        guard duration > 0 else { return 0.0 }
        let current = isDragging ? dragValue : currentTime
        return max(0.0, min(1.0, current / duration))
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackHeight: CGFloat = isHovered || isDragging ? 4 : 3
            
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: trackHeight)
                
                // Active progress bar
                Capsule()
                    .fill(ColorTheme.accent)
                    .frame(width: max(0, min(width, width * CGFloat(progress))), height: trackHeight)
                
                // Small thumb indicator (revealed on hover or drag)
                if isHovered || isDragging {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 0.5)
                        .offset(x: max(0, min(width - 8, width * CGFloat(progress) - 4)))
                }
            }
            .frame(height: geo.size.height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let clampedX = max(0, min(value.location.x, width))
                        let pct = width > 0 ? (clampedX / width) : 0
                        dragValue = pct * duration
                    }
                    .onEnded { value in
                        let clampedX = max(0, min(value.location.x, width))
                        let pct = width > 0 ? (clampedX / width) : 0
                        let finalTime = pct * duration
                        dragValue = finalTime
                        onSeek(finalTime)
                        isDragging = false
                    }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }
}

private struct BarWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 800
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
