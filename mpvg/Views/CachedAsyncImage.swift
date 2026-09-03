//
//  CachedAsyncImage.swift
//  mpvg
//
//  High-performance image loader with in-memory NSCache and URLCache.
//  Prevents flickering, reloading, and redundant network requests.
//

import SwiftUI
import AppKit

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSURL, NSImage>()
    
    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 1024 * 1024 * 256 // 256 MB
        
        // Increase system URLCache capacity
        URLCache.shared.memoryCapacity = 1024 * 1024 * 64 // 64 MB
        URLCache.shared.diskCapacity = 1024 * 1024 * 512   // 512 MB
    }
    
    func image(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func setImage(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var loadedImage: NSImage?
    
    var body: some View {
        Group {
            if let img = loadedImage {
                Image(nsImage: img)
                    .resizable()
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        
        // Check memory cache first
        if let cached = ImageCacheManager.shared.image(for: url) {
            self.loadedImage = cached
            return
        }
        
        // Download image
        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
               let nsImage = NSImage(data: data) {
                ImageCacheManager.shared.setImage(nsImage, for: url)
                self.loadedImage = nsImage
            }
        } catch {
            // Silently handle cancelled requests
        }
    }
}
