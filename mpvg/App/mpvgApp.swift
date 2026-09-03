//
//  mpvgApp.swift
//  mpvg
//
//  Created by Fabián Sanhueza on 30-08-26.
//

import SwiftUI
import Darwin
#if os(macOS)
import AppKit
#endif

@main
struct mpvgApp: App {
    init() {
        signal(SIGPIPE, SIG_IGN)
        #if os(macOS)
        // Explicitly set the Dock icon on launch to ensure immediate rendering
        if let iconImage = NSImage(named: "AppIcon") ?? Bundle.main.path(forResource: "AppIcon", ofType: "icns").flatMap({ NSImage(contentsOfFile: $0) }) {
            NSApplication.shared.applicationIconImage = iconImage
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.light)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 740)
        #endif
    }
}
