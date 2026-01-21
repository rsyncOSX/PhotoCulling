//
//  ThumbnailCacheService.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 21/01/2026.
//
import Cocoa
import Foundation

actor ThumbnailCacheService {
    static let shared = ThumbnailCacheService()

    // NSCache works with classes, so we wrap URL in NSURL and use NSImage for macOS
    private let cache = NSCache<NSURL, NSImage>()

    func thumbnail(for url: URL, targetSize: Int) -> NSImage? {
        let nsUrl = url as NSURL

        // 1. Check Cache
        if let cached = cache.object(forKey: nsUrl) {
            return cached
        }

        // 2. Generate
        if let image = generateThumbnail(for: url, maxPixelSize: targetSize) {
            cache.setObject(image, forKey: nsUrl)
            return image
        }

        return nil
    }

    private func generateThumbnail(for url: URL, maxPixelSize: Int) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        else {
            return nil
        }

        // macOS uses NSImage, initializing from CGImage requires size
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        return nsImage
    }
}
