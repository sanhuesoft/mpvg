//
//  ConnectionOverlayView.swift
//  mpvg
//
//  Floating overlay displayed when connection to the Navidrome/Subsonic server
//  fails, providing quick actions to refresh/reconnect or edit server settings.
//

import SwiftUI

struct ConnectionOverlayView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        ZStack {
            // Dimmed blur backdrop
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    // Optional: tap outside does not dismiss to prevent accidental close,
                    // or allows dismissal if offline browsing is desired
                }
            
            // Floating Card
            VStack(spacing: 22) {
                // Top Icon Badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorTheme.amberBg, ColorTheme.terracottaLight.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                    
                    Circle()
                        .stroke(ColorTheme.amber.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 68, height: 68)
                    
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(ColorTheme.terracotta)
                }
                .padding(.top, 6)
                
                // Header & Message
                VStack(spacing: 8) {
                    Text(LocalizedStringKey("No Connection to Server"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(LocalizedStringKey("Could not establish connection to the music server. Check your settings or network status."))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(ColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
                
                // Status Detail Pill
                if !viewModel.serverConfig.urlString.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ColorTheme.amber)
                            .frame(width: 6, height: 6)
                        
                        Text(viewModel.serverConfig.cleanURL?.absoluteString ?? viewModel.serverConfig.urlString)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(ColorTheme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ColorTheme.cardBorder.opacity(0.5))
                    .cornerRadius(14)
                }
                
                Divider()
                    .background(ColorTheme.cardBorder)
                    .padding(.horizontal, 4)
                
                // Action Buttons
                VStack(spacing: 10) {
                    // Refresh / Reconnect Button
                    Button(action: {
                        Task {
                            await viewModel.testConnection()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isTestingConnection {
                                ProgressView()
                                    #if os(macOS)
                                    .scaleEffect(0.6)
                                    #else
                                    .scaleEffect(0.8)
                                    #endif
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            
                            Text(LocalizedStringKey("Retry Connection"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(ColorTheme.terracotta)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isTestingConnection)
                    
                    // Edit Connection Settings Button
                    Button(action: {
                        viewModel.openSettings()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                            Text(LocalizedStringKey("Edit Connection"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(ColorTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(ColorTheme.cardBorderHover, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Continue Offline / Dismiss
                    Button(action: {
                        viewModel.dismissDisconnectedOverlay()
                    }) {
                        Text(LocalizedStringKey("Continue Offline"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ColorTheme.textTertiary)
                            .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ColorTheme.cardBackground)
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ColorTheme.cardBorder, lineWidth: 1)
            )
            .padding(20)
        }
    }
}
