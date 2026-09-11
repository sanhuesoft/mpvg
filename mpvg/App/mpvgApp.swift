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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Broadcast termination to ensure audio engine terminates immediately
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: nil)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window: window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configure(window: window)
            }
        }
    }
    
    private func configure(window: NSWindow) {
        let minSize = NSSize(width: 960, height: 620)
        window.minSize = minSize
        
        var frame = window.frame
        var needsResize = false
        if frame.size.width < minSize.width {
            frame.size.width = minSize.width
            needsResize = true
        }
        if frame.size.height < minSize.height {
            frame.size.height = minSize.height
            needsResize = true
        }
        if needsResize {
            window.setFrame(frame, display: true, animate: false)
        }
    }
}
#endif

@main
struct mpvgApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
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
                #if os(macOS)
                .frame(minWidth: 960, maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
                .background(WindowConfigurator())
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1120, height: 740)
        #endif
    }
}
