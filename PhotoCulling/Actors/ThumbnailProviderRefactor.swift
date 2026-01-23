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
        self.cost = Int(image.size.width * image.size.height * 4)
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
        return discarded
    }
}

// MARK: - Thumbnail Provider Actor
actor ThumbnailProviderRefactor {
    static let shared = ThumbnailProviderRefactor()
    var fileHandlers: FileHandlers?
    
    private let cache = NSCache<NSURL, DiscardableThumbnail>()

    private init() {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryLimit = min(Int(totalMemory / 10), 512 * 1024 * 1024)
        
        cache.countLimit = 250
        cache.totalCostLimit = memoryLimit
        cache.name = "no.blogspot.PhotoCulling.imageCache"
        cache.evictsObjectsWithDiscardedContent = true
    }

    func setFileHandlers(_ fileHandlers: FileHandlers) {
        self.fileHandlers = fileHandlers
    }

    // MARK: - Cache Management
    
    /// Completely clears the cache. Call this when switching catalogs.
    func clearCache() {
        Logger.process.debugMessageOnly("ThumbnailProvider: Clearing all cached thumbnails.")
        cache.removeAllObjects()
    }

    /// Removes a specific thumbnail (e.g., if a file was deleted)
    func removeThumbnail(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    // MARK: - Core Logic

    func thumbnail(for url: URL, targetSize: Int) async -> NSImage? {
        let nsUrl = url as NSURL

        if let wrapper = cache.object(forKey: nsUrl) {
            if await wrapper.beginContentAccess() {
                let img = wrapper.image
                await wrapper.endContentAccess()
                return img
            } else {
                cache.removeObject(forKey: nsUrl)
            }
        }

        do {
            let image = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))
            let wrapper = await DiscardableThumbnail(image: image)
            cache.setObject(wrapper, forKey: nsUrl, cost: wrapper.cost)
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
            if cache.object(forKey: fileURL as NSURL) != nil {
                successCount += 1
                continue
            }

            do {
                let img = try await extractSonyThumbnail(from: fileURL, maxDimension: CGFloat(targetSize))
                let wrapper = await DiscardableThumbnail(image: img)
                cache.setObject(wrapper, forKey: fileURL as NSURL, cost: wrapper.cost)
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
