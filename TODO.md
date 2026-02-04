# PhotoCulling - TODO & Recommendations

This document consolidates all recommendations from the quality analysis and technical reviews.

---

## Caching System Improvements

### Memory Cache Analysis

When scanning 500 RAW files with the current settings:

```swift
memoryCache.totalCostLimit = 200 * 2560 * 2560 // 1.25 GB
memoryCache.countLimit = 500
```

**Current Behavior:**
- NSCache will **silently evict older entries** when either limit is exceeded
- The `totalCostLimit` (1.25 GB) is the real bottleneck, likely hit before the 500-item count limit
- When full, NSCache removes least-recently-used items automatically
- Evicted thumbnails are no longer in memory but still on disk
- Subsequent requests will reload from disk (slower) or re-extract (slowest)

### Disk Cache Limitations

The current `DiskCacheManager` has no explicit size limits:

- **No size limit**: Cache could grow indefinitely
- **No eviction policy**: Old thumbnails aren't automatically removed unless you call `pruneCache()`
- **Prune only by age**: Current `pruneCache()` only removes files older than 30 days, not by disk space usage
- **For 500 RAW files**: At ~200KB per JPEG thumbnail, you could accumulate ~100MB+ without cleanup

### Recommended Updates

#### Issue A: Memory cache not using DiscardableThumbnail cost effectively
- [x] Review `DiscardableThumbnail` implementation to ensure `cost` property reflects actual image data size
- [x] Verify cost calculation in memory cache storage
- [x] Added cache statistics tracking (hits, misses, evictions)
- [x] Added CacheDelegate to monitor evictions
- [x] Improved cost calculation to account for all image representations

#### Issue B: No LRU disk cache eviction
- [ ] Implement total disk space limits for cache directory
- [ ] Add eviction policy for oldest files when disk limit exceeded
- [ ] Prevent unbounded disk growth on long-running sessions
- [ ] Add configuration for max disk cache size (suggest: 500MB default, configurable)

#### Issue C: Memory eviction strategy
- [ ] Monitor cache hit rates during large batch operations
- [ ] Consider two-tier approach: small previews in memory, full-resolution on demand
- [ ] Add metrics logging for memory cache hit/miss ratios

---

## 🔴 Critical (Do Immediately - Post v0.6.0)

### 1. Expand Automated Tests
- [ ] Increase unit test coverage for ViewModel, actors, and persistence logic
- [ ] Add integration and UI tests for critical workflows
- [ ] Add tests for caching behavior (memory full, disk full scenarios)
- [ ] **Why critical:** Prevents regressions, enables safe refactoring
- [ ] **Impact:** Increases confidence in future updates

### 2. Continue Error Handling Improvements
- [ ] Ensure all user-facing operations provide clear feedback
- [ ] Centralize alert logic for consistency
- [ ] Add error recovery for cache-related failures
- [ ] **Why critical:** Improves user trust and reliability

### 3. Document Architecture
- [ ] Create ARCHITECTURE.md with MVVM, actor, and caching strategy details
- [ ] Document the three-tier caching system (RAM → Disk → Generate)
- [ ] Expand API documentation for all public types and methods
- [ ] Document actor isolation patterns and thread safety
- [ ] **Why critical:** Accelerates onboarding, reduces bugs

---

## 🟡 High Priority (v0.6.1 - Next Sprint)

### 4. Input Validation
- [ ] Add file size checks before processing (recommend: reject >500MB files)
- [ ] Validate file extensions and paths
- [ ] Check memory availability for large operations
- [ ] Validate cache directory permissions and availability

### 5. Enhance Error Recovery
- [ ] Implement robust abort/cancel methods with proper task management
- [ ] Graceful handling of file system and I/O errors
- [ ] Recovery suggestions for common failures (disk full, permission denied, etc.)
- [ ] Add retry logic for transient failures

### 6. README Improvements
- [ ] Add usage instructions and workflow documentation
- [ ] Add feature list and screenshots
- [ ] Include roadmap and contribution guidelines

### 7. Caching Metrics & Monitoring
- [ ] Add instrumentation to track cache hit/miss rates
- [ ] Log memory cache evictions (when full)
- [ ] Log disk cache operations
- [ ] Add optional verbose logging mode for diagnostics

---

## 🟢 Medium Priority (v0.6.2+)

### 8. Type-Safe Identifiers
- [ ] Reduce stringly-typed code with enums for window IDs:
  ```swift
  enum WindowIdentifier: String {
      case main = "main-window"
      case zoomARW = "zoom-window-arw"
  }
  ```

- [ ] Create type-safe file type enumeration:
  ```swift
  enum SupportedFileType: String, CaseIterable {
      case arw
      case tiff, tif
      case jpeg, jpg
      
      var extensions: [String] {
          switch self {
          case .arw: return ["arw"]
          case .tiff: return ["tiff", "tif"]
          case .jpeg: return ["jpeg", "jpg"]
          }
      }
  }
  ```

- [ ] Create constants for thumbnail sizes:
  ```swift
  struct ThumbnailSize {
      static let grid = 100
      static let preview = 2560
      static let fullSize = 8700
  }
  ```

### 9. Performance Optimization for Large Catalogs
- [ ] Implement pagination or lazy loading for 1000+ files
- [ ] Use AsyncStream for incremental file loading
- [ ] Profile memory usage during batch operations
- [ ] Consider batch size limits for UI updates

### 10. Localization Preparation
- [ ] Extract all user-facing strings to localization files
- [ ] Plan localization strategy and supported languages
- [ ] Use NSLocalizedString throughout UI

### 11. Accessibility Improvements
- [ ] Add VoiceOver support
- [ ] Ensure keyboard navigation
- [ ] High contrast mode support
- [ ] Dynamic font size support

---

## 🔵 Low Priority (Future Enhancement)

### 12. Snapshot Tests
- [ ] Add SwiftUI snapshot tests for critical views
- [ ] Validate UI consistency across updates

### 13. Extended Performance Profiling
- [ ] Profile memory usage patterns over time
- [ ] Analyze CPU usage during large batch operations
- [ ] Benchmark different caching strategies

### 14. Bookmark Persistence
- [ ] Implement persistent folder bookmarks for seamless access across launches
- [ ] Store security-scoped bookmarks for user-selected folders

### 15. Advanced Security Features
- [ ] Add file size validation before processing
- [ ] Consider EXIF metadata stripping from extracted JPEGs for privacy
- [ ] Implement optional encryption for cached files

### 16. User Preference System
- [ ] Add settings for cache size limits
- [ ] Allow configuration of thumbnail quality
- [ ] Save user preferences (sort order, column widths, etc.)

---

## Tracking Completed Items

- [x] Sandbox Compliance (v0.6.0)
- [x] Security-scoped resource management (v0.6.0)
- [x] Initial XCTest target (v0.6.0)
- [x] Improved error handling (v0.6.0)
- [x] README improvements (v0.6.0)
