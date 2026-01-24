//
//  DiskCacheManager.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 23/01/2026.
//

import AppKit
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

actor DiskCacheManager {
    let cacheDirectory: URL

    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let folder = paths[0].appendingPathComponent("no.blogspot.PhotoCulling/Thumbnails")
        cacheDirectory = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func cacheURL(for sourceURL: URL) -> URL {
        // Standardize the URL to ensure consistent hashing
        let standardizedPath = sourceURL.standardized.path
        // Use MD5 for a stable, deterministic hash
        let data = Data(standardizedPath.utf8)
        let digest = Insecure.MD5.hash(data: data)
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(hash).appendingPathExtension("jpg")
    }

    func load(for sourceURL: URL) -> NSImage? {
        let fileURL = cacheURL(for: sourceURL)
        // Use ImageIO to read for better control, or stick to NSImage for simplicity
        // NSImage(contentsOf:) is generally efficient for reading JPEGs
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    func save(_ image: NSImage, for sourceURL: URL) {
        let fileURL = cacheURL(for: sourceURL)
        // 1. Get the underlying CGImage
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        // 2. Create a destination for the file
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return
        }

        // 3. Set compression properties (0.7 is a good balance for thumbnails)
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.7
        ]

        // 4. Write directly to disk
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(destination)
    }

    func pruneCache(maxAgeInDays: Int = 30) {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]

        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: .skipsHiddenFiles
        ) else { return }

        let expirationDate = Calendar.current.date(byAdding: .day, value: -maxAgeInDays, to: Date())!

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if let date = values.contentModificationDate, date < expirationDate {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                // Log error
            }
        }
    }
}
