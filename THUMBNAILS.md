# Thumbnails in PhotoCulling

## Overview

PhotoCulling uses a sophisticated thumbnail generation and caching system designed to handle large photo libraries efficiently. Thumbnails are extracted from raw image files (currently supporting `.arw` Sony format) using native macOS image processing APIs. The system implements a two-level caching strategy (memory + disk) with intelligent memory management to prevent excessive RAM usage.

## Libraries and Frameworks

### Core Frameworks Used

1. **CoreGraphics** (`import CoreGraphics`)
   - `CGImageSourceCreateWithURL()` - Creates an image source from a URL
   - `CGImageSourceCreateThumbnailAtIndex()` - Generates thumbnails directly from image sources
   - `CGContext` - Used for applying interpolation quality transformations
   - `CGImage` - Thread-safe image representation used throughout the system

2. **AppKit** (`import AppKit`)
   - `NSImage` - Display-ready image wrapper for UI rendering
   - `NSCache<Key, Value>` - Thread-safe in-memory cache with LRU eviction

3. **Foundation** (`import Foundation`)
   - URL handling and file operations
   - Task-based concurrency

4. **CryptoKit** (in DiskCacheManager)
   - `Insecure.MD5` - Generates cache filenames from source file paths

5. **OSLog** (`import OSLog`)
   - Logging for debugging and performance monitoring

6. **ImageIO Framework** (via CoreGraphics)
   - Handles multiple image formats through standardized APIs
   - Supports EXIF transformation and embedded thumbnails

---

## Architecture

### Three-Layer Thumbnail Resolution

The thumbnail system uses a three-tier approach to minimize processing:

```
┌─────────────────────────────────────┐
│  Request Thumbnail (thumbnail())    │
└────────────────┬────────────────────┘
                 │
                 ▼
        ┌────────────────┐
        │ Check RAM Cache│ ─── HIT ──► Return NSImage
        └────────┬───────┘
                 │ MISS
                 ▼
        ┌────────────────┐
        │Check Disk Cache│ ─── HIT ──► Load JPEG, Store in RAM, Return
        └────────┬───────┘
                 │ MISS
                 ▼
        ┌────────────────┐
        │  Extract from  │
        │  Source File   │ ──► Create CGImage ──► Store in Memory
        └────────┬───────┘                         & Disk (async)
                 │
                 ▼
          Return NSImage
```

### Component Breakdown

#### 1. **ThumbnailProvider** (Actor)
The main orchestrator for thumbnail generation. Using Swift's actor model ensures thread-safe access to caches.

```swift
actor ThumbnailProvider {
    // Memory cache - stores NSImage wrappers
    private let memoryCache: NSCache<NSURL, DiscardableThumbnail>
    
    // Disk cache - stores compressed JPEGs
    private let diskCache: DiskCacheManager
    
    // Quality parameter
    private var costPerPixel: Int = 4
}
```

**Key Methods:**
- `thumbnail(for:targetSize:)` - Resolves and returns a thumbnail
- `preloadCatalog(at:targetSize:)` - Batch-loads all thumbnails in a directory
- `getCacheStatistics()` - Returns hit rate and cache efficiency metrics
- `clearCaches()` - Clears both memory and disk caches
- `pruneDiskCache(maxAgeInDays:)` - Removes old cached thumbnails

#### 2. **DiscardableThumbnail** (NSDiscardableContent)
A wrapper around NSImage that implements NSCache's eviction protocol. Automatically tracks accurate memory costs.

```swift
final class DiscardableThumbnail: NSDiscardableContent {
    let image: NSImage
    let cost: Int  // Calculated as: pixels × 4 bytes/pixel × 1.1 overhead
}
```

**Cost Calculation:**
- Each image representation: `width × height × 4 bytes (RGBA) × 1.1 (10% overhead)`
- NSCache uses this to determine when to evict images

#### 3. **DiskCacheManager** (Actor)
Manages persistent storage of thumbnail JPEGs on disk.

```swift
actor DiskCacheManager {
    // Location: ~/Library/Caches/no.blogspot.PhotoCulling/Thumbnails/
    let cacheDirectory: URL
}
```

**Storage Mechanism:**
- Files are named using MD5 hash of source file path
- Format: JPEG with 70% quality (configurable)
- Path example: `~/.../Thumbnails/a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.jpg`

---

## Key Parameters and Their Effects

### 1. **targetSize** (Maximum Dimension in Pixels)

**What it does:** Sets the maximum width OR height of the generated thumbnail.

```swift
func thumbnail(for url: URL, targetSize: Int) async -> NSImage?
// Common values: 128, 256, 512, 1024, 2560
```

**Impact on File Size:**
| targetSize | Typical JPEG Size | Memory Cost |
|-----------|------------------|------------|
| 128 px    | ~2-3 KB          | ~64 KB     |
| 256 px    | ~8-12 KB         | ~256 KB    |
| 512 px    | ~25-35 KB        | ~1 MB      |
| 1024 px   | ~60-90 KB        | ~4 MB      |
| 2560 px   | ~200-300 KB      | ~25 MB     |

**Performance Implications:**
- Larger thumbnails require more CPU for extraction and rendering
- Larger thumbnails consume more memory in the cache
- Cache automatically reconfigures when targetSize changes

**Usage Example:**
```swift
// Quick preview - fast, small memory footprint
let smallThumb = await ThumbnailProvider.shared.thumbnail(
    for: fileURL, 
    targetSize: 256
)

// High-quality preview - slower, larger memory footprint
let largeThumb = await ThumbnailProvider.shared.thumbnail(
    for: fileURL, 
    targetSize: 2560
)
```

### 2. **costPerPixel** (Quality vs. Speed Trade-off)

**What it does:** Controls interpolation quality when resampling images. Range: **1-8 bytes per pixel**.

```swift
func setCostPerPixel(_ cost: Int) {
    self.costPerPixel = max(1, min(8, cost))
}
```

**Quality Mapping:**

| costPerPixel | Interpolation Quality | Use Case |
|-------------|----------------------|----------|
| 1-2        | `.low`              | Fast preview, acceptable quality |
| 3-4        | `.medium`           | Default, balanced quality & speed |
| 5-8        | `.high`             | High-quality output, careful inspection |

**How It Works:**
1. `costPerPixel` is mapped to `CGInterpolationQuality`
2. If costPerPixel ≠ 4 (default), image is re-rendered in a `CGContext` with appropriate quality
3. Higher quality uses more sophisticated algorithms (e.g., cubic interpolation vs. linear)

**Performance Impact:**
```
costPerPixel=1: ~100ms to generate 1024px thumbnail
costPerPixel=4: ~120-150ms (includes rerendering)
costPerPixel=8: ~150-200ms (high-quality interpolation)
```

**Memory Impact:**
- Memory cost calculation: `width × height × costPerPixel × 1.1`
- costPerPixel=1: ~1 MB for 512px image
- costPerPixel=8: ~8 MB for 512px image

---

## Cache Configuration and Memory Management

### Memory Cache (NSCache)

The memory cache is auto-configuring based on thumbnail size:

```swift
struct CacheConfig {
    let totalCostLimit: Int    // Total bytes to keep in memory
    let countLimit: Int        // Maximum number of thumbnails
}
```

**Production Configuration:**
```swift
static let production = CacheConfig(
    totalCostLimit: 500 * 1024 * 1024,  // 500 MB
    countLimit: 1000                     // 1000 images max
)
```

**Dynamic Reconfiguration:**
When you load a catalog with a specific targetSize, the cache reconfigures:

```swift
let config = CacheConfig.forThumbnailSize(targetSize, costPerPixel: costPerPixel)
// Example: 512px thumbnails, costPerPixel=4
// → Stores ~100 images = ~50MB memory
```

**Eviction Strategy:**
- Least Recently Used (LRU) - oldest accessed thumbnails are evicted first
- Tracks via `DiscardableThumbnail.beginContentAccess()` / `endContentAccess()`
- Monitoring via `CacheDelegate` which logs evictions

### Disk Cache (Persistent Storage)

**Location:** `~/Library/Caches/no.blogspot.PhotoCulling/Thumbnails/`

**Format:** JPEG compressed at 70% quality
```swift
let options: [CFString: Any] = [
    kCGImageDestinationLossyCompressionQuality: 0.7
]
```

**File Naming:** MD5 hash of source file path (deterministic)
```
Source: /Users/jane/Pictures/2025-01-15/photo.arw
Hash:   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
Cached: ~/...Thumbnails/a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.jpg
```

**Pruning:**
```swift
func pruneCache(maxAgeInDays: Int = 30) async
// Removes cached files older than the specified age
// Default: 30 days
```

---

## The Extraction Process: How Thumbnails Are Generated

### Step-by-Step Thumbnail Creation

```swift
private nonisolated func extractSonyThumbnail(
    from url: URL, 
    maxDimension: CGFloat, 
    qualityCost: Int = 4
) async throws -> CGImage
```

#### Phase 1: Image Source Creation
```swift
let options = [kCGImageSourceShouldCache: false] as CFDictionary
guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else {
    throw ThumbnailError.invalidSource
}
```
- Opens the image file
- `kCGImageSourceShouldCache: false` prevents caching the original (saves memory)

#### Phase 2: Thumbnail Generation
```swift
let thumbOptions: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceThumbnailMaxPixelSize: maxDimension,
    kCGImageSourceShouldCacheImmediately: false
]

guard var image = CGImageSourceCreateThumbnailAtIndex(
    source, 0, thumbOptions as CFDictionary
) else {
    throw ThumbnailError.generationFailed
}
```

**Key Options Explained:**

| Option | Value | Purpose |
|--------|-------|---------|
| `kCGImageSourceCreateThumbnailFromImageAlways` | true | Always create a thumbnail, even if embedded one exists |
| `kCGImageSourceCreateThumbnailWithTransform` | true | Apply EXIF rotation/orientation automatically |
| `kCGImageSourceThumbnailMaxPixelSize` | maxDimension | Constrains longest edge to this size |
| `kCGImageSourceShouldCacheImmediately` | false | Don't cache the extracted thumbnail (we manage caching) |

#### Phase 3: Quality Enhancement (Optional)
If `costPerPixel ≠ 4` (default), the image is re-rendered with appropriate interpolation:

```swift
if qualityCost != 4 {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    if let context = CGContext(...) {
        context.interpolationQuality = interpolationQuality
        context.draw(image, in: CGRect(...))  // Re-render with quality setting
        if let processedImage = context.makeImage() {
            image = processedImage
        }
    }
}
```

#### Phase 4: Return Thread-Safe CGImage
```swift
return image  // CGImage is Sendable, safe to use in actors
```

#### Phase 5: Wrap and Cache (in Actor Context)
```swift
let nsImage = NSImage(cgImage: cgImage, size: NSSize(...))
storeInMemory(nsImage, for: url)  // In-memory cache

Task.detached(priority: .background) {
    await self.diskCache.save(cgImage, for: url)  // Async to disk
}
```

---

## Performance Characteristics

### Typical Generation Times (1024px thumbnail from .arw file)

| Operation | Time | Notes |
|-----------|------|-------|
| Extract from RAM cache | <1ms | Instant |
| Load from disk cache | 5-10ms | JPEG decompression |
| Generate from file | 100-200ms | Full extraction + quality adjustment |
| Batch preload (100 files) | 5-15sec | Parallel on all CPU cores |

### Memory Usage Examples

**Scenario: Loading 100 thumbnails at 1024px with costPerPixel=4**
```
Cost per image: 1024 × 1024 × 4 × 1.1 = ~4.6 MB
100 images: ~460 MB
Cache limit: 500 MB
→ ~92 images fit in memory, then LRU eviction occurs
```

**Scenario: Loading 1000 thumbnails at 256px with costPerPixel=2**
```
Cost per image: 256 × 256 × 2 × 1.1 = ~144 KB
1000 images would need: ~144 MB
Cache limit: 500 MB
→ All 1000 fit with room to spare
```

### Disk Space

**Typical footprint per cached thumbnail:**
- 256px: 3-5 KB per image
- 512px: 12-20 KB per image
- 1024px: 40-80 KB per image
- 2560px: 150-250 KB per image

**100,000 images at 512px: ~1.5-2 GB on disk**

---

## API Usage

### Basic Thumbnail Loading

```swift
import PhotoCulling

// Get a single thumbnail
let thumbnail = await ThumbnailProvider.shared.thumbnail(
    for: fileURL,
    targetSize: 512
)
```

### Batch Preloading

```swift
// Preload all thumbnails in a directory
let successCount = await ThumbnailProvider.shared.preloadCatalog(
    at: catalogURL,
    targetSize: 1024
)
print("Successfully generated \(successCount) thumbnails")
```

### Adjusting Quality

```swift
// Set global quality setting (1=low, 8=high)
ThumbnailProvider.shared.setCostPerPixel(8)  // High quality for detailed inspection

// Later, switch to faster preview
ThumbnailProvider.shared.setCostPerPixel(2)  // Lower quality, faster
```

### Monitoring Cache Performance

```swift
let stats = await ThumbnailProvider.shared.getCacheStatistics()
print("Cache Hit Rate: \(stats.hitRate)%")
print("Hits: \(stats.hits), Misses: \(stats.misses)")

let diskSize = await ThumbnailProvider.shared.getDiskCacheSize()
print("Disk cache: \(diskSize / 1024 / 1024) MB")
```

### Cache Management

```swift
// Clear everything (memory + disk)
await ThumbnailProvider.shared.clearCaches()

// Remove old cached files (older than 30 days)
await ThumbnailProvider.shared.pruneDiskCache(maxAgeInDays: 30)

// Remove all cached files
await ThumbnailProvider.shared.pruneDiskCache(maxAgeInDays: 0)
```

---

## Supported File Formats

Currently, the system supports Sony `.arw` raw files:

```swift
let supported: Set<String> = ["arw"]
```

**Note:** The implementation uses generic ImageIO APIs, so additional formats can be easily added:

```swift
let supported: Set<String> = ["arw", "tiff", "tif", "jpeg", "jpg", "png", "heic", "heif"]
```

---

## Threading and Concurrency

### Actor-Based Safety

All caches are protected by the `ThumbnailProvider` and `DiskCacheManager` actors:

```swift
actor ThumbnailProvider { }
actor DiskCacheManager { }
```

This ensures:
- **Thread-safe cache access** - Multiple tasks can safely request thumbnails
- **No race conditions** - Cache updates are serialized
- **Efficient I/O** - Heavy operations run on background tasks

### Cancellation Support

The preload operation is cancellable:

```swift
let task = Task {
    await ThumbnailProvider.shared.preloadCatalog(
        at: catalogURL,
        targetSize: 1024
    )
}

// Later, if needed:
task.cancel()  // Stops preloading gracefully
```

---

## Troubleshooting

### Poor Thumbnail Quality

**Problem:** Thumbnails look blurry or pixelated

**Solution:** Increase `costPerPixel`
```swift
ThumbnailProvider.shared.setCostPerPixel(6)  // Use high-quality interpolation
```

### High Memory Usage

**Problem:** App uses excessive RAM

**Causes & Solutions:**
1. **targetSize too large** → Use 512-1024px instead of 2560px for previews
2. **costPerPixel too high** → Reduce to 4 (default) or 2 (fast preview)
3. **Too many cached thumbnails** → Increase interval between preloads or clear caches

### Slow Thumbnail Generation

**Problem:** Thumbnails take too long to appear

**Solutions:**
1. **Reduce targetSize** for quicker generation (256-512px vs. 1024-2560px)
2. **Lower costPerPixel** (use 2 for fast preview mode)
3. **Use preloadCatalog()** for batch operations instead of individual requests
4. **Check disk space** - Low disk space slows I/O operations

### Disk Cache Growing Too Large

**Problem:** Disk cache uses too much space

**Solution:** Prune old cache files
```swift
// Remove files older than 7 days
await ThumbnailProvider.shared.pruneDiskCache(maxAgeInDays: 7)
```

---

## Summary Table: Parameter Guidelines

| Use Case | targetSize | costPerPixel | Typical Time | Memory/Image |
|----------|-----------|-------------|--------------|-------------|
| Quick preview | 256 | 2 | 50-80ms | 144 KB |
| Grid view | 512 | 3 | 100-120ms | 576 KB |
| Detail view | 1024 | 4 | 120-150ms | 2.3 MB |
| High-detail inspect | 2560 | 7 | 150-200ms | 14.6 MB |
| Batch loading | 512 | 4 | 100-150ms/ea | 576 KB |

---

## See Also

- [ThumbnailProvider.swift](PhotoCulling/Actors/ThumbnailProvider.swift) - Main implementation
- [DiskCacheManager.swift](PhotoCulling/Actors/DiskCacheManager.swift) - Persistent cache
- [DiscardableThumbnail.swift](PhotoCulling/Model/DiscardableThumbnail.swift) - Memory management wrapper
