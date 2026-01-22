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

enum ThumbnailError: Error {
    case invalidSource
    case generationFailed
}

/// macOS Tahoe Optimized Thumbnail Generator
actor SonyThumbnailProvider {
    static let shared = SonyThumbnailProvider()

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
            let image = try await extractSonyThumbnail(
                from: url,
                maxDimension: CGFloat(targetSize)
            )
            cache.setObject(image, forKey: nsUrl)
            return image
        } catch let err {
            Logger.process.debugMessageOnly("SonyThumbnailProvider: thumbnail() failed with error: \(err)")
            return nil
        }
    }

    /// Preloads thumbnails for all .ARW files in a catalog directory
    /// - Parameters:
    ///   - catalogURL: The directory URL containing .ARW files
    ///   - targetSize: The target size for thumbnails
    ///   - recursive: Whether to search subdirectories (default: true)
    /// - Returns: The number of thumbnails successfully cached
    @discardableResult
    func preloadCatalog(at catalogURL: URL, targetSize: Int, recursive: Bool = true) async -> Int {
        Logger.process.debugThreadOnly("SonyThumbnailProvider: preloadCatalog()")

        // Collect URLs synchronously first
        let arwURLs = await Task.detached {
            let fileManager = FileManager.default
            var urls: [URL] = []

            guard let enumerator = fileManager.enumerator(
                at: catalogURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: recursive ? [] : [.skipsSubdirectoryDescendants]
            ) else {
                return urls
            }

            // Use nextObject() instead of for-in to avoid makeIterator() in async context
            while let fileURL = enumerator.nextObject() as? URL {
                // Filter for .ARW files
                guard fileURL.pathExtension.lowercased() == "arw" else { continue }

                // Check if it's a regular file
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      let isRegularFile = resourceValues.isRegularFile,
                      isRegularFile
                else {
                    continue
                }

                urls.append(fileURL)
            }

            return urls
        }.value

        guard !arwURLs.isEmpty else {
            Logger.process.debugMessageOnly("SonyThumbnailProvider: No ARW files found in \(catalogURL.path)")
            return 0
        }

        // Process thumbnails asynchronously
        var successCount = 0
        for fileURL in arwURLs {
            do {
                let nsimage = try await extractSonyThumbnail(from: fileURL, maxDimension: CGFloat(targetSize))
                cache.setObject(nsimage, forKey: fileURL as NSURL)
                successCount += 1
                print(successCount)
            } catch {}
        }

        Logger.process.debugMessageOnly("SonyThumbnailProvider: Preloaded \(successCount) thumbnails from \(catalogURL.path)")
        return successCount
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

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            ) else {
                throw ThumbnailError.generationFailed
            }

            // Create NSImage from the generated CGImage
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            return NSImage(cgImage: cgImage, size: size)
        }.value
    }
}
