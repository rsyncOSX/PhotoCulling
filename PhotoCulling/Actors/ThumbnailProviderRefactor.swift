//
//  ThumbnailProviderRefactor.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 24/01/2026.
//

import AppKit
import Foundation
import OSLog

actor ThumbnailProviderRefactor {
    nonisolated static let shared = ThumbnailProviderRefactor()

    // 1. Isolated State
    private let memoryCache = NSCache<NSURL, DiscardableThumbnail>()
    private var successCount = 0
    private let diskCache = DiskCacheManager() // Assume this is also thread-safe

    // Track the current preload task so we can cancel it
    private var preloadTask: Task<Int, Never>?

    var fileHandlers: FileHandlers?

    // 2. Performance Limits
    init() {
        memoryCache.totalCostLimit = 200 * 1024 * 1024 // 200MB
        memoryCache.countLimit = 500
    }

    func setFileHandlers(_ fileHandlers: FileHandlers) {
        self.fileHandlers = fileHandlers
    }

    func cancelPreload() {
        preloadTask?.cancel()
        preloadTask = nil
        Logger.process.debugMessageOnly("ThumbnailProvider: Preload Cancelled")
    }

    /// 1. Discovery Function (The missing piece)
    private func discoverFiles(at catalogURL: URL, recursive: Bool) async -> [URL] {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let supported: Set<String> = ["arw", "tiff", "tif", "jpeg", "jpg", "png"]
            var urls: [URL] = []

            guard let enumerator = fileManager.enumerator(
                at: catalogURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: recursive ? [] : [.skipsSubdirectoryDescendants]
            ) else { return urls }

            while let fileURL = enumerator.nextObject() as? URL {
                if supported.contains(fileURL.pathExtension.lowercased()) {
                    urls.append(fileURL)
                }
            }
            return urls
        }.value
    }

    @discardableResult
    func preloadCatalog(at catalogURL: URL, targetSize: Int) async -> Int {
        // Cancel any existing preload before starting a new one
        cancelPreload()

        let task = Task {
            successCount = 0
            let urls = await discoverFiles(at: catalogURL, recursive: false)

            await fileHandlers?.maxfilesHandler(urls.count)

            return await withThrowingTaskGroup(of: Void.self) { group in
                let maxConcurrent = ProcessInfo.processInfo.activeProcessorCount

                for (index, url) in urls.enumerated() {
                    // Check for cancellation at the start of every loop
                    if Task.isCancelled { break }

                    if index >= maxConcurrent { try? await group.next() }

                    group.addTask {
                        await self.processSingleFile(url, targetSize: targetSize)
                    }
                }
                return successCount
            }
        }

        preloadTask = task
        return await task.value
    }

    // This method is actor-isolated: only one thread can be here at a time
    private func processSingleFile(_ url: URL, targetSize: Int) async {
        // A. Check RAM
        if let wrapper = memoryCache.object(forKey: url as NSURL), wrapper.beginContentAccess() {
            wrapper.endContentAccess()
            let newCount = incrementAndGetCount()
            // Assuming fileHandlers is accessible or passed in
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugMessageOnly("ThumbnailProvider: processSingleFile() - found in RAM Cache")
            return
        }

        // B. Check Disk
        if let diskImage = await diskCache.load(for: url) {
            storeInMemory(diskImage, for: url)
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugMessageOnly("ThumbnailProvider: processSingleFile() - found in DISK Cache")
            return
        }

        // C. Extract (Heavy lifting)
        do {
            // We call this but the ACTUAL work happens off the actor
            // because extractSonyThumbnail is 'nonisolated'
            let image = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))
            storeInMemory(image, for: url)
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugMessageOnly("ThumbnailProvider: processSingleFile() - CREATING thumbnail")
            // Background save to disk
            Task.detached(priority: .background) {
                await self.diskCache.save(image, for: url)
            }
        } catch {
            print("Failed: \(url.lastPathComponent)")
        }
    }

    private nonisolated func extractSonyThumbnail(from url: URL, maxDimension: CGFloat) async throws -> NSImage {
        // 1. Run the heavy decoding on a detached background task
        let cgImage = try await Task.detached(priority: .userInitiated) {
            // Use ShouldCache: false to prevent the OS from caching the HUGE raw data globally
            let options = [kCGImageSourceShouldCache: false] as CFDictionary

            guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
                throw ThumbnailError.invalidSource
            }

            let thumbOptions: [CFString: Any] = [
                // FORCE a high-quality decode from the RAW data
                // instead of the tiny embedded Sony preview
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ]

            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
                throw ThumbnailError.generationFailed
            }

            return image // Return the CGImage (which is thread-safe/Sendable)
        }.value

        // 2. Convert to NSImage back on the Main Actor or calling thread
        // This avoids NSImage thread-safety issues
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func storeInMemory(_ image: NSImage, for url: URL) {
        let wrapper = DiscardableThumbnail(image: image)
        memoryCache.setObject(wrapper, forKey: url as NSURL, cost: wrapper.cost)
    }

    private func incrementAndGetCount() -> Int {
        successCount += 1
        return successCount
    }
    
    func clearCaches() async {
        memoryCache.removeAllObjects()
        await diskCache.pruneCache(maxAgeInDays: 0)
    }
    
    func thumbnail(for url: URL, targetSize: Int) async -> NSImage? {
        let nsUrl = url as NSURL

        // 1. RAM - Access wrapper safely
        if let wrapper = memoryCache.object(forKey: nsUrl) {
            if wrapper.beginContentAccess() {
                let img = wrapper.image
                wrapper.endContentAccess()
                Logger.process.debugMessageOnly("ThumbnailProvider: Found in RAM Cache")
                return img
            } else {
                // Content was discarded by the OS; clean up the "dead" wrapper
                memoryCache.removeObject(forKey: nsUrl)
                Logger.process.debugMessageOnly("ThumbnailProvider: Wrapper found but content discarded")
            }
        }

        // 2. Disk
        if let diskImage = await diskCache.load(for: url) {
            let wrapper = DiscardableThumbnail(image: diskImage)
            memoryCache.setObject(wrapper, forKey: nsUrl, cost: wrapper.cost)
            Logger.process.debugMessageOnly("ThumbnailProvider: thumbnail(): found in Disk Cache()")
            return diskImage
        }

        // 3. Extraction
        do {
            let image = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))
            let wrapper = DiscardableThumbnail(image: image)
            memoryCache.setObject(wrapper, forKey: nsUrl, cost: wrapper.cost)
            let imgToSave = image
            Task.detached(priority: .background) { [diskCache] in
                await diskCache.save(imgToSave, for: url)
            }
            Logger.process.debugMessageOnly("ThumbnailProvider: thumbnail(): creating thumbnail")
            return image
        } catch {
            return nil
        }
    }
}
