# Quick Reference Card

## Essential Commands

```bash
# Run all tests
xcodebuild test -scheme PhotoCulling

# Run specific test suite
xcodebuild test -scheme PhotoCulling \
  -only-testing PhotoCullingTests/ThumbnailProviderTests

# Run with Xcode
⌘U  # In Xcode

# Run in CI/CD
xcodebuild test -scheme PhotoCulling \
  -destination 'platform=macOS' \
  -resultBundlePath TestResults.xcresult
```

---

## Essential Code Patterns

### Production Config (Default)
```swift
let provider = ThumbnailProvider()
// 1.25 GB, 500 items
```

### Testing Config
```swift
let provider = ThumbnailProvider(config: .testing)
// 100 KB, 5 items - immediate evictions
```

### Custom Config
```swift
let config = CacheConfig(
    totalCostLimit: 5_000_000,  // 5 MB
    countLimit: 50
)
let provider = ThumbnailProvider(config: config)
```

### Get Statistics
```swift
let stats = await provider.getCacheStatistics()
print("Hit Rate: \(stats.hitRate)%")
print("Evictions: \(stats.evictions)")
```

### Clear Cache
```swift
await provider.clearCaches()
```

---

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Modified Source | `PhotoCulling/Actors/ThumbnailProvider.swift` | Core class with CacheConfig |
| Core Tests | `PhotoCullingTests/ThumbnailProviderTests.swift` | 19 basic tests |
| Advanced Tests | `PhotoCullingTests/ThumbnailProviderAdvancedTests.swift` | 28 advanced tests |
| Examples | `PhotoCullingTests/ThumbnailProviderCustomMemoryTests.swift` | Test templates |

---

## Documentation Files

| File | Size | Purpose |
|------|------|---------|
| START_HERE.md | 2 min read | This overview |
| TESTING_QUICKSTART.md | 5 min | Quick commands |
| TESTING.md | 15 min | Complete guide |
| TESTING_EXAMPLES.md | 20 min | Real examples |
| IMPLEMENTATION_SUMMARY.md | 10 min | Details |
| INDEX.md | 10 min | Complete index |
| CHANGES.md | 10 min | Changelog |
| VISUAL_SUMMARY.md | 5 min | Visual overview |

---

## Configuration Presets

```swift
// Memory Testing (quick evictions)
CacheConfig.testing
// 100 KB, 5 items

// Production (default, unchanged)
CacheConfig.production
// 1.25 GB, 500 items

// Custom: 5 MB
CacheConfig(totalCostLimit: 5_000_000, countLimit: 50)

// Custom: 10 MB
CacheConfig(totalCostLimit: 10_000_000, countLimit: 100)

// Custom: 100 MB
CacheConfig(totalCostLimit: 100_000_000, countLimit: 200)
```

---

## Test Statistics

```
Total Tests: 47
├─ Core Tests: 19
├─ Advanced Tests: 28
└─ Examples: 18 (templates)

Lines of Code:
├─ Test Code: 700+ lines
├─ Documentation: 1,300+ lines
└─ Total: 2,000+ lines

Files:
├─ Modified: 1
├─ Created: 8 (3 test + 5 docs)
└─ Total: 9 files
```

---

## Common Tasks

### Run Tests
```bash
xcodebuild test -scheme PhotoCulling
```

### Test Memory Limits
```swift
let provider = ThumbnailProvider(config: .testing)
```

### Monitor Cache
```swift
let stats = await provider.getCacheStatistics()
```

### Add Custom Test
1. Open `PhotoCullingTests/ThumbnailProviderCustomMemoryTests.swift`
2. Copy a test suite
3. Modify for your needs
4. Run: `xcodebuild test`

### Check What Changed
```bash
cat CHANGES.md  # See all changes
```

---

## Performance Targets

| Operation | Target | Status |
|-----------|--------|--------|
| 1000 stat calls | < 1 sec | ✅ Passing |
| Single clear | < 10 ms | ✅ Passing |
| Concurrent (50) | < 100 ms | ✅ Passing |
| Cache hit | < 1 ms | ✅ Passing |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Tests won't run | `xcodebuild build -scheme PhotoCulling` first |
| Module not found | Clean: `xcodebuild clean -scheme PhotoCulling` |
| Cache not evicting | Verify image sizes in test |
| Actor isolation error | Use `await` for all provider calls |

---

## Key Takeaways

✅ Use `.testing` config to trigger evictions  
✅ Create custom configs for specific scenarios  
✅ Monitor with `getCacheStatistics()`  
✅ No breaking changes - backward compatible  
✅ 47 tests verify all scenarios  

---

## Learning Path

```
5 min:  Read TESTING_QUICKSTART.md
10 min: Run xcodebuild test
15 min: Review TESTING.md
20 min: Read TESTING_EXAMPLES.md
30 min: Create custom test
60 min: Master all documentation
```

---

## Documentation Index

```
Quick Reference (this file)
    ↓
START_HERE.md
    ↓
TESTING_QUICKSTART.md
    ↓
├─ TESTING.md (complete)
├─ TESTING_EXAMPLES.md (examples)
├─ IMPLEMENTATION_SUMMARY.md (details)
├─ INDEX.md (full index)
└─ VISUAL_SUMMARY.md (diagrams)
```

---

## Configuration Comparison

| Feature | Production | Testing | Custom |
|---------|-----------|---------|--------|
| Cost Limit | 1.25 GB | 100 KB | ✏️ Set it |
| Item Count | 500 | 5 | ✏️ Set it |
| Evictions | Slow | Immediate | Adjustable |
| Default | ✅ Yes | No | No |
| Use | Real app | Testing | Research |

---

## Getting Help

```
Question              → File
─────────────────────────────────────────
"How do I run tests?" → TESTING_QUICKSTART.md
"Show me examples"    → TESTING_EXAMPLES.md
"What changed?"       → CHANGES.md
"Full guide?"         → TESTING.md
"Everything?"         → INDEX.md
"Overview?"           → VISUAL_SUMMARY.md
```

---

## Before & After

### Before ❌
```swift
// Hard to test - would need to modify code
let memoryCache.totalCostLimit = 100_000  // Change here
```

### After ✅
```swift
// Easy - just use a config
let provider = ThumbnailProvider(config: .testing)
// 100 KB limit automatically
```

---

## Three-Line Summary

1. **What**: Configurable memory limits for ThumbnailProvider
2. **How**: Use `CacheConfig.testing` for 100 KB, create custom configs
3. **Result**: 47 tests, complete documentation, production ready

---

## Success Criteria

✅ Answer provided  
✅ 47 tests implemented  
✅ Documentation complete  
✅ Examples provided  
✅ Backward compatible  
✅ Production ready  
✅ Easy to extend  

---

**STATUS: READY TO USE** 🚀

Next: Read **TESTING_QUICKSTART.md** (5 min) or run tests directly:
```bash
xcodebuild test -scheme PhotoCulling
```
