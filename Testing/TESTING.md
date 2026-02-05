# ThumbnailProvider Testing Guide

## Overview

The `ThumbnailProvider` now includes comprehensive test coverage using Swift Testing framework. Tests cover:

- **Memory limit testing** with configurable cache limits
- **Cache statistics** tracking and validation
- **Concurrency safety** with actor isolation
- **Performance benchmarks** for cache operations
- **Integration tests** for multi-operation workflows

## Key Changes to ThumbnailProvider

### CacheConfig Structure

A new `CacheConfig` struct enables configurable memory limits for testing:

```swift
struct CacheConfig {
    let totalCostLimit: Int
    let countLimit: Int
    
    static let production = CacheConfig(
        totalCostLimit: 200 * 2560 * 2560,  // 1.25 GB
        countLimit: 500
    )
    
    static let testing = CacheConfig(
        totalCostLimit: 100_000,  // Very small for evictions
        countLimit: 5
    )
}
```

### Initialization

The `ThumbnailProvider` initializer now accepts configuration:

```swift
// Production use (default)
let provider = ThumbnailProvider()

// Testing with small limits
let provider = ThumbnailProvider(config: .testing)

// Custom configuration
let config = CacheConfig(totalCostLimit: 50_000, countLimit: 3)
let provider = ThumbnailProvider(config: config)
```

## Running Tests

### Run All Tests
```bash
xcodebuild test -scheme PhotoCulling
```

### Run Specific Test Suite
```bash
xcodebuild test -scheme PhotoCulling -only-testing PhotoCullingTests/ThumbnailProviderTests
```

### Run Performance Tests Only
```bash
xcodebuild test -scheme PhotoCulling -only-testing PhotoCullingTests/ThumbnailProviderPerformanceTests
```

### Run with Xcode
1. Open PhotoCulling.xcodeproj
2. Select Product → Test (⌘U)
3. Or click the test diamond next to test functions

## Test Categories

### 1. Initialization Tests
- `testProductionConfigInitialization` - Default config is production
- `testCustomConfigInitialization` - Custom config accepted

### 2. Cache Statistics Tests
- `testCacheHitRate` - Hit rate calculation
- `testStatisticsResetAfterClear` - Statistics reset on clear

### 3. Memory Limit Tests
- `testCountLimit` - Cache respects item count limit
- `testCostLimit` - Cache respects byte cost limit

### 4. Cache Lookup Tests
- `testThumbnailMissingFile` - Graceful handling of missing files

### 5. Clear Cache Tests
- `testClearCaches` - Cache clearing resets statistics

### 6. Preload Catalog Tests
- `testPreloadCatalogInitiation` - Preload mechanism works

### 7. Concurrency Tests
- `testConcurrentAccess` - Multiple concurrent requests handled safely

### 8. Configuration Tests
- `testProductionConfigLimits` - Production limits correct
- `testTestingConfigLimits` - Testing limits correct

### 9. Thread Safety Tests
- `testActorIsolation` - Actor properly isolates state

### 10. Performance Tests
- `testStatisticsPerformance` - 1000 stat calls < 1 second
- `testClearCachesPerformance` - Cache clearing completes promptly

### 11. Integration Tests
- `testMultipleOperationsSequence` - Multiple operations work correctly
- `testInstanceIsolation` - Separate instances maintain isolation

## Testing Memory Limits

### Method 1: Using Testing Config
The easiest way to test memory limits:

```swift
let provider = ThumbnailProvider(config: .testing)
// Now provider has:
// - totalCostLimit: 100,000 bytes
// - countLimit: 5 items
```

With these small limits, you can observe eviction behavior by adding many images.

### Method 2: Custom Configuration
For specific memory limit scenarios:

```swift
let config = CacheConfig(
    totalCostLimit: 5_000_000,    // 5 MB
    countLimit: 10
)
let provider = ThumbnailProvider(config: config)
```

### Method 3: Memory Pressure Simulation
Monitor evictions via the `CacheDelegate`:

```swift
let stats = await provider.getCacheStatistics()
print("Cache Hit Rate: \(stats.hitRate)%")
print("Evictions: \(stats.evictions)")
```

## Test Utilities

### createTestImage()
Creates test NSImage for use in tests:

```swift
// Create 100x100 red image
let image = createTestImage()

// Create custom size image
let image = createTestImage(width: 256, height: 256)
```

## Advanced Testing

### Adding Cache Introspection Tests
To test actual cache contents, you can extend `ThumbnailProvider` with debug methods:

```swift
#if DEBUG
extension ThumbnailProvider {
    func getDebugCacheInfo() -> (itemCount: Int, totalCost: Int) {
        // Return cache internals for testing
    }
}
#endif
```

### Performance Baseline
Establish baseline performance for your system:

```swift
// Run this to establish baseline
let provider = ThumbnailProvider(config: .testing)
let startTime = Date()
for i in 0..<10000 {
    let _ = await provider.getCacheStatistics()
}
print("10000 calls took: \(Date().timeIntervalSince(startTime))s")
```

## Continuous Integration

For CI/CD pipelines, use:

```bash
xcodebuild test \
  -scheme PhotoCulling \
  -destination 'platform=macOS' \
  -resultBundlePath TestResults.xcresult \
  -derivedDataPath build
```

## Troubleshooting

### Tests Fail with "Module not found"
Ensure PhotoCulling target is built before running tests:
```bash
xcodebuild build -scheme PhotoCulling
xcodebuild test -scheme PhotoCulling
```

### Actor Isolation Warnings
Swift Testing respects actor isolation. All calls to `ThumbnailProvider` methods must be awaited in async context.

### Cache Not Evicting in Tests
If cache isn't evicting with small limits:
1. Verify test image sizes
2. Check `DiscardableThumbnail.cost` calculation
3. Monitor eviction logs via Logger

## Best Practices

1. **Always use `.testing` config in tests**
   ```swift
   let provider = ThumbnailProvider(config: .testing)
   ```

2. **Clean up in between tests** if needed
   ```swift
   await provider.clearCaches()
   ```

3. **Test isolation** - Create new instances per test to avoid state bleed

4. **Verify statistics** after operations
   ```swift
   let stats = await provider.getCacheStatistics()
   #expect(stats.hits >= 0)
   ```

## Performance Targets

- Cache statistics: < 1ms per call
- Clear operation: < 10ms
- Stats calculation: < 100μs
- Eviction detection: Automatic via NSCache delegate
