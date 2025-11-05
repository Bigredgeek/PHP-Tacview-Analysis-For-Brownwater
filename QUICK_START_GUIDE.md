# Performance Fix - Quick Implementation Guide

**Date:** November 5, 2025  
**Branch:** feature/performance-investigation  
**Related Docs:** PERFORMANCE_ANALYSIS.md, SOLUTION_OPTIONS.md

This is a quick-start guide for implementing the recommended performance fix. For detailed analysis and alternative solutions, see the related documentation.

---

## TL;DR - What's the Problem?

Users report **15-23 second page loads** on mobile devices and **5-8.5 seconds** on desktop. 

**Root Cause:** The EventGraph aggregator processes 5MB+ of XML files at runtime on every page request with no caching.

**Solution:** Pre-process files during build, serve cached results → **95% faster** (0.5-1s load time).

---

## Recommended Fix: Build-Time Pre-Processing

### Why This Solution?

- ✅ **95% faster** page loads (15-23s → 0.5-1s)
- ✅ **Simple** to implement (1-2 days)
- ✅ **Proven** approach (used by many static site generators)
- ✅ **Minimal** code changes
- ✅ **Compatible** with Vercel deployment
- ✅ **Graceful** fallback to runtime processing

### Implementation Steps

#### 1️⃣ Create Pre-Processing Script (20 min)

Create `scripts/preprocess-debriefings.php`:

```php
<?php
declare(strict_types=1);

// Bootstrap
$rootDir = dirname(__DIR__);
require_once $rootDir . '/config.php';
require_once $rootDir . '/src/core_path.php';
$corePath = tacview_resolve_core_path($config['core_path'] ?? 'php-tacview-core', $rootDir);
require_once $corePath . '/tacview.php';
require_once $rootDir . '/src/EventGraph/autoload.php';

use EventGraph\EventGraphAggregator;

// Find XML files
$debriefingsGlob = $rootDir . '/' . ltrim($config['debriefings_path'], '/');
$xmlFiles = glob($debriefingsGlob) ?: [];

if (empty($xmlFiles)) {
    echo "No XML files found\n";
    exit(0);
}

echo "Processing " . count($xmlFiles) . " files...\n";

// Aggregate
$aggregator = new EventGraphAggregator($config['default_language'], $config['aggregator'] ?? []);
foreach ($xmlFiles as $file) {
    echo "  - " . basename($file) . "\n";
    $aggregator->ingestFile($file);
}

$mission = $aggregator->toAggregatedMission();

// Save cache
$cache = [
    'version' => '1.0',
    'generated' => time(),
    'mission' => [
        'name' => $mission->getMissionName(),
        'startTime' => $mission->getStartTime(),
        'duration' => $mission->getDuration(),
        'events' => $mission->getEvents(),
        'sources' => $mission->getSources(),
    ],
    'metrics' => $aggregator->getMetrics(),
];

$outputDir = $rootDir . '/public/debriefings';
if (!is_dir($outputDir)) {
    mkdir($outputDir, 0755, true);
}

file_put_contents($outputDir . '/aggregated-cache.json', json_encode($cache, JSON_PRETTY_PRINT));
echo "✅ Cache generated\n";
```

#### 2️⃣ Modify debriefing.php (15 min)

Add this near the top of `debriefing.php` (after config loading, before XML processing):

```php
// Check for pre-aggregated cache
$cacheFile = __DIR__ . '/public/debriefings/aggregated-cache.json';

if (is_file($cacheFile)) {
    $cache = json_decode(file_get_contents($cacheFile), true);
    
    if ($cache && isset($cache['mission'])) {
        // Use cached data
        $tv->proceedAggregatedStats(
            $cache['mission']['name'],
            $cache['mission']['startTime'],
            $cache['mission']['duration'],
            $cache['mission']['events']
        );
        echo $tv->getOutput();
        
        // Display cache info
        $statusMessages = "<div style='margin-top: 40px; padding: 20px;'>";
        $statusMessages .= "<p>⚡ Loaded from cache (generated: " . date('Y-m-d H:i', $cache['generated']) . ")</p>";
        $statusMessages .= "</div>";
        echo $statusMessages;
        
        // Skip runtime processing
        goto skip_runtime;
    }
}

// ... existing runtime aggregation code ...

skip_runtime:
```

#### 3️⃣ Update package.json (5 min)

```json
{
  "scripts": {
    "build": "node scripts/fetch-core.js && php scripts/preprocess-debriefings.php",
    "build:debriefings": "php scripts/preprocess-debriefings.php"
  }
}
```

#### 4️⃣ Update .gitignore (2 min)

```gitignore
# Pre-processed cache (regenerated during build)
public/debriefings/aggregated-cache.json
public/debriefings/cache-meta.json
```

#### 5️⃣ Test Locally (10 min)

```bash
# Generate cache
npm run build

# Start server
php -S localhost:8000

# Open browser, check page loads quickly
# Look for "⚡ Loaded from cache" message
```

#### 6️⃣ Deploy (Automatic)

Vercel will automatically run `npm run build` and deploy with cache.

---

## Testing Checklist

- [ ] Cache file generated: `public/debriefings/aggregated-cache.json`
- [ ] Cache contains expected data structure
- [ ] Page loads quickly with cache (< 1s)
- [ ] Page displays "⚡ Loaded from cache" indicator
- [ ] Fallback works (delete cache, page still loads)
- [ ] Rebuild generates new cache
- [ ] Vercel deployment includes cache

---

## Verification

### Before Fix:
```bash
time curl http://localhost:8000/debriefing.php > /dev/null
# Expected: 5-10 seconds
```

### After Fix:
```bash
npm run build
time curl http://localhost:8000/debriefing.php > /dev/null
# Expected: < 1 second
```

### Performance Measurement:
```javascript
// Add to page for monitoring
window.addEventListener('load', () => {
    const loadTime = performance.timing.domContentLoadedEventEnd - performance.timing.navigationStart;
    console.log('Page load time:', loadTime, 'ms');
});
```

---

## Rollback Plan

If issues occur:

1. **Disable cache in debriefing.php:**
   ```php
   $cacheFile = null; // Force runtime processing
   ```

2. **Remove cache files:**
   ```bash
   rm public/debriefings/aggregated-cache.json
   ```

3. **Revert commits:**
   ```bash
   git revert HEAD
   git push
   ```

Runtime aggregation will still work as fallback.

---

## Expected Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Mobile Page Load | 15-23s | 0.5-1s | **95% faster** |
| Desktop Page Load | 5-8.5s | 0.2-0.5s | **94% faster** |
| Memory Usage | 37MB | 5MB | **86% less** |
| Time to Interactive | 15-23s | 0.5-1s | **95% faster** |

---

## Future Enhancements

After this fix is deployed and stable:

1. **Add Progressive Loading** (Solution 4)
   - Load summary first
   - Lazy-load event details
   - Better UX

2. **Optimize Algorithm** (Solution 3)
   - Reduce complexity for dynamic files
   - Use indexed lookups
   - Memory optimization

3. **Smart Invalidation**
   - Auto-detect file changes
   - Regenerate cache on upload
   - Background processing

---

## Support & Questions

- 📖 Full Analysis: `PERFORMANCE_ANALYSIS.md`
- 🔧 All Solutions: `SOLUTION_OPTIONS.md`
- 📝 Implementation: This file

---

## Summary

**Time to Implement:** ~1 hour active work  
**Impact:** 95% faster page loads  
**Risk:** Low (has fallback)  
**Complexity:** Low  
**Recommended:** ✅ Yes

**One-Liner:** Pre-process debriefings at build time, serve cached results.

---

**Status:** Ready to implement  
**Approval:** Awaiting team decision
