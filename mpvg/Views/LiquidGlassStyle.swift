//
//  LiquidGlassStyle.swift
//  mpvg
//
//  Authentic Apple Liquid Glass styling system inspired by macOS Sonoma / Sequoia & Apple Music.
//  Provides hyper-realistic optical properties:
//  - Multi-pass backdrop blur via system materials (.fullScreenUI on AppKit / .ultraThinMaterial on SwiftUI)
//  - Luminous gradient translucent tint (preventing milky/chalky opacity)
//  - Curved specular reflection (upper lens sheen)
//  - Sub-pixel refractive rim border (specular zenith highlight fading to subtle keyline)
//  - Inner micro-bevel for perceived 3D glass thickness
//  - Dual-depth ambient and contact shadows
//

import SwiftUI

#if os(macOS)
import AppKit

public struct SystemGlassMaterialView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    
    public init(material: NSVisualEffectView.Material = .fullScreenUI, blendingMode: NSVisualEffectView.BlendingMode = .withinWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
#endif

// MARK: - Capsule Liquid Glass (Now Playing Bar)

public struct LiquidGlassCapsuleBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 1. Native system glass blur
            #if os(macOS)
            SystemGlassMaterialView(material: .fullScreenUI, blendingMode: .withinWindow)
                .clipShape(Capsule())
            #else
            Capsule()
                .fill(.ultraThinMaterial)
            #endif
            
            // 2. Translucent liquid tint (high vibrancy, NOT milky)
            Capsule()
                .fill(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28), location: 0.0),
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10), location: 0.60),
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.06 : 0.18), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // 3. Curved specular highlight (top half lens reflection)
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.16 : 0.40), location: 0.0),
                        Gradient.Stop(color: Color.white.opacity(0.0), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                
                Spacer(minLength: 0)
            }
            .clipShape(Capsule())
        }
    }
}

public struct LiquidGlassCapsuleOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Outer Specular Rim (Zenith light fading to bottom rim)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.35 : 0.90), location: 0.0),
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.15 : 0.35), location: 0.35),
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.10), location: 0.75),
                            Gradient.Stop(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            
            // Inner micro-bevel refraction
            Capsule()
                .inset(by: 0.75)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.20 : 0.45), location: 0.0),
                            Gradient.Stop(color: Color.clear, location: 0.50)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

// MARK: - Rounded Liquid Glass (Header Buttons, Docks, Controls)

public struct LiquidGlassRoundedBackground: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    public init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        ZStack {
            #if os(macOS)
            SystemGlassMaterialView(material: .fullScreenUI, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            #else
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            #endif
            
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.10 : 0.32), location: 0.0),
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12), location: 0.70),
                            Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.07 : 0.20), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.18 : 0.45), location: 0.0),
                        Gradient.Stop(color: Color.white.opacity(0.0), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)
                
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

public struct LiquidGlassRoundedOverlay: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    public init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.35 : 0.85), location: 0.0),
                        Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.15 : 0.30), location: 0.40),
                        Gradient.Stop(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.10), location: 0.70),
                        Gradient.Stop(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.06), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.75
            )
    }
}

// MARK: - View Modifiers

public extension View {
    /// Applies authentic Apple Music liquid glass capsule styling
    func liquidGlassCapsule() -> some View {
        self
            .background(LiquidGlassCapsuleBackground())
            .overlay(LiquidGlassCapsuleOverlay())
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 7)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    /// Applies authentic Apple liquid glass styling with custom corner radius
    func liquidGlassRounded(cornerRadius: CGFloat = 8) -> some View {
        self
            .background(LiquidGlassRoundedBackground(cornerRadius: cornerRadius))
            .overlay(LiquidGlassRoundedOverlay(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1.5)
    }
}
