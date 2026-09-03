//
//  MainView.swift
//  mpvg
//
//  Created by Fabián Sanhueza on 30-08-26.
//


import SwiftUI

struct MainView: View {
    @StateObject private var mpv = MPVProcessManager()
    @State private var tracks: [Track] = []
    @State private var currentTrack: Track?
    @State private var isPaused: Bool = false
    
    var body: some View {
        NavigationSplitView {
            List {
                Section("Biblioteca") {
                    Label("Todas las canciones", systemImage: "music.note.list")
                }
            }
            .listStyle(.sidebar)
        } detail: {
            VStack(spacing: 0) {
                // Lista de canciones
                Table(tracks) {
                    TableColumn("Título") { track in
                        Text(track.title)
                            .fontWeight(currentTrack == track ? .bold : .regular)
                            .foregroundColor(currentTrack == track ? .accentColor : .primary)
                    }
                    TableColumn("Artista", value: \.artist)
                    TableColumn("Álbum", value: \.album)
                    TableColumn("Formato") { track in
                        Text(track.url.pathExtension.uppercased())
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .contextMenu(forSelectionType: Track.ID.self) { items in
                    // Menú contextual si se necesita
                } primaryAction: { selection in
                    if let selectedID = selection.first,
                       let track = tracks.first(where: { $0.id == selectedID }) {
                        play(track: track)
                    }
                }
                
                Divider()
                
                // Barra de control inferior
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(currentTrack?.title ?? "Sin reproducción")
                            .font(.headline)
                        Text(currentTrack?.artist ?? "—")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: togglePause) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .task {
            mpv.start()
            // Ruta a tu carpeta de música
            let musicURL = URL(fileURLWithPath: "/Volumes/bacteria/music")
            tracks = await LibraryScanner.scanDirectory(at: musicURL)
        }
        .onDisappear {
            mpv.stop()
        }
    }
    
    private func play(track: Track) {
        currentTrack = track
        isPaused = false
        mpv.sendCommand(["loadfile", track.url.path, "replace"])
    }
    
    private func togglePause() {
        isPaused.toggle()
        mpv.sendCommand(["cycle", "pause"])
    }
}