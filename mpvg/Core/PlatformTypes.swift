//
//  PlatformTypes.swift
//  mpvg
//
//  Cross-platform type aliases and UI adapters for macOS, iOS, and iPadOS.
//

import SwiftUI

#if canImport(AppKit)
import AppKit

public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor

extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}

extension View {
    @ViewBuilder
    func platformCheckbox() -> some View {
        self.toggleStyle(.checkbox)
    }
    
    func hideKeyboard() {
        // No-op on macOS
    }
}

#elseif canImport(UIKit)
import UIKit

public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}

extension View {
    @ViewBuilder
    func platformCheckbox() -> some View {
        self.toggleStyle(.switch)
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#endif
