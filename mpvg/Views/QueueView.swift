//
//  QueueView.swift
//  mpvg
//
//  Playing Queue (Cola de Reproducción) view.
//  Displays Now Playing track and upcoming tracks (Up Next) with options
//  to jump to tracks, reorder, remove, or clear the queue.
//

import SwiftUI

struct QueueView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Playing Queue")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("\(viewModel.queue.count) tracks in queue")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                
                Spacer()
                
                if viewModel.queue.count > 1 {
                    Button(action: {
                        withAnimation {
                            viewModel.clearQueue()
                        }
                    }) {
                        Text("Clear Queue")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorTheme.terracotta)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTheme.terracottaLight.opacity(0.5))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider().background(ColorTheme.cardBorder)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    // NOW PLAYING SECTION
                    if let current = viewModel.currentSong {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOW PLAYING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ColorTheme.textTertiary)
                                .tracking(0.8)
                                .padding(.horizontal, 16)
                            
                            HStack(spacing: 12) {
                                let artURL: URL? = {
                                    if let coverId = current.coverArt ?? viewModel.currentAlbum?.coverArt {
                                        return viewModel.coverArtURL(for: coverId)
                                    }
                                    return nil
                                }()
                                
                                CachedAsyncImage(url: artURL) {
                                    ZStack {
                                        ColorTheme.cardBorder.opacity(0.4)
                                        Image(systemName: "opticaldisc")
                                            .foregroundColor(ColorTheme.terracotta)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(current.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(ColorTheme.terracotta)
                                        .lineLimit(1)
                                    
                                    Text(current.displayArtist)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(ColorTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "waveform")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(ColorTheme.terracotta)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(ColorTheme.terracottaLight.opacity(0.4))
                            .cornerRadius(10)
                            .padding(.horizontal, 12)
                        }
                    }
                    
                    // UP NEXT SECTION
                    let upcomingIndices = (viewModel.queueIndex + 1)..<viewModel.queue.count
                    VStack(alignment: .leading, spacing: 6) {
                        Text("UP NEXT (\(upcomingIndices.count))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ColorTheme.textTertiary)
                            .tracking(0.8)
                            .padding(.horizontal, 16)
                        
                        if upcomingIndices.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 24))
                                    .foregroundColor(ColorTheme.textTertiary)
                                Text("End of queue")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ColorTheme.textSecondary)
                                Text("Playing an album will automatically queue all remaining tracks.")
                                    .font(.system(size: 11))
                                    .foregroundColor(ColorTheme.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .padding(.horizontal, 16)
                        } else {
                            ForEach(Array(upcomingIndices), id: \.self) { idx in
                                let song = viewModel.queue[idx]
                                queueRow(song: song, index: idx)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, minHeight: 380, idealHeight: 460)
        .background(ColorTheme.windowBackground)
    }
    
    // MARK: - Queue Row
    private func queueRow(song: SongItem, index: Int) -> some View {
        Button(action: {
            viewModel.playQueueItem(at: index)
        }) {
            HStack(spacing: 10) {
                Text("\(index - viewModel.queueIndex)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 20, alignment: .center)
                
                let artURL: URL? = {
                    if let coverId = song.coverArt ?? viewModel.currentAlbum?.coverArt {
                        return viewModel.coverArtURL(for: coverId)
                    }
                    return nil
                }()
                
                CachedAsyncImage(url: artURL) {
                    ZStack {
                        ColorTheme.cardBorder.opacity(0.3)
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
                .frame(width: 32, height: 32)
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text(song.displayArtist)
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(formatDuration(song.duration))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(ColorTheme.textTertiary)
                
                // Remove from queue button
                Button(action: {
                    withAnimation {
                        viewModel.removeFromQueue(at: index)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(ColorTheme.cardBackground.opacity(0.6))
            .cornerRadius(8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ seconds: Double?) -> String {
        guard let sec = seconds, !sec.isNaN && sec >= 0 else { return "0:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
