//
//  mpvgApp.swift
//  mpvg
//
//  Created by Fabián Sanhueza on 30-08-26.
//

import SwiftUI
import Darwin

@main
struct mpvgApp: App {
    init() {
        signal(SIGPIPE, SIG_IGN)
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
