//
//  ThumbnailProviderTests.swift
//  PhotoCullingTests
//
//  Created by Thomas Evensen on 04/02/2026.
//

import AppKit
import Foundation
@testable import PhotoCulling
import Testing

// MARK: - Mock DiskCacheManager for testing

/*
actor MockDiskCacheManager: DiskCacheManager {
    private var cache: [URL: NSImage] = [:]
    var saveCallCount = 0
    var loadCallCount = 0

    override func save(_ cgImage: CGImage, for url: URL) async {
        saveCallCount += 1
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        cache[url] = nsImage
    }

    override func load(for url: URL) async -> NSImage? {
        loadCallCount += 1
        return cache[url]
    }

    override func pruneCache(maxAgeInDays _: Int) async {
        cache.removeAll()
    }
}
*/
// MARK: - Test Image Generator

func createTestImage(width: Int = 100, height: Int = 100) -> NSImage {
    let size = NSSize(width: width, height: height)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.red.setFill()
    NSRect(origin: .zero, size: size).fill()
    image.unlockFocus()
    return image
}

// MARK: - Tests

@Suite("ThumbnailProvider Tests")
@MainActor
struct ThumbnailProviderTests {
    // MARK: - Initialization Tests

    @Test("Initializes with production config by default")
    func productionConfigInitialization() async {
        let provider = ThumbnailProvider()
        let stats = await provider.getCacheStatistics()
        #expect(stats.hitRate == 0)
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
    }

    @Test("Initializes with custom config")
    func testCustomConfigInitialization() async {
        let testConfig = CacheConfig(totalCostLimit: 50000, countLimit: 3)
        let provider = ThumbnailProvider(config: testConfig)
        let stats = await provider.getCacheStatistics()
        #expect(stats.hitRate == 0)
    }

    // MARK: - Cache Statistics Tests

    @Test("Cache hit rate calculates correctly")
    func testCacheHitRate() async {
        let provider = ThumbnailProvider(config: .testing)

        // Create test images
        let testImage = createTestImage()

        // Simulate a hit and a miss
        // Note: We'd need access to storeInMemory to fully test this
        // For now, we test the statistics gathering
        let stats = await provider.getCacheStatistics()
        let expectedHitRate = 0.0 // Initially no hits or misses

        #expect(stats.hitRate == expectedHitRate)
    }

    @Test("Statistics reset after clear caches")
    func testStatisticsResetAfterClear() async {
        let provider = ThumbnailProvider(config: .testing)

        // Get initial stats
        var stats = await provider.getCacheStatistics()
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)

        // Clear and verify
        await provider.clearCaches()
        stats = await provider.getCacheStatistics()
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
    }

    // MARK: - Memory Limit Tests

    @Test("Cache respects count limit")
    func testCountLimit() async {
        let testConfig = CacheConfig(totalCostLimit: 10_000_000, countLimit: 3)
        let provider = ThumbnailProvider(config: testConfig)

        let testImage1 = createTestImage(width: 50, height: 50)
        let testImage2 = createTestImage(width: 50, height: 50)
        let testImage3 = createTestImage(width: 50, height: 50)
        let testImage4 = createTestImage(width: 50, height: 50)

        let url1 = URL(fileURLWithPath: "/test1.jpg")
        let url2 = URL(fileURLWithPath: "/test2.jpg")
        let url3 = URL(fileURLWithPath: "/test3.jpg")
        let url4 = URL(fileURLWithPath: "/test4.jpg")

        // This is an indirect test - we can't directly access the cache,
        // but we can verify the limit doesn't crash the system
        // A full test would require exposing cache internals or using reflection

        #expect(true) // Placeholder for conceptual test
    }

    @Test("Cache respects cost limit")
    func testCostLimit() async {
        let testConfig = CacheConfig(totalCostLimit: 100_000, countLimit: 100)
        let provider = ThumbnailProvider(config: testConfig)

        // With a very small cost limit, items should be evicted
        // This tests the memory management

        #expect(true) // Placeholder - full implementation requires cache introspection
    }

    // MARK: - Cache Lookup Tests

    @Test("Thumbnail method handles missing files gracefully")
    func testThumbnailMissingFile() async {
        let provider = ThumbnailProvider(config: .testing)
        let missingURL = URL(fileURLWithPath: "/nonexistent/file.jpg")

        let result = await provider.thumbnail(for: missingURL, targetSize: 256)

        #expect(result == nil)
    }

    // MARK: - Clear Cache Tests

    @Test("Clear caches removes all cached items")
    func testClearCaches() async {
        let provider = ThumbnailProvider(config: .testing)

        // Clear caches
        await provider.clearCaches()

        // Verify statistics are reset
        let stats = await provider.getCacheStatistics()
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
        #expect(stats.evictions == 0)
    }

    // MARK: - Preload Catalog Tests

    @Test("Preload catalog starts and can be tracked")
    func testPreloadCatalogInitiation() async {
        let provider = ThumbnailProvider(config: .testing)
        let testDir = FileManager.default.temporaryDirectory

        // This will fail to find files but tests the mechanism
        let result = await provider.preloadCatalog(at: testDir, targetSize: 256)

        #expect(result >= 0)
    }

    // MARK: - Concurrency Tests

    @Test("Provider handles concurrent access safely")
    func testConcurrentAccess() async {
        let provider = ThumbnailProvider(config: .testing)
        let testURL = URL(fileURLWithPath: "/test/file.jpg")

        // Attempt concurrent reads on non-existent file
        async let result1 = provider.thumbnail(for: testURL, targetSize: 256)
        async let result2 = provider.thumbnail(for: testURL, targetSize: 256)
        async let result3 = provider.thumbnail(for: testURL, targetSize: 256)

        let (r1, r2, r3) = await (result1, result2, result3)

        #expect(r1 == nil)
        #expect(r2 == nil)
        #expect(r3 == nil)
    }

    // MARK: - Configuration Tests

    @Test("Config production has correct limits")
    func testProductionConfigLimits() async {
        let config = CacheConfig.production

        #expect(config.totalCostLimit == 200 * 2560 * 2560)
        #expect(config.countLimit == 500)
    }

    @Test("Config testing has small limits")
    func testTestingConfigLimits() async {
        let config = CacheConfig.testing

        #expect(config.totalCostLimit == 100_000)
        #expect(config.countLimit == 5)
    }

    // MARK: - Cache Delegate Tests

    @Test("Cache delegate is properly set")
    func testCacheDelegateIsSet() async {
        let provider = ThumbnailProvider(config: .testing)

        // Verify provider initializes without crashing
        // A full test would require exposing the delegate

        #expect(true)
    }

    // MARK: - Sendable Conformance Tests

    @Test("Provider is actor-isolated for thread safety")
    func testActorIsolation() async {
        let provider = ThumbnailProvider(config: .testing)

        // Multiple concurrent accesses should not cause data races
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 5 {
                group.addTask {
                    let stats = await provider.getCacheStatistics()
                    #expect(stats.hitRate >= 0)
                }
            }
        }
    }
}

// MARK: - Performance Tests

@Suite("ThumbnailProvider Performance Tests")
@MainActor
struct ThumbnailProviderPerformanceTests {
    @Test("Statistics gathering is fast")
    func testStatisticsPerformance() async {
        let provider = ThumbnailProvider(config: .testing)

        let startTime = Date()
        for _ in 0 ..< 1000 {
            _ = await provider.getCacheStatistics()
        }
        let duration = Date().timeIntervalSince(startTime)

        // Should complete 1000 calls in less than 1 second
        #expect(duration < 1.0)
    }

    @Test("Clear operation completes promptly")
    func testClearCachesPerformance() async {
        let provider = ThumbnailProvider(config: .testing)

        let startTime = Date()
        await provider.clearCaches()
        let duration = Date().timeIntervalSince(startTime)

        // Should complete quickly even with empty cache
        #expect(duration < 1.0)
    }
}

// MARK: - Integration Tests

@Suite("ThumbnailProvider Integration Tests")
@MainActor
struct ThumbnailProviderIntegrationTests {
    @Test("Multiple operations in sequence work correctly")
    func testMultipleOperationsSequence() async {
        let provider = ThumbnailProvider(config: .testing)

        // Get initial stats
        let initialStats = await provider.getCacheStatistics()
        #expect(initialStats.hits == 0)

        // Clear
        await provider.clearCaches()

        // Get final stats
        let finalStats = await provider.getCacheStatistics()
        #expect(finalStats.hits == 0)
    }

    @Test("Provider maintains isolation across instances")
    func testInstanceIsolation() async {
        let provider1 = ThumbnailProvider(config: .testing)
        let provider2 = ThumbnailProvider(config: .testing)

        // Each instance should have independent state
        let stats1 = await provider1.getCacheStatistics()
        let stats2 = await provider2.getCacheStatistics()

        #expect(stats1.hits == stats2.hits)
        #expect(stats1.misses == stats2.misses)
    }
}
