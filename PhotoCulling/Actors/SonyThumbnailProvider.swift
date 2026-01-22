//
//  SonyThumbnailProvider.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 22/01/2026.
//

import AppKit // Use AppKit for macOS, UIKit for iOS
import Foundation
import ImageIO
import OSLog

/// macOS Tahoe Optimized Thumbnail Generator
actor SonyThumbnailProvider {
    static let shared = SonyThumbnailProvider()

    enum ThumbnailError: Error {
        case invalidSource
        case generationFailed
    }

    // NSCache works with classes, so we wrap URL in NSURL and use NSImage for macOS
    private let cache = NSCache<NSURL, NSImage>()

    func thumbnail(for url: URL, targetSize: Int) async -> NSImage? {
        Logger.process.debugThreadOnly("SonyThumbnailProvider: thumbnail()")
        let nsUrl = url as NSURL

        // 1. Check Cache
        if let cached = cache.object(forKey: nsUrl) {
            return cached
        }
        // 2. Generate
        do {
            let image = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))
            cache.setObject(image, forKey: nsUrl)
        } catch let err {
            Logger.process.debugMessageOnly("SonyThumbnailProvider: thumbnail() failed with error: \(err)")
            return nil
        }
        return nil
    }

    /// Generates a thumbnail for a Sony .ARW file
    /// - Parameters:
    ///   - url: The file path to the .ARW file
    ///   - maxDimension: The maximum width or height of the thumbnail
    /// - Returns: An NSImage thumbnail
    private func extractSonyThumbnail(from url: URL, maxDimension: CGFloat) async throws -> NSImage {
        // Use a background task for the heavy decoding
        try await Task.detached(priority: .userInitiated) {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary

            guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
                throw ThumbnailError.invalidSource
            }

            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                // Ensure we use the embedded preview for speed (crucial for Tahoe performance)
                kCGImageSourceCreateThumbnailFromImageAlways: false
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
                throw ThumbnailError.generationFailed
            }

            // Create NSImage from the generated CGImage
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            return NSImage(cgImage: cgImage, size: size)
        }.value
    }
}
