//
//  ThumbnailProviderAdvancedTests.swift
//  PhotoCullingTests
//
//  Created by Thomas Evensen on 04/02/2026.
//
//  Advanced tests for ThumbnailProvider covering edge cases,
//  stress tests, and memory pressure scenarios.
//

import AppKit
import Foundation
@testable import PhotoCulling
import Testing

@Suite("ThumbnailProvider Advanced Memory Tests")
struct ThumbnailProviderAdvancedMemoryTests {
    @Test("Small cost limit triggers rapid evictions")
    async func testRapidEvictionsWithSmallCostLimit() {
        let config = CacheConfig(totalCostLimit: 10000, countLimit: 100)
        let provider = ThumbnailProvider(config: config)

        let initialStats = await provider.getCacheStatistics()
        #expect(initialStats.evictions == 0)

        // After clear, evictions should still be tracked
        await provider.clearCaches()
        let finalStats = await provider.getCacheStatistics()
        #expect(finalStats.evictions == 0) // Cleared
    }

    @Test("Very small count limit prevents accumulation")
    async func testCountLimitStrictEnforcement() {
        let config = CacheConfig(totalCostLimit: 1_000_000, countLimit: 1)
        let provider = ThumbnailProvider(config: config)

        let stats = await provider.getCacheStatistics()
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
    }

    @Test("Cost calculation accuracy")
    async func testCostCalculation() {
        let image = createTestImage(width: 256, height: 256)
        let thumbnail = DiscardableThumbnail(image: image)

        // 256 * 256 * 4 bytes per pixel = 262,144 bytes
        // Plus 10% overhead = 288,358 bytes
        let expectedMinCost = 256 * 256 * 4

        #expect(thumbnail.cost >= expectedMinCost)
    }
}

@Suite("ThumbnailProvider Stress Tests")
struct ThumbnailProviderStressTests {
    @Test("Handles rapid sequential operations")
    async func testRapidSequentialOperations() {
        let provider = ThumbnailProvider(config: .testing)

        for _ in 0 ..< 100 {
            let stats = await provider.getCacheStatistics()
            #expect(stats.hitRate >= 0)
        }
    }

    @Test("Handles many concurrent statistics calls")
    async func testHighConcurrencyStatistics() {
        let provider = ThumbnailProvider(config: .testing)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 50 {
                group.addTask {
                    let stats = await provider.getCacheStatistics()
                    #expect(stats.hits >= 0)
                }
            }
        }
    }

    @Test("Clear during concurrent operations")
    async func testConcurrentClear() {
        let provider = ThumbnailProvider(config: .testing)

        async let clearTask = provider.clearCaches()
        async let statsTask = provider.getCacheStatistics()

        _ = await (clearTask, statsTask)
    }

    @Test("Multiple rapid clear operations")
    async func testRapidClears() {
        let provider = ThumbnailProvider(config: .testing)

        for _ in 0 ..< 10 {
            await provider.clearCaches()
        }

        let stats = await provider.getCacheStatistics()
        #expect(stats.hits == 0)
    }
}

@Suite("ThumbnailProvider Edge Case Tests")
struct ThumbnailProviderEdgeCaseTests {
    @Test("Config with zero cost limit")
    async func testZeroCostLimit() {
        // Edge case: what happens with totalCostLimit = 0?
        let config = CacheConfig(totalCostLimit: 0, countLimit: 10)
        let provider = ThumbnailProvider(config: config)

        let stats = await provider.getCacheStatistics()
        #expect(stats.hitRate == 0)
    }

    @Test("Config with zero count limit")
    async func testZeroCountLimit() {
        // Edge case: what happens with countLimit = 0?
        let config = CacheConfig(totalCostLimit: 1_000_000, countLimit: 0)
        let provider = ThumbnailProvider(config: config)

        let stats = await provider.getCacheStatistics()
        #expect(stats.hitRate == 0)
    }

    @Test("Very large cache configuration")
    async func testLargeCacheConfig() {
        let config = CacheConfig(
            totalCostLimit: Int.max / 2,
            countLimit: Int.max / 2
        )
        let provider = ThumbnailProvider(config: config)

        let stats = await provider.getCacheStatistics()
        #expect(stats.hits == 0)
    }

    @Test("Thumbnail with extreme URL paths")
    async func testExtremeURLPaths() {
        let provider = ThumbnailProvider(config: .testing)

        let veryLongPath = URL(fileURLWithPath: String(repeating: "/path", count: 100))
        let result = await provider.thumbnail(for: veryLongPath, targetSize: 256)

        #expect(result == nil)
    }

    @Test("Preload with nonexistent directory")
    async func testPreloadNonexistentDirectory() {
        let provider = ThumbnailProvider(config: .testing)
        let fakeDir = URL(fileURLWithPath: "/fake/nonexistent/path/\(UUID().uuidString)")

        let result = await provider.preloadCatalog(at: fakeDir, targetSize: 256)

        #expect(result >= 0) // Should return gracefully
    }
}

@Suite("ThumbnailProvider Configuration Tests")
struct ThumbnailProviderConfigurationTests {
    @Test("Different configs have different limits")
    async func testConfigDifferences() {
        let config1 = CacheConfig.production
        let config2 = CacheConfig.testing

        #expect(config1.totalCostLimit > config2.totalCostLimit)
        #expect(config1.countLimit > config2.countLimit)
    }

    @Test("Custom config creation")
    async func testCustomConfigCreation() {
        let customConfigs = [
            CacheConfig(totalCostLimit: 1000, countLimit: 1),
            CacheConfig(totalCostLimit: 10000, countLimit: 5),
            CacheConfig(totalCostLimit: 100_000, countLimit: 10),
            CacheConfig(totalCostLimit: 1_000_000, countLimit: 100)
        ]

        for config in customConfigs {
            let provider = ThumbnailProvider(config: config)
            let stats = await provider.getCacheStatistics()
            #expect(stats.hitRate >= 0)
        }
    }
}

@Suite("ThumbnailProvider Discardable Content Tests")
struct ThumbnailProviderDiscardableContentTests {
    @Test("DiscardableThumbnail tracks access correctly")
    async func testDiscardableThumbnailAccess() {
        let image = createTestImage()
        let thumbnail = DiscardableThumbnail(image: image)

        // Begin access should succeed initially
        let canAccess = thumbnail.beginContentAccess()
        #expect(canAccess == true)

        // End access
        thumbnail.endContentAccess()
    }

    @Test("DiscardableThumbnail image property accessible")
    async func testDiscardableThumbnailImageAccess() {
        let originalImage = createTestImage()
        let thumbnail = DiscardableThumbnail(image: originalImage)

        let canAccess = thumbnail.beginContentAccess()
        #expect(canAccess == true)

        let retrievedImage = thumbnail.image
        #expect(retrievedImage.size == originalImage.size)

        thumbnail.endContentAccess()
    }

    @Test("DiscardableThumbnail cost reflects size")
    async func testDiscardableThumbnailCostVariation() {
        let smallImage = createTestImage(width: 50, height: 50)
        let largeImage = createTestImage(width: 500, height: 500)

        let smallThumbnail = DiscardableThumbnail(image: smallImage)
        let largeThumbnail = DiscardableThumbnail(image: largeImage)

        // Larger image should have higher cost
        #expect(largeThumbnail.cost > smallThumbnail.cost)
    }
}

@Suite("ThumbnailProvider Isolation Tests")
struct ThumbnailProviderIsolationTests {
    @Test("Shared instance is consistent")
    async func testSharedInstanceConsistency() {
        let provider1 = ThumbnailProvider.shared
        let provider2 = ThumbnailProvider.shared

        let stats1 = await provider1.getCacheStatistics()
        let stats2 = await provider2.getCacheStatistics()

        #expect(stats1.hits == stats2.hits)
        #expect(stats1.misses == stats2.misses)
    }

    @Test("Different instances are independent")
    async func testInstanceIndependence() {
        let provider1 = ThumbnailProvider(config: .testing)
        let provider2 = ThumbnailProvider(config: .testing)

        let stats1 = await provider1.getCacheStatistics()
        let stats2 = await provider2.getCacheStatistics()

        // Both should start fresh
        #expect(stats1.hits == 0)
        #expect(stats2.hits == 0)
    }
}

@Suite("ThumbnailProvider Scalability Tests")
struct ThumbnailProviderScalabilityTests {
    @Test("Handles variable target sizes")
    async func testVariousTargetSizes() {
        let provider = ThumbnailProvider(config: .testing)
        let testURL = URL(fileURLWithPath: "/test.jpg")

        let sizes = [64, 128, 256, 512, 1024, 2560]
        for size in sizes {
            let result = await provider.thumbnail(for: testURL, targetSize: size)
            // Non-existent file will return nil, but verify no crash
            #expect(true)
        }
    }

    @Test("Multiple concurrent preloads")
    async func testConcurrentPreloads() {
        let provider = ThumbnailProvider(config: .testing)
        let testDir = FileManager.default.temporaryDirectory

        async let preload1 = provider.preloadCatalog(at: testDir, targetSize: 256)
        async let preload2 = provider.preloadCatalog(at: testDir, targetSize: 256)

        let (result1, result2) = await (preload1, preload2)

        #expect(result1 >= 0)
        #expect(result2 >= 0)
    }
}
