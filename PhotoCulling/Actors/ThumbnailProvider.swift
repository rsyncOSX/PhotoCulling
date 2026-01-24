//
//  ThumbnailProvider.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 24/01/2026.
//

import AppKit
import Foundation
import OSLog

enum ThumbnailError: Error {
    case invalidSource
    case generationFailed
}

actor ThumbnailProvider {
    nonisolated static let shared = ThumbnailProvider()

    // 1. Isolated State
    private let memoryCache = NSCache<NSURL, DiscardableThumbnail>()
    private var successCount = 0
    private let diskCache = DiskCacheManager()

    // Track the current preload task so we can cancel it
    private var preloadTask: Task<Int, Never>?

    var fileHandlers: FileHandlers?

    let supported: Set<String> = ["arw", "tiff", "tif", "jpeg", "jpg", "png", "heic", "heif"]

    // 2. Performance Limits
    init() {
        memoryCache.totalCostLimit = 200 * 2560 * 2560 // 1.25 GB
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

    private func discoverFiles(at catalogURL: URL, recursive: Bool) async -> [URL] {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            var urls: [URL] = []

            guard let enumerator = fileManager.enumerator(
                at: catalogURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: recursive ? [] : [.skipsSubdirectoryDescendants]
            ) else { return urls }

            while let fileURL = enumerator.nextObject() as? URL {
                if self.supported.contains(fileURL.pathExtension.lowercased()) {
                    urls.append(fileURL)
                }
            }
            return urls
        }.value
    }

    @discardableResult
    func preloadCatalog(at catalogURL: URL, targetSize: Int) async -> Int {
        cancelPreload()

        let task = Task {
            successCount = 0
            let urls = await discoverFiles(at: catalogURL, recursive: false)

            await fileHandlers?.maxfilesHandler(urls.count)

            return await withThrowingTaskGroup(of: Void.self) { group in
                let maxConcurrent = ProcessInfo.processInfo.activeProcessorCount * 2 // Be a bit more aggressive

                for (index, url) in urls.enumerated() {
                    // Check for cancellation at the start of every loop
                    if Task.isCancelled {
                        group.cancelAll() // FIX #2: Stop all running tasks
                        break
                    }

                    if index >= maxConcurrent {
                        try? await group.next()
                    }

                    group.addTask {
                        await self.processSingleFile(url, targetSize: targetSize)
                    }
                }

                // Wait for remaining tasks to finish (or be cancelled)
                try? await group.waitForAll()
                return successCount
            }
        }

        preloadTask = task
        return await task.value
    }

    private func processSingleFile(_ url: URL, targetSize: Int) async {
        // Cancellation Check inside the processing unit
        if Task.isCancelled { return }

        // A. Check RAM
        if let wrapper = memoryCache.object(forKey: url as NSURL), wrapper.beginContentAccess() {
            wrapper.endContentAccess()
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugThreadOnly("ThumbnailProvider: processSingleFile() - found in RAM Cache")
            return
        }

        // B. Check Disk
        // Cancellation check again before doing heavy IO
        if Task.isCancelled { return }

        if let diskImage = await diskCache.load(for: url) {
            storeInMemory(diskImage, for: url)
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugThreadOnly("ThumbnailProvider: processSingleFile() - found in DISK Cache")
            return
        }

        // C. Extract
        do {
            if Task.isCancelled { return }

            // 1. Call the worker - we get a thread-safe CGImage
            let cgImage = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))

            // 2. Create NSImage HERE, inside the Actor
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // 3. Store the NSImage
            storeInMemory(image, for: url)

            let newCount = incrementAndGetCount()
            // Optional: Throttle this if UI jitters occur
            await fileHandlers?.fileHandler(newCount)

            Logger.process.debugThreadOnly("ThumbnailProvider: processSingleFile() - CREATING thumbnail")

            // Background save
            Task.detached(priority: .background) {
                await self.diskCache.save(cgImage, for: url)
            }
        } catch {
            print("Failed: \(url.lastPathComponent)")
        }
    }

    // Renamed to reflect that it uses generic ImageIO, not Sony-specific SDKs
    private nonisolated func extractSonyThumbnail(from url: URL, maxDimension: CGFloat) async throws -> CGImage {
        let cgImage = try await Task.detached(priority: .userInitiated) {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary

            guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
                throw ThumbnailError.invalidSource
            }

            let thumbOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ]

            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
                throw ThumbnailError.generationFailed
            }

            return image
        }.value

        return cgImage
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
        do {
            return try await resolveImage(for: url, targetSize: targetSize)
        } catch {
            print("Failed to resolve thumbnail: \(error)")
            return nil
        }
    }

    private func resolveImage(for url: URL, targetSize: Int) async throws -> NSImage {
        let nsUrl = url as NSURL

        // A. Check RAM
        if let wrapper = memoryCache.object(forKey: nsUrl), wrapper.beginContentAccess() {
            // FIX #1: We must pair begin with end.
            // The 'image' variable holds a strong reference to the NSImage,
            // so it's safe to tell the cache we are done accessing it.
            defer { wrapper.endContentAccess() }

            Logger.process.debugThreadOnly("resolveImage: found in RAM Cache")
            return wrapper.image
        }

        // B. Check Disk
        if let diskImage = await diskCache.load(for: url) {
            storeInMemory(diskImage, for: url)
            Logger.process.debugThreadOnly("resolveImage: found in Disk Cache")
            return diskImage
        }

        // C. Extract
        Logger.process.debugThreadOnly("resolveImage: CREATING thumbnail")

        // 1. Get the Sendable CGImage
        let cgImage = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize))

        // 2. Wrap in NSImage for display (inside Actor)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

        storeInMemory(image, for: url)

        // 3. Background save
        Task.detached(priority: .background) {
            await self.diskCache.save(cgImage, for: url)
        }

        return image
    }
}
