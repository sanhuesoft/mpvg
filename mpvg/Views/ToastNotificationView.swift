//
//  ToastNotificationView.swift
//  mpvg
//
//  Floating liquid glass toast notification banner for warnings, errors, and system status.
//

import SwiftUI

struct ToastNotificationView: View {
    let message: String
    var isError: Bool = true
    var onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isError ? ColorTheme.amber : ColorTheme.terracotta)
            
            Text(LocalizedStringKey(message))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorTheme.textPrimary)
                .lineLimit(2)
            
            Spacer(minLength: 8)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ColorTheme.textSecondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(toastBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isError ? ColorTheme.amber.opacity(0.4) : ColorTheme.cardBorder, lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    @ViewBuilder
    private var toastBackground: some View {
        #if os(macOS)
        VisualEffectView(material: .popover, blendingMode: .withinWindow)
            .background(ColorTheme.cardBackground.opacity(0.85))
        #else
        ColorTheme.cardBackground
        #endif
    }
}

// MARK: - Pointing Hand Cursor Extension
extension View {
    func pointingHandOnHover() -> some View {
        #if os(macOS)
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #else
        self
        #endif
    }
}
