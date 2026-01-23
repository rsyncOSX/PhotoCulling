import AppKit
import Foundation
import ImageIO
import OSLog

enum ThumbnailError: Error {
    case invalidSource
    case generationFailed
}

// MARK: - Thumbnail Provider Actor

actor ThumbnailProvider {
    nonisolated static let shared = ThumbnailProvider()

    var fileHandlers: FileHandlers?
    private let memoryCache = NSCache<NSURL, DiscardableThumbnail>()
    // 1. Mark this nonisolated to allow synchronous calling of its methods
    private nonisolated let diskCache = DiskCacheManager()

    private init() {
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

    func thumbnail(for url: URL, targetSize: Int) async -> NSImage? {
        let nsUrl = url as NSURL

        // 2. RAM - Access wrapper safely
        if let wrapper = memoryCache.object(forKey: nsUrl) {
            if wrapper.beginContentAccess() {
                let img = wrapper.image
                wrapper.endContentAccess()
                Logger.process.debugMessageOnly("ThumbnailProviderRefactor: thumbnail(): found in RAM Cache()")
                return img
            }
        }

        // 3. Disk
        if let diskImage = await diskCache.load(for: url) {
            let wrapper = await DiscardableThumbnail(image: diskImage)
            memoryCache.setObject(wrapper, forKey: nsUrl, cost: wrapper.cost)
            Logger.process.debugMessageOnly("ThumbnailProviderRefactor: thumbnail(): found in Disk Cache()")
            return diskImage
        }

        // 4. Extraction
        do {
            let image = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))
            let wrapper = await DiscardableThumbnail(image: image)
            memoryCache.setObject(wrapper, forKey: nsUrl, cost: wrapper.cost)
            let imgToSave = image
            Task.detached(priority: .background) { [diskCache] in
                await diskCache.save(imgToSave, for: url)
            }
            Logger.process.debugMessageOnly("ThumbnailProviderRefactor: thumbnail(): creating thumbnail")
            return image
        } catch {
            return nil
        }
    }

    func clearCaches() async {
        memoryCache.removeAllObjects()
        await diskCache.pruneCache()
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
            // 1. Check RAM Cache
            if memoryCache.object(forKey: fileURL as NSURL) != nil {
                Logger.process.debugMessageOnly("ThumbnailProviderRefactor: preloadCatalog: found in RAM Cache()")
                successCount += 1
                await fileHandlers?.fileHandler(successCount)
                continue
            }
            // 2. Check Disk Cache
            // We check if the image exists on disk before attempting extraction
            if let diskImage = await diskCache.load(for: fileURL) {
                let wrapper = await DiscardableThumbnail(image: diskImage)
                memoryCache.setObject(wrapper, forKey: fileURL as NSURL, cost: wrapper.cost)
                Logger.process.debugMessageOnly("ThumbnailProviderRefactor: preloadCatalog: found in Disk Cache()")
                successCount += 1
                await fileHandlers?.fileHandler(successCount)
                continue // Move to next file, no extraction needed
            }

            // 3. Extraction (Only if RAM and Disk both miss)
            do {
                Logger.process.debugMessageOnly("ThumbnailProviderRefactor: preloadCatalog: creating thumbnail")
                let image = try await extractSonyThumbnail(from: fileURL, maxDimension: CGFloat(targetSize))
                let wrapper = await DiscardableThumbnail(image: image)
                memoryCache.setObject(wrapper, forKey: fileURL as NSURL, cost: wrapper.cost)
                let imgToSave = image
                Task.detached(priority: .background) { [diskCache] in
                    await diskCache.save(imgToSave, for: fileURL)
                }
                successCount += 1
                await fileHandlers?.fileHandler(successCount)
            } catch {}
        }
        return successCount
    }
}
