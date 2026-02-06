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
        totalCostLimit: 500 * 1024 * 1024, // ~500 MB for ~112 1024x1024 images
        countLimit: 1000
    )

    nonisolated static let testing = CacheConfig(
        totalCostLimit: 100_000, // Very small for testing evictions
        countLimit: 5
    )
}

actor ThumbnailProvider {
    nonisolated static let shared = ThumbnailProvider()

    // 1. Isolated State
    private let memoryCache: NSCache<NSURL, DiscardableThumbnail>
    private var successCount = 0
    private let diskCache: DiskCacheManager

    // Cache statistics for monitoring
    private var cacheMemory = 0
    private var cacheDisk = 0
    private var cacheEvictions = 0

    /// Saved Memory Cache settings
    private var savedsettings: SavedSettings?

    /// Track the current preload task so we can cancel it
    private var preloadTask: Task<Int, Never>?

    private var fileHandlers: FileHandlers?
    /// Memory cost per pixel for thumbnails (1-8 bytes) - affects quality
    private var costPerPixel: Int = 4
    /// let supported: Set<String> = ["arw", "tiff", "tif", "jpeg", "jpg", "png", "heic", "heif"]
    let supported: Set<String> = ["arw"]

    /// 2. Performance Limits - Configurable for testing
    init(config: CacheConfig? = nil, diskCache: DiskCacheManager? = nil) {
        memoryCache = NSCache<NSURL, DiscardableThumbnail>()
        if let config {
            memoryCache.totalCostLimit = config.totalCostLimit
            memoryCache.countLimit = config.countLimit
            memoryCache.delegate = CacheDelegate.shared
        }
        self.diskCache = diskCache ?? DiskCacheManager()
        Task {
            // Only set if config == nil, config is set in Tests
            if config == nil {
                await self.setmemomorycachefromsavedsettings()
            }
        }
    }

    func setmemomorycachefromsavedsettings() async {
        savedsettings = await SettingsManager.shared.asyncgetsettings()
        if let settings = savedsettings {
            let thumbnailCostPerPixel = settings.thumbnailCostPerPixel // 4 default
            let thumbnailSizePreview = settings.thumbnailSizePreview // 1024 default
            let memoryCacheSizeMB = settings.memoryCacheSizeMB // 500MB default
            let maxCachedThumbnails = settings.maxCachedThumbnails // default 100

            let estimatedCostPerImage = (thumbnailSizePreview * thumbnailSizePreview * thumbnailCostPerPixel * 11) / 10
            let totalCostlimit = memoryCacheSizeMB * 1024 * 1024 // Convert MB to bytes
            let countLimit = estimatedCostPerImage > 0 ? totalCostlimit / estimatedCostPerImage : maxCachedThumbnails

            Logger.process.debugMessageOnly(
                "test(): totalCostLimit: \(totalCostlimit), countLimit: \(countLimit), costPerPixel: \(thumbnailCostPerPixel)"
            )

            memoryCache.totalCostLimit = totalCostlimit
            memoryCache.countLimit = countLimit
            // Set delegate to track evictions
            memoryCache.delegate = CacheDelegate.shared
        }
    }

    func getsettings() async -> SavedSettings {
        await SettingsManager.shared.asyncgetsettings()
    }

    func setFileHandlers(_ fileHandlers: FileHandlers) {
        self.fileHandlers = fileHandlers
    }

    func setCostPerPixel(_ cost: Int) {
        self.costPerPixel = max(1, min(8, cost)) // Clamp between 1-8
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
            cacheMemory += 1
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugThreadOnly("ThumbnailProvider: processSingleFile() - found in RAM Cache (hits: \(cacheMemory))")
            return
        }

        // B. Check Disk
        // Cancellation check again before doing heavy IO
        if Task.isCancelled { return }

        if let diskImage = await diskCache.load(for: url) {
            storeInMemory(diskImage, for: url)
            cacheDisk += 1
            let newCount = incrementAndGetCount()
            await fileHandlers?.fileHandler(newCount)
            Logger.process.debugThreadOnly("ThumbnailProvider: processSingleFile() - found in DISK Cache (misses: \(cacheDisk))")
            return
        }

        // C. Extract
        do {
            if Task.isCancelled { return }

            // 1. Call the worker - we get a thread-safe CGImage
            let cgImage = try await extractSonyThumbnail(
                from: url,
                maxDimension: CGFloat(targetSize),
                qualityCost: costPerPixel
            )

            // 2. Create NSImage HERE, inside the Actor
            let image = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width,
                             height: cgImage.height)
            )

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
    /// qualityCost: 1-8 bytes per pixel, controls interpolation quality
    private nonisolated func extractSonyThumbnail(from url: URL, maxDimension: CGFloat, qualityCost: Int = 4) async throws -> CGImage {
        try await Task.detached(priority: .userInitiated) {
            let options = [kCGImageSourceShouldCache: false] as CFDictionary

            guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
                throw ThumbnailError.invalidSource
            }

            // Map quality cost to interpolation quality
            let interpolationQuality: CGInterpolationQuality
            switch qualityCost {
            case 1 ... 2:
                interpolationQuality = .low

            case 3 ... 4:
                interpolationQuality = .medium

            default: // 5...8
                interpolationQuality = .high
            }

            let thumbOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: false
            ]

            guard var image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
                throw ThumbnailError.generationFailed
            }

            // Apply interpolation quality through image rendering context
            if qualityCost != 4 { // Only reprocess if different from default
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                if let context = CGContext(data: nil,
                                           width: image.width,
                                           height: image.height,
                                           bitsPerComponent: image.bitsPerComponent,
                                           bytesPerRow: 0,
                                           space: colorSpace,
                                           bitmapInfo: image.bitmapInfo.rawValue) {
                    context.interpolationQuality = interpolationQuality
                    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                    if let processedImage = context.makeImage() {
                        image = processedImage
                    }
                }
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
        let hitRate = cacheMemory + cacheDisk > 0 ? Double(cacheMemory) / Double(cacheMemory + cacheDisk) * 100 : 0
        Logger.process.info("Cache Statistics - Hits: \(self.cacheMemory), Misses: \(self.cacheDisk), Hit Rate: \(String(format: "%.1f", hitRate))%")

        memoryCache.removeAllObjects()
        await diskCache.pruneCache(maxAgeInDays: 0)

        // Reset statistics
        cacheMemory = 0
        cacheDisk = 0
        cacheEvictions = 0
    }

    /// Get current cache statistics for monitoring
    func getCacheStatistics() async -> (hits: Int, misses: Int, evictions: Int, hitRate: Double) {
        let total = cacheMemory + cacheDisk
        let hitRate = total > 0 ? Double(cacheMemory) / Double(total) * 100 : 0
        return (cacheMemory, cacheDisk, cacheEvictions, hitRate)
    }

    /// Get current disk cache size in bytes
    func getDiskCacheSize() async -> Int {
        await diskCache.getDiskCacheSize()
    }

    /// Prune disk cache to remove old files
    func pruneDiskCache(maxAgeInDays: Int = 30) async {
        await diskCache.pruneCache(maxAgeInDays: maxAgeInDays)
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
            cacheMemory += 1
            Logger.process.debugThreadOnly("resolveImage: found in RAM Cache (hits: \(cacheMemory))")
            return wrapper.image
        }

        // B. Check Disk
        if let diskImage = await diskCache.load(for: url) {
            storeInMemory(diskImage, for: url)
            cacheDisk += 1
            Logger.process.debugThreadOnly("resolveImage: found in Disk Cache (misses: \(cacheDisk))")
            return diskImage
        }

        // C. Extract
        Logger.process.debugThreadOnly("resolveImage: CREATING thumbnail")

        // 1. Get the Sendable CGImage
        let cgImage = try await extractSonyThumbnail(from: url, maxDimension: CGFloat(targetSize), qualityCost: costPerPixel)

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
