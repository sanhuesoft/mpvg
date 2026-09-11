//
//  SmartPlaylistDetailView.swift
//  mpvg
//
//  Detail view for pre-built / smart playlists (Unplayed, Forgotten Favorites,
//  Top Tracks, Starred, Discovery Mix).
//

import SwiftUI

struct SmartPlaylistDetailView: View {
    let type: SmartPlaylistType
    @ObservedObject var viewModel: PlayerViewModel
    
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
    #else
    private var isCompact: Bool { false }
    #endif
    
    private var songs: [SongItem] {
        viewModel.smartPlaylistSongs[type] ?? []
    }
    
    private var isLoading: Bool {
        viewModel.isLoadingSmartPlaylist[type] ?? false
    }
    
    private var totalDurationFormatted: String {
        let total = songs.reduce(0.0) { $0 + ($1.duration ?? 0.0) }
        guard total > 0 else { return "" }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours) h \(minutes) min"
        } else {
            return "\(minutes) min"
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                heroHeaderView
                    .padding(.horizontal, isCompact ? 18 : 28)
                    .padding(.top, isCompact ? 14 : 22)
                    .padding(.bottom, isCompact ? 18 : 24)
                
                Divider()
                    .background(ColorTheme.cardBorder)
                    .padding(.horizontal, isCompact ? 18 : 28)
                
                tracklistSection
                    .padding(.horizontal, isCompact ? 16 : 28)
                    .padding(.top, 16)
                    .padding(.bottom, 90)
            }
        }
        .background(ColorTheme.windowBackground)
        .navigationTitle(type.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if songs.isEmpty {
                await viewModel.loadSmartPlaylist(type)
            }
        }
    }
    
    // MARK: - Hero Header View
    @ViewBuilder
    private var heroHeaderView: some View {
        if isCompact {
            compactHeroHeaderView
        } else {
            desktopHeroHeaderView
        }
    }
    
    // MARK: - Compact Header (iOS)
    private var compactHeroHeaderView: some View {
        VStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: type.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .shadow(color: type.gradientColors.first?.opacity(0.35) ?? Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                
                Image(systemName: type.iconName)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .center, spacing: 5) {
                Text("LISTA INTELIGENTE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(ColorTheme.terracotta)
                    .tracking(1.2)
                
                Text(type.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(type.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(ColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("\(songs.count) \(songs.count == 1 ? "canción" : "canciones")")
                    if !totalDurationFormatted.isEmpty {
                        Text("•")
                        Text(totalDurationFormatted)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorTheme.textTertiary)
                .padding(.top, 2)
            }
            
            actionButtons
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Desktop Header (macOS)
    private var desktopHeroHeaderView: some View {
        HStack(alignment: .bottom, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: type.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: type.gradientColors.first?.opacity(0.3) ?? Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                
                Image(systemName: type.iconName)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("LISTA INTELIGENTE")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(ColorTheme.terracotta)
                    .tracking(1.2)
                
                Text(type.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text(type.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
                
                HStack(spacing: 8) {
                    Text("\(songs.count) \(songs.count == 1 ? "canción" : "canciones")")
                    if !totalDurationFormatted.isEmpty {
                        Text("•")
                        Text(totalDurationFormatted)
                    }
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(ColorTheme.textTertiary)
                
                actionButtons
                    .padding(.top, 6)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Play All
            Button(action: {
                viewModel.playSmartPlaylist(type, startingAt: 0, shuffle: false)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Reproducir Todo")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ColorTheme.terracotta)
                .cornerRadius(9)
                .shadow(color: ColorTheme.terracotta.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(songs.isEmpty)
            .opacity(songs.isEmpty ? 0.6 : 1.0)
            
            // Shuffle
            Button(action: {
                viewModel.playSmartPlaylist(type, startingAt: 0, shuffle: true)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Aleatorio")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(ColorTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ColorTheme.inputBackground)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(ColorTheme.cardBorder, lineWidth: 1))
                .cornerRadius(9)
            }
            .buttonStyle(.plain)
            .disabled(songs.isEmpty)
            .opacity(songs.isEmpty ? 0.6 : 1.0)
            
            // Refresh / Regenerate
            if type.canRegenerate {
                Button(action: {
                    Task {
                        await viewModel.loadSmartPlaylist(type, forceRefresh: true)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                            .animation(isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                        Text("Regenerar")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(ColorTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ColorTheme.inputBackground)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(ColorTheme.cardBorder, lineWidth: 1))
                    .cornerRadius(9)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
    }
    
    // MARK: - Tracklist Section
    @ViewBuilder
    private var tracklistSection: some View {
        if isLoading && songs.isEmpty {
            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.1)
                Text("Cargando lista inteligente...")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else if songs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(ColorTheme.textTertiary.opacity(0.6))
                    .padding(.top, 20)
                Text("No hay canciones disponibles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                Text("Vuelve a intentarlo o sincroniza tu biblioteca con el servidor.")
                    .font(.system(size: 13))
                    .foregroundColor(ColorTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Table Columns Header
                HStack(spacing: 12) {
                    Text("#")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                        .frame(width: 24, alignment: .center)
                    
                    Text("TÍTULO")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Spacer()
                    
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ColorTheme.textTertiary)
                        .padding(.trailing, 14)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                
                Divider()
                    .background(ColorTheme.cardBorder.opacity(0.6))
                    .padding(.bottom, 2)
                
                // Track Rows
                LazyVStack(spacing: 2) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        SongRowView(
                            song: song,
                            isPlaying: viewModel.currentSong?.id == song.id,
                            viewModel: viewModel,
                            onRate: { rating in
                                viewModel.rateSong(song, rating: rating)
                            },
                            onPlay: {
                                viewModel.playSmartPlaylist(type, startingAt: index, shuffle: false)
                            }
                        )
                    }
                }
            }
        }
    }
}
