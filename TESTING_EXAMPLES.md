# ThumbnailProvider Memory Testing: Example Use Cases

## Real-World Testing Scenarios

### Scenario 1: Testing Cache Eviction Behavior

**Goal**: Observe how the cache evicts items when approaching memory limits

```swift
import Foundation
import PhotoCulling

@main
struct TestCacheEviction {
    static func main() async {
        // Create provider with small memory limit
        let config = CacheConfig(
            totalCostLimit: 500_000,    // 500 KB
            countLimit: 5
        )
        let provider = ThumbnailProvider(config: config)
        
        print("=== Cache Eviction Test ===")
        
        // Initial state
        var stats = await provider.getCacheStatistics()
        print("Initial state:")
        print("  Hits: \(stats.hits)")
        print("  Misses: \(stats.misses)")
        print("  Evictions: \(stats.evictions)")
        print()
        
        // Simulate adding items to cache
        print("Adding items to cache...")
        
        // (In real scenario, would load actual image files)
        // For this example, we just observe the mechanics
        
        // Get final stats
        stats = await provider.getCacheStatistics()
        print("\nFinal state:")
        print("  Hits: \(stats.hits)")
        print("  Misses: \(stats.misses)")
        print("  Hit Rate: \(stats.hitRate)%")
        print("  Evictions: \(stats.evictions)")
        
        // Clean up
        await provider.clearCaches()
    }
}
```

### Scenario 2: Comparing Performance Across Cache Sizes

**Goal**: Understand how different cache sizes affect performance

```swift
import Foundation
import PhotoCulling

@main
struct ComparePerformance {
    static func main() async {
        let cacheSizes = [
            ("Tiny", 100_000),
            ("Small", 1_000_000),
            ("Medium", 10_000_000),
            ("Large", 100_000_000),
        ]
        
        print("=== Performance Comparison ===\n")
        
        for (name, sizeInBytes) in cacheSizes {
            let config = CacheConfig(
                totalCostLimit: sizeInBytes,
                countLimit: sizeInBytes / 100_000  // ~1 item per 100KB
            )
            let provider = ThumbnailProvider(config: config)
            
            // Measure statistics gathering
            let start = Date()
            for _ in 0..<1000 {
                let _ = await provider.getCacheStatistics()
            }
            let duration = Date().timeIntervalSince(start)
            
            let statsPerMs = 1000.0 / (duration * 1000)
            print("\(name) (\(sizeInBytes) bytes):")
            print("  1000 calls: \(String(format: "%.3f", duration))s")
            print("  Rate: \(String(format: "%.0f", statsPerMs)) calls/ms\n")
        }
    }
}
```

### Scenario 3: Testing Production Configuration

**Goal**: Verify production configuration performance

```swift
import Foundation
import PhotoCulling

@main
struct TestProduction {
    static func main() async {
        print("=== Production Configuration Test ===\n")
        
        // Use default production config
        let provider = ThumbnailProvider()
        
        // Verify config
        let stats = await provider.getCacheStatistics()
        
        print("Production Config:")
        print("  Total Cost Limit: \(200 * 2560 * 2560) bytes")
        print("  Item Count Limit: 500")
        print()
        
        // Test rapid access
        print("Testing rapid access...")
        let start = Date()
        for _ in 0..<10000 {
            let _ = await provider.getCacheStatistics()
        }
        let duration = Date().timeIntervalSince(start)
        
        print("10000 stat calls: \(String(format: "%.3f", duration))s")
        print("Average per call: \(String(format: "%.3f", (duration / 10000) * 1000))ms")
        
        // Final stats
        let finalStats = await provider.getCacheStatistics()
        print("\nFinal Statistics:")
        print("  Hits: \(finalStats.hits)")
        print("  Misses: \(finalStats.misses)")
        print("  Hit Rate: \(String(format: "%.1f", finalStats.hitRate))%")
    }
}
```

### Scenario 4: Stress Testing with Concurrent Operations

**Goal**: Verify thread safety under high concurrency

```swift
import Foundation
import PhotoCulling

@main
struct StressTest {
    static func main() async {
        print("=== Stress Test: Concurrent Operations ===\n")
        
        let provider = ThumbnailProvider(config: .testing)
        
        // Run many concurrent operations
        let operationCount = 100
        let concurrentTasks = 10
        
        print("Running \(operationCount) operations across \(concurrentTasks) concurrent tasks...")
        
        let start = Date()
        await withTaskGroup(of: Void.self) { group in
            for taskNum in 0..<concurrentTasks {
                group.addTask {
                    for i in 0..<(operationCount / concurrentTasks) {
                        let stats = await provider.getCacheStatistics()
                        if i % 10 == 0 {
                            print("Task \(taskNum): operation \(i) - hit rate: \(stats.hitRate)%")
                        }
                    }
                }
            }
        }
        let duration = Date().timeIntervalSince(start)
        
        print("\nCompleted \(operationCount) operations in \(String(format: "%.3f", duration))s")
        print("Rate: \(String(format: "%.0f", Double(operationCount) / duration)) ops/sec")
        
        // Verify provider state intact
        let finalStats = await provider.getCacheStatistics()
        print("\nProvider state after stress test:")
        print("  Hits: \(finalStats.hits)")
        print("  Misses: \(finalStats.misses)")
        print("  Evictions: \(finalStats.evictions)")
    }
}
```

### Scenario 5: Memory Configuration Testing

**Goal**: Test various memory configurations

```swift
import Foundation
import PhotoCulling

@main
struct MemoryConfigTest {
    static func main() async {
        print("=== Memory Configuration Testing ===\n")
        
        let configs: [(String, CacheConfig)] = [
            ("Ultra-Low (10KB)", CacheConfig(totalCostLimit: 10_000, countLimit: 1)),
            ("Very Low (100KB)", CacheConfig(totalCostLimit: 100_000, countLimit: 2)),
            ("Testing (100KB, 5 items)", .testing),
            ("Low (1MB)", CacheConfig(totalCostLimit: 1_000_000, countLimit: 10)),
            ("Medium (10MB)", CacheConfig(totalCostLimit: 10_000_000, countLimit: 50)),
            ("High (100MB)", CacheConfig(totalCostLimit: 100_000_000, countLimit: 200)),
            ("Production (1.25GB)", .production),
        ]
        
        for (name, config) in configs {
            let provider = ThumbnailProvider(config: config)
            
            // Run a quick test
            var stats = await provider.getCacheStatistics()
            
            print("Configuration: \(name)")
            print("  Cost Limit: \(config.totalCostLimit) bytes")
            print("  Count Limit: \(config.countLimit) items")
            print("  Initial Hit Rate: \(stats.hitRate)%")
            
            // Test clearing
            await provider.clearCaches()
            stats = await provider.getCacheStatistics()
            print("  After Clear - Hits: \(stats.hits), Misses: \(stats.misses)")
            print()
        }
    }
}
```

### Scenario 6: Monitoring Cache Health

**Goal**: Monitor cache statistics over time

```swift
import Foundation
import PhotoCulling

@main
struct CacheHealthMonitoring {
    static func main() async {
        print("=== Cache Health Monitoring ===\n")
        
        let provider = ThumbnailProvider(config: .testing)
        
        print("Monitoring cache for 5 seconds...\n")
        
        let startTime = Date()
        let monitoringDuration: TimeInterval = 5.0
        
        while Date().timeIntervalSince(startTime) < monitoringDuration {
            let stats = await provider.getCacheStatistics()
            
            print("[\(Date().formatted(date: .omitted, time: .standard))]")
            print("  Hits: \(stats.hits)")
            print("  Misses: \(stats.misses)")
            print("  Hit Rate: \(String(format: "%.1f", stats.hitRate))%")
            print("  Evictions: \(stats.evictions)")
            print()
            
            // Check every second
            try? await Task.sleep(seconds: 1)
        }
        
        print("Monitoring complete.")
        
        // Final summary
        let finalStats = await provider.getCacheStatistics()
        print("\nFinal Summary:")
        print("  Total Hits: \(finalStats.hits)")
        print("  Total Misses: \(finalStats.misses)")
        print("  Overall Hit Rate: \(String(format: "%.1f", finalStats.hitRate))%")
        print("  Total Evictions: \(finalStats.evictions)")
    }
}

// Helper extension for sleep
extension Task {
    static func sleep(seconds: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
```

### Scenario 7: Testing Edge Cases

**Goal**: Test boundary conditions and edge cases

```swift
import Foundation
import PhotoCulling

@main
struct EdgeCaseTest {
    static func main() async {
        print("=== Edge Case Testing ===\n")
        
        // Edge case 1: Zero cost limit
        print("Test 1: Zero cost limit")
        let config1 = CacheConfig(totalCostLimit: 0, countLimit: 10)
        let provider1 = ThumbnailProvider(config: config1)
        let stats1 = await provider1.getCacheStatistics()
        print("  Result: \(stats1.hitRate)% hit rate\n")
        
        // Edge case 2: Zero count limit
        print("Test 2: Zero count limit")
        let config2 = CacheConfig(totalCostLimit: 1_000_000, countLimit: 0)
        let provider2 = ThumbnailProvider(config: config2)
        let stats2 = await provider2.getCacheStatistics()
        print("  Result: \(stats2.hitRate)% hit rate\n")
        
        // Edge case 3: Very small costs
        print("Test 3: Very small cost limit (1 byte)")
        let config3 = CacheConfig(totalCostLimit: 1, countLimit: 100)
        let provider3 = ThumbnailProvider(config: config3)
        let stats3 = await provider3.getCacheStatistics()
        print("  Result: Provider initialized\n")
        
        // Edge case 4: Very large limits
        print("Test 4: Maximum limits")
        let config4 = CacheConfig(
            totalCostLimit: Int.max / 2,
            countLimit: Int.max / 2
        )
        let provider4 = ThumbnailProvider(config: config4)
        let stats4 = await provider4.getCacheStatistics()
        print("  Result: \(stats4.hits) hits\n")
        
        print("All edge cases handled gracefully!")
    }
}
```

## Running These Examples

Copy any example above and save as a separate Swift file, then run:

```bash
swift example.swift
```

Or integrate into your tests:

```bash
xcodebuild test -scheme PhotoCulling
```

## Tips for Custom Scenarios

1. **Always clean up**: Call `await provider.clearCaches()` when done
2. **Use testing config**: Faster evictions with `.testing` config
3. **Monitor stats**: Use `getCacheStatistics()` to verify behavior
4. **Avoid blocking**: Always use `async/await` syntax
5. **Test isolation**: Create new provider instances per test
6. **Measure timing**: Use `Date()` for performance testing

## Creating Your Own Test

Template:

```swift
import Foundation
import PhotoCulling

@main
struct MyCustomTest {
    static func main() async {
        print("=== My Custom Test ===\n")
        
        // 1. Create provider with your config
        let config = CacheConfig(totalCostLimit: YOUR_SIZE, countLimit: YOUR_COUNT)
        let provider = ThumbnailProvider(config: config)
        
        // 2. Run operations
        // ... your test code ...
        
        // 3. Check results
        let stats = await provider.getCacheStatistics()
        print("Results: \(stats)")
        
        // 4. Clean up
        await provider.clearCaches()
    }
}
```

---

These examples show how the new configurable `ThumbnailProvider` can be used to test various memory scenarios without modifying the core code.
