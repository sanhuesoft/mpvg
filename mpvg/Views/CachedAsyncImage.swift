//
//  CachedAsyncImage.swift
//  mpvg
//
//  High-performance image loader with in-memory NSCache and URLCache.
//  Multiplatform support for macOS, iOS, and iPadOS.
//

import SwiftUI

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cache = NSCache<NSURL, PlatformImage>()
    
    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 1024 * 1024 * 256 // 256 MB
        
        // Increase system URLCache capacity
        URLCache.shared.memoryCapacity = 1024 * 1024 * 64 // 64 MB
        URLCache.shared.diskCapacity = 1024 * 1024 * 512   // 512 MB
    }
    
    func image(for url: URL) -> PlatformImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func setImage(_ image: PlatformImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var loadedImage: PlatformImage?
    
    var body: some View {
        Group {
            if let img = loadedImage {
                Image(platformImage: img)
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
               let img = PlatformImage(data: data) {
                ImageCacheManager.shared.setImage(img, for: url)
                self.loadedImage = img
            }
        } catch {
            // Silently handle cancelled requests
        }
    }
}
