import AppKit
import Foundation
import ImageIO
import OSLog

// MARK: - Discardable Wrapper

final class DiscardableThumbnail: NSObject, NSDiscardableContent {
    let image: NSImage
    let cost: Int
    private var accessCount: Int = 0
    private var discarded: Bool = false

    init(image: NSImage) {
        self.image = image
        cost = Int(image.size.width * image.size.height * 4)
    }

    func beginContentAccess() -> Bool {
        if discarded { return false }
        accessCount += 1
        return true
    }

    func endContentAccess() {
        accessCount = max(0, accessCount - 1)
    }

    func discardContentIfPossible() {
        if accessCount == 0 {
            discarded = true
        }
    }

    func isContentDiscarded() -> Bool {
        discarded
    }
}

// MARK: - Thumbnail Provider Actor

actor ThumbnailProviderRefactor {
    nonisolated static let shared = ThumbnailProviderRefactor()

    var fileHandlers: FileHandlers?
    private let memoryCache = NSCache<NSURL, DiscardableThumbnail>()
    private let diskCache: DiskCacheManager

    private init() {
        // Initialize disk cache
        self.diskCache = DiskCacheManager()
        
        // Memory Cache Settings
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryLimit = min(Int(totalMemory / 10), 512 * 1024 * 1024)

        memoryCache.countLimit = 250
        memoryCache.totalCostLimit = memoryLimit
        memoryCache.name = "no.blogspot.PhotoCulling.imageCache"
        memoryCache.evictsObjectsWithDiscardedContent = true
    }

    func setFileHandlers(_ fileHandlers: FileHandlers) {
        self.fileHandlers = fileHandlers
    }

    // MARK: - Cache Management

    /// Completely clears the cache. Call this when switching catalogs.
    func clearCache() {
        Logger.process.debugMessageOnly("ThumbnailProvider: Clearing all cached thumbnails.")
        memoryCache.removeAllObjects()
    }

    /// Removes a specific thumbnail (e.g., if a file was deleted)
    func removeThumbnail(for url: URL) {
        memoryCache.removeObject(forKey: url as NSURL)
    }

    // MARK: - Core Logic

    func thumbnail(for url: URL, targetSize: Int) async -> NSImage? {
        let nsUrl = url as NSURL

        // 1. Check Memory Cache
        if let wrapper = memoryCache.object(forKey: nsUrl), await wrapper.beginContentAccess() {
            let img = wrapper.image
            await wrapper.endContentAccess()
            return img
        }

        // 2. Check Disk Cache
        if let diskImage = await diskCache.load(for: url) {
            // Put it back in memory cache for faster subsequent access
            let wrapper = await DiscardableThumbnail(image: diskImage)
            memoryCache.setObject(wrapper, forKey: nsUrl, cost: wrapper.cost)
            return diskImage
        }

        // 3. Generate from Scratch (Slowest)
        do {
            let image = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))

            // Save to both caches
            let wrapper = await DiscardableThumbnail(image: image)
            memoryCache.setObject(wrapper, forKey: nsUrl, cost: wrapper.cost)
            await diskCache.save(image, for: url) // NEW

            return image
        } catch {
            return nil
        }
    }

    @discardableResult
    func preloadCatalog(at catalogURL: URL, targetSize: Int, recursive: Bool = true) async -> Int {
        let arwURLs = await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            var urls: [URL] = []
            guard let enumerator = fileManager.enumerator(
                at: catalogURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: recursive ? [] : [.skipsSubdirectoryDescendants]
            ) else { return urls }

            let supported: Set<String> = ["arw", "tiff", "tif", "jpeg", "jpg", "png"]
            while let fileURL = enumerator.nextObject() as? URL {
                guard supported.contains(fileURL.pathExtension.lowercased()) else { continue }
                urls.append(fileURL)
            }
            return urls
        }.value

        await fileHandlers?.maxfilesHandler(arwURLs.count)

        var successCount = 0
        for fileURL in arwURLs {
            // Check if already in cache to avoid double-processing
            if memoryCache.object(forKey: fileURL as NSURL) != nil {
                successCount += 1
                continue
            }

            do {
                let img = try await extractSonyThumbnail(from: fileURL, maxDimension: CGFloat(targetSize))
                let wrapper = await DiscardableThumbnail(image: img)
                memoryCache.setObject(wrapper, forKey: fileURL as NSURL, cost: wrapper.cost)
                successCount += 1
                await fileHandlers?.fileHandler(successCount)
            } catch {}
        }
        return successCount
    }

    private func extractSonyThumbnail(from url: URL, maxDimension: CGFloat) async throws -> NSImage {
        try await Task.detached(priority: .userInitiated) {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
                throw ThumbnailError.invalidSource
            }

            let thumbOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceCreateThumbnailFromImageAlways: false
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
                throw ThumbnailError.generationFailed
            }

            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }.value
    }
}

// 1. Ensure the Disk Manager is Sendable (Safe to pass across actors)
struct DiskCacheManager: Sendable {
    let cacheDirectory: URL

    nonisolated init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let folder = paths[0].appendingPathComponent("no.blogspot.PhotoCulling/Thumbnails")
        cacheDirectory = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func save(_ image: NSImage, for sourceURL: URL) {
        let fileURL = cacheURL(for: sourceURL)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else { return }
        try? data.write(to: fileURL)
    }

    func load(for sourceURL: URL) -> NSImage? {
        let fileURL = cacheURL(for: sourceURL)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    private func cacheURL(for sourceURL: URL) -> URL {
        let hash = String(sourceURL.path.hashValue)
        return cacheDirectory.appendingPathComponent(hash).appendingPathExtension("jpg")
    }

    func clearDisk() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
