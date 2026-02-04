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

/// Delegate to track NSCache evictions for monitoring memory pressure
final class CacheDelegate: NSObject, NSCacheDelegate, @unchecked Sendable {
    nonisolated static let shared = CacheDelegate()

    override nonisolated init() {
        super.init()
    }

    /// ✅ FIX: Change 'obj: AnyObject' to 'obj: Any'
    nonisolated func cache(_: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // The cast still works exactly the same way
        if let image = obj as? NSImage {
            Logger.process.debugMessageOnly("Evicted image: \(image)")
        }
    }
}

struct CacheConfig {
    let totalCostLimit: Int
    let countLimit: Int

    nonisolated static let production = CacheConfig(
        totalCostLimit: 200 * 2560 * 2560, // 1.25 GB
        countLimit: 500
    )

    nonisolated static let testing = CacheConfig(
        totalCostLimit: 100_000, // Very small for testing evictions
        countLimit: 5
    )
}

actor ThumbnailProvider {
    nonisolated static let shared = ThumbnailProvider(config: .production)

    // 1. Isolated State
    private let memoryCache: NSCache<NSURL, DiscardableThumbnail>
    private var successCount = 0
    private let diskCache: DiskCacheManager

    // Cache statistics for monitoring
    private var cacheHits = 0
    private var cacheMisses = 0
    private var cacheEvictions = 0

    /// Track the current preload task so we can cancel it
    private var preloadTask: Task<Int, Never>?

    private var fileHandlers: FileHandlers?
    /// let supported: Set<String> = ["arw", "tiff", "tif", "jpeg", "jpg", "png", "heic", "heif"]
    let supported: Set<String> = ["arw"]

    /// 2. Performance Limits - Configurable for testing
    init(config: CacheConfig = .production, diskCache: DiskCacheManager? = nil) {
        memoryCache = NSCache<NSURL, DiscardableThumbnail>()
        memoryCache.totalCostLimit = config.totalCostLimit
        memoryCache.countLimit = config.countLimit
        // Set delegate to track evictions
        memoryCache.delegate = CacheDelegate.shared
        self.diskCache = diskCache ?? DiskCacheManager()
    }

    func setFileHandlers(_ fileHandlers: FileHandlers) {
        self.fileHandlers = fileHandlers
    }

    private func cancelPreload() {
        preloadTask?.cancel()
        preloadTask = nil
        Logger.process.debugMessageOnly("ThumbnailProvider: Preload Cancelled")
    }

    @discardableResult
    func preloadCatalog(at catalogURL: URL, targetSize: Int) async -> Int {
        cancelPreload()

        let task = Task {
            successCount = 0
            let urls = await DiscoverFiles().discoverFiles(at: catalogURL, recursive: false)

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
            cacheHits += 1
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugThreadOnly("ThumbnailProvider: processSingleFile() - found in RAM Cache (hits: \(cacheHits))")
            return
        }

        // B. Check Disk
        // Cancellation check again before doing heavy IO
        if Task.isCancelled { return }

        if let diskImage = await diskCache.load(for: url) {
            storeInMemory(diskImage, for: url)
            cacheMisses += 1
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugThreadOnly("ThumbnailProvider: processSingleFile() - found in DISK Cache (misses: \(cacheMisses))")
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
            Logger.process.warning("Failed: \(url.lastPathComponent)")
        }
    }

    /// Renamed to reflect that it uses generic ImageIO, not Sony-specific SDKs
    private nonisolated func extractSonyThumbnail(from url: URL, maxDimension: CGFloat) async throws -> CGImage {
        try await Task.detached(priority: .userInitiated) {
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
        let hitRate = cacheHits + cacheMisses > 0 ? Double(cacheHits) / Double(cacheHits + cacheMisses) * 100 : 0
        Logger.process.info("Cache Statistics - Hits: \(self.cacheHits), Misses: \(self.cacheMisses), Hit Rate: \(String(format: "%.1f", hitRate))%")

        memoryCache.removeAllObjects()
        await diskCache.pruneCache(maxAgeInDays: 0)

        // Reset statistics
        cacheHits = 0
        cacheMisses = 0
        cacheEvictions = 0
    }

    /// Get current cache statistics for monitoring
    func getCacheStatistics() async -> (hits: Int, misses: Int, evictions: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) * 100 : 0
        return (cacheHits, cacheMisses, cacheEvictions, hitRate)
    }

    func thumbnail(for url: URL, targetSize: Int) async -> NSImage? {
        do {
            return try await resolveImage(for: url, targetSize: targetSize)
        } catch {
            Logger.process.warning("Failed to resolve thumbnail: \(error)")
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
            cacheHits += 1
            Logger.process.debugThreadOnly("resolveImage: found in RAM Cache (hits: \(cacheHits))")
            return wrapper.image
        }

        // B. Check Disk
        if let diskImage = await diskCache.load(for: url) {
            storeInMemory(diskImage, for: url)
            cacheMisses += 1
            Logger.process.debugThreadOnly("resolveImage: found in Disk Cache (misses: \(cacheMisses))")
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

/*
 nsImage = await ThumbnailProvider.shared.thumbnail(for: file.url, targetSize: 2560)
 */
