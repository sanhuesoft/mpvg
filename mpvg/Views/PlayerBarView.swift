//
//  PlayerBarView.swift
//  mpvg
//
//  Bottom player and status bar matching CaskHub's terminal/status bar aesthetic.
//  Includes live track info, controls, seek scrubber, and CoreAudio Exclusive Mode indicator.
//

import SwiftUI

struct PlayerBarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isDraggingSlider: Bool = false
    @State private var dragValue: Double = 0.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Server Status & Library Info (CaskHub terminal style)
            HStack(spacing: 8) {
                // Server status dot
                Circle()
                    .fill(viewModel.isConnected ? ColorTheme.sageGreen : ColorTheme.amber)
                    .frame(width: 7, height: 7)
                
                HStack(spacing: 6) {
                    Text(viewModel.isConnected ? "navidrome: connected" : "navidrome: demo mode")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Text("\(viewModel.albums.count) albums")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
            .frame(minWidth: 220, alignment: .leading)
            
            Spacer(minLength: 8)
            
            // Center: Playback Controls & Track Scrubber
            HStack(spacing: 14) {
                // Mini Playback Controls
                HStack(spacing: 10) {
                    Button(action: { viewModel.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: viewModel.mpv.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ColorTheme.terracotta)
                            .frame(width: 26, height: 26)
                            .background(ColorTheme.terracottaLight.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Button(action: { viewModel.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Track Info & Progress Bar
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(viewModel.currentSong?.title ?? "No track playing")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .lineLimit(1)
                        
                        if let artist = viewModel.currentSong?.displayArtist {
                            Text("—  \(artist)")
                                .font(.system(size: 11))
                                .foregroundColor(ColorTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Scrubber
                    HStack(spacing: 8) {
                        Text(formatTime(isDraggingSlider ? dragValue : viewModel.mpv.currentTime))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                            .frame(width: 32, alignment: .leading)
                        
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
                        .frame(width: 140)
                        
                        Text(formatTime(viewModel.mpv.duration))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textTertiary)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Right: CoreAudio Exclusive Mode & Volume
            HStack(spacing: 12) {
                // Exclusive Audio Badge / Warning
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
                    HStack(spacing: 5) {
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
                        } else if !viewModel.mpv.preferredDeviceName.isEmpty && viewModel.mpv.isDeviceConnected {
                            Text("• \(viewModel.mpv.preferredDeviceName)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(ColorTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(viewModel.mpv.isExclusive ? ColorTheme.terracottaLight : ColorTheme.cardBorder.opacity(0.4))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                
                // Volume Slider
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
                    .accentColor(ColorTheme.textSecondary)
                    .frame(width: 65)
                }
            }
            .frame(minWidth: 220, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(ColorTheme.bottomBarBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ColorTheme.bottomBarBorder),
            alignment: .top
        )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let min = total / 60
        let sec = total % 60
        return String(format: "%02d:%02d", min, sec)
    }
}
