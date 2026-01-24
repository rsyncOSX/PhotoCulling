import AppKit
import CryptoKit // Required for Insecure.MD5
import Foundation
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

    func load(for sourceURL: URL) async -> NSImage? {
        let fileURL = cacheURL(for: sourceURL)

        // 1. Read Data off the actor to prevent blocking
        let data = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: fileURL)
        }.value

        guard let data else { return nil }

        // 2. Create NSImage inside the actor (safe)
        return NSImage(data: data)
    }

    func save(_ cgImage: CGImage, for sourceURL: URL) async {
        // 1. Perform the heavy IO and JPEG compression off the actor
        await Task.detached(priority: .background) { [cacheDirectory = self.cacheDirectory] in
            // We need a local copy of cacheURL logic or capture self properly.
            // Since self is an actor, we can't capture it synchronously in the detached closure
            // unless we calculate the path outside or await.
            // Ideally, calculate path before detaching, or do the work inside a nonisolated func.
            // For simplicity here, we just reconstruct the path logic or call a helper.
            try? Self.performSave(cgImage: cgImage, for: sourceURL, cacheDir: cacheDirectory)
        }.value
    }

    // Helper to keep the detached closure clean and non-isolated
    private nonisolated static func performSave(cgImage: CGImage, for sourceURL: URL, cacheDir: URL) throws {
        // Reconstruct path (or refactor this to take the URL directly)
        let standardizedPath = sourceURL.standardized.path
        let data = Data(standardizedPath.utf8)
        let digest = Insecure.MD5.hash(data: data)
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        let fileURL = cacheDir.appendingPathComponent(hash).appendingPathExtension("jpg")

        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ThumbnailError.generationFailed // Or a specific disk error
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.7
        ]

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw ThumbnailError.generationFailed
        }
    }

    func pruneCache(maxAgeInDays: Int = 30) async {
        // Offload IO to background task
        await Task.detached(priority: .utility) { [cacheDirectory = self.cacheDirectory] in
            let fileManager = FileManager.default
            let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .totalFileAllocatedSizeKey]

            // 1. Get all files at once into an Array.
            // Arrays are safe to iterate in Swift 6 async contexts.
            guard let urls = try? fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: resourceKeys,
                options: .skipsHiddenFiles
            ) else { return }

            let expirationDate = Calendar.current.date(byAdding: .day, value: -maxAgeInDays, to: Date())!

            // 2. Iterate over the array of URLs
            for fileURL in urls {
                do {
                    let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                    if let date = values.contentModificationDate, date < expirationDate {
                        try fileManager.removeItem(at: fileURL)
                    }
                } catch {
                    // Log error if needed, e.g., print("Failed to delete \(fileURL): \(error)")
                }
            }
        }.value
    }
}
