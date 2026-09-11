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

#if os(macOS)
import AppKit

struct PointingHandCursorHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> PointingHandNSView {
        let view = PointingHandNSView()
        return view
    }
    
    func updateNSView(_ nsView: PointingHandNSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.invalidateCursorRects(for: nsView)
        }
    }
}

final class PointingHandNSView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
#endif

#if os(macOS)
struct PointingHandAndHoverModifier: ViewModifier {
    var scale: CGFloat = 1.025
    var brightness: Double = 0.035
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .overlay(PointingHandCursorHelper().allowsHitTesting(false))
            .scaleEffect(isHovered ? scale : 1.0)
            .brightness(isHovered ? brightness : 0.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}
#endif

// MARK: - Pointing Hand Cursor & Interactive Hover Extension
extension View {
    func pointingHandOnHover(scale: CGFloat = 1.025, brightness: Double = 0.035) -> some View {
        #if os(macOS)
        self.modifier(PointingHandAndHoverModifier(scale: scale, brightness: brightness))
        #else
        self
        #endif
    }
}

