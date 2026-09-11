//
//  QueueView.swift
//  mpvg
//
//  Playing Queue (Cola de Reproducción) view.
//  Displays Now Playing track and upcoming tracks (Up Next) with options
//  to jump to tracks, reorder, remove, or clear the queue.
//

import SwiftUI
import UniformTypeIdentifiers

struct QueueView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draggingIndex: Int? = nil
    
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
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(ColorTheme.terracottaLight.opacity(0.45))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(ColorTheme.terracotta.opacity(0.35), lineWidth: 0.8)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(.horizontal, 12)
                            .contextMenu {
                                if !current.displayArtist.isEmpty && current.displayArtist != "Unknown Artist" {
                                    Button {
                                        viewModel.navigateToArtist(for: current)
                                        viewModel.showQueueSheet = false
                                    } label: {
                                        Label("Ver artista", systemImage: "music.mic")
                                    }
                                }
                                
                                if !current.displayAlbum.isEmpty && current.displayAlbum != "Unknown Album" {
                                    Button {
                                        viewModel.navigateToAlbum(for: current)
                                        viewModel.showQueueSheet = false
                                    } label: {
                                        Label("Ver álbum", systemImage: "square.stack")
                                    }
                                }
                            }
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
                                    .opacity(draggingIndex == idx ? 0.6 : 1.0)
                                    .onDrag {
                                        self.draggingIndex = idx
                                        return NSItemProvider(object: "\(idx)" as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: QueueDropDelegate(
                                        targetIndex: idx,
                                        draggingIndex: $draggingIndex,
                                        viewModel: viewModel
                                    ))
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        #if os(macOS)
        .frame(width: 380, height: 480)
        .background(.ultraThinMaterial)
        .background(ColorTheme.windowBackground.opacity(0.7))
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTheme.windowBackground)
        #endif
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
                
                // Drag Handle for Reordering
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorTheme.textTertiary)
                    .frame(width: 18, height: 20)
                    .contentShape(Rectangle())
                    .help(LocalizedStringKey("Arrastra para reordenar"))
                
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
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ColorTheme.cardBackground.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ColorTheme.cardBorder.opacity(0.7), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                viewModel.playQueueItem(at: index)
            } label: {
                Label("Reproducir ahora", systemImage: "play.fill")
            }
            
            Divider()
            
            // Queue Reordering Options
            if index > viewModel.queueIndex + 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.moveUpcomingQueueItemToTop(at: index)
                    }
                } label: {
                    Label(LocalizedStringKey("Mover al inicio de la cola"), systemImage: "arrow.up.to.line")
                }
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.moveUpcomingQueueItem(at: index, direction: -1)
                    }
                } label: {
                    Label(LocalizedStringKey("Subir"), systemImage: "arrow.up")
                }
            }
            
            if index < viewModel.queue.count - 1 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.moveUpcomingQueueItem(at: index, direction: 1)
                    }
                } label: {
                    Label(LocalizedStringKey("Bajar"), systemImage: "arrow.down")
                }
            }
            
            Divider()
            
            Button {
                viewModel.playNext(song)
                viewModel.showToast("\"\(song.title)\" añadida a continuación")
            } label: {
                Label("Añadir a continuación", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            
            Divider()
            
            if !song.displayArtist.isEmpty && song.displayArtist != "Unknown Artist" {
                Button {
                    viewModel.navigateToArtist(for: song)
                    viewModel.showQueueSheet = false
                } label: {
                    Label("Ver artista", systemImage: "music.mic")
                }
            }
            
            if !song.displayAlbum.isEmpty && song.displayAlbum != "Unknown Album" {
                Button {
                    viewModel.navigateToAlbum(for: song)
                    viewModel.showQueueSheet = false
                } label: {
                    Label("Ver álbum", systemImage: "square.stack")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                withAnimation {
                    viewModel.removeFromQueue(at: index)
                }
            } label: {
                Label("Eliminar de la cola", systemImage: "trash")
            }
        }
    }
    
    private func formatDuration(_ seconds: Double?) -> String {
        guard let sec = seconds, !sec.isNaN && sec >= 0 else { return "0:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Queue Drop Delegate for Reordering
struct QueueDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggingIndex: Int?
    let viewModel: PlayerViewModel
    
    func dropEntered(info: DropInfo) {
        guard let fromIndex = draggingIndex, fromIndex != targetIndex else { return }
        let minUpcoming = viewModel.queueIndex + 1
        guard fromIndex >= minUpcoming && targetIndex >= minUpcoming,
              fromIndex < viewModel.queue.count && targetIndex < viewModel.queue.count else { return }
        
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.moveQueueItem(from: fromIndex, to: targetIndex)
            self.draggingIndex = targetIndex
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingIndex = nil
        return true
    }
    
    func dropExited(info: DropInfo) {
    }
}

