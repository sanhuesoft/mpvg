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
            let key = ArtworkCacheManager.shared.cacheKey(for: url)
            if let cached = ArtworkCacheManager.shared.imageFromMemory(for: key) {
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
            
            // 1. Check Memory or Disk Cache via ArtworkCacheManager
            if let cached = await ArtworkCacheManager.shared.image(for: targetURL) {
                self.loadedImage = cached
                return
            }
            
            // 2. Fetch from Network if not cached
            self.loadedImage = nil
            await loadImage(for: targetURL)
        }
    }
    
    private func loadImage(for targetURL: URL) async {
        do {
            let request = URLRequest(url: targetURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return }
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let img = PlatformImage(data: data) {
                ArtworkCacheManager.shared.storeImage(img, for: targetURL, rawData: data)
                if self.url == targetURL {
                    self.loadedImage = img
                }
            }
        } catch {
            // Silently handle cancelled or offline network requests
        }
    }
}
