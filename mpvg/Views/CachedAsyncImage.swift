//
//  CachedAsyncImage.swift
//  mpvg
//
//  High-performance asynchronous image loader powered by ArtworkCacheManager
//  (In-memory NSCache + Persistent disk cache).
//  Multiplatform support for macOS, iOS, and iPadOS.
//

import SwiftUI

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var loadedImage: PlatformImage?
    
    init(url: URL?, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
        if let url = url {
            if let cached = ArtworkCacheManager.shared.syncImage(for: url) {
                self._loadedImage = State(initialValue: cached)
            } else {
                self._loadedImage = State(initialValue: nil)
            }
        } else {
            self._loadedImage = State(initialValue: nil)
        }
    }
    
    var body: some View {
        Group {
            if let img = loadedImage {
                Image(platformImage: img)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let targetURL = url else {
                self.loadedImage = nil
                return
            }
            
            // Check synchronous memory / fast disk cache first for instant render
            if let cached = ArtworkCacheManager.shared.syncImage(for: targetURL) {
                self.loadedImage = cached
                return
            }
            
            // Clear previous image so stale artwork is never shown while loading
            self.loadedImage = nil
            
            // Load from cache or fetch via deduplicated network loader
            if let img = await ArtworkCacheManager.shared.loadImage(for: targetURL) {
                if self.url == targetURL {
                    self.loadedImage = img
                }
            }
        }
    }
}
