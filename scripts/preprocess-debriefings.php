<?php
declare(strict_types=1);

/**
 * Debriefing Pre-Processor
 * 
 * This script aggregates all Tacview XML files during build time
 * and generates a cached JSON representation for fast loading.
 */

// Bootstrap
$rootDir = dirname(__DIR__);
$config = require_once $rootDir . '/config.php';
require_once $rootDir . '/src/core_path.php';

$corePath = tacview_resolve_core_path($config['core_path'] ?? 'php-tacview-core', $rootDir);
require_once $corePath . '/tacview.php';

$eventGraphAutoloadCandidates = [
	$rootDir . '/src/EventGraph/autoload.php',
	$rootDir . '/public/src/EventGraph/autoload.php',
];

$eventGraphAutoloadPath = null;
foreach ($eventGraphAutoloadCandidates as $candidate) {
	if (is_file($candidate)) {
		$eventGraphAutoloadPath = $candidate;
		break;
	}
}

if ($eventGraphAutoloadPath === null) {
	echo "❌ Unable to locate EventGraph autoloader. Checked:\n";
	foreach ($eventGraphAutoloadCandidates as $candidate) {
		echo "   - $candidate\n";
	}
	exit(1);
}

require_once $eventGraphAutoloadPath;

use EventGraph\EventGraphAggregator;

// Configuration
$debriefingsGlob = $rootDir . '/' . ltrim($config['debriefings_path'], '/');
$publicDebriefingsDir = $rootDir . '/public/debriefings';
$cacheFile = $publicDebriefingsDir . '/aggregated-cache.json';
$metaFile = $publicDebriefingsDir . '/cache-meta.json';

// Ensure output directory exists
if (!is_dir($publicDebriefingsDir)) {
	mkdir($publicDebriefingsDir, 0755, true);
}

// Find all XML files
$xmlFiles = glob($debriefingsGlob) ?: [];

if (empty($xmlFiles)) {
	echo "⚠️  No XML files found in: $debriefingsGlob\n";
	echo "ℹ️  Cache not generated (no debriefings to process)\n";
	exit(0);
}

echo "🔍 Found " . count($xmlFiles) . " debriefing files\n";

// Calculate file hashes for cache invalidation
$fileHashes = [];
$totalSize = 0;
foreach ($xmlFiles as $file) {
	$fileHashes[basename($file)] = [
		'hash' => md5_file($file),
		'size' => filesize($file),
		'modified' => filemtime($file),
	];
	$totalSize += filesize($file);
}

echo "📊 Total data size: " . number_format($totalSize / 1024 / 1024, 2) . " MB\n";

// Always rebuild cache to ensure fresh data
echo "⚙️  Processing debriefings...\n";
$startTime = microtime(true);

// Create aggregator
$aggregatorOptions = $config['aggregator'] ?? [];
$aggregator = new EventGraphAggregator($config['default_language'], $aggregatorOptions);

// Ingest all files
foreach ($xmlFiles as $index => $filexml) {
	$fileName = basename($filexml);
	echo "  [" . ($index + 1) . "/" . count($xmlFiles) . "] Processing: $fileName\n";
	
	try {
		$aggregator->ingestFile($filexml);
	} catch (\Throwable $exception) {
		echo "  ⚠️  Failed to ingest $fileName: " . $exception->getMessage() . "\n";
	}
}

// Generate aggregated mission
echo "🔄 Aggregating events...\n";
$mission = $aggregator->toAggregatedMission();
$metrics = $aggregator->getMetrics();

// Prepare cache data
$cacheData = [
	'version' => '1.0',
	'generated' => time(),
	'generatedIso' => date('c'),
	'fileCount' => count($xmlFiles),
	'files' => array_keys($fileHashes),
	'mission' => [
		'name' => $mission->getMissionName(),
		'startTime' => $mission->getStartTime(),
		'duration' => $mission->getDuration(),
		'events' => $mission->getEvents(),
		'sources' => $mission->getSources(),
	],
	'metrics' => $metrics,
];

// Save cache
echo "💾 Writing cache files...\n";
file_put_contents($cacheFile, json_encode($cacheData, JSON_PRETTY_PRINT));
file_put_contents($metaFile, json_encode([
	'version' => '1.0',
	'generated' => time(),
	'fileHashes' => $fileHashes,
], JSON_PRETTY_PRINT));

$endTime = microtime(true);
$duration = round($endTime - $startTime, 2);

echo "\n";
echo "✅ Cache generation complete!\n";
echo "⏱️  Processing time: {$duration}s\n";
echo "📁 Cache file: " . basename($cacheFile) . " (" . number_format(filesize($cacheFile) / 1024, 2) . " KB)\n";
echo "🎯 Events aggregated: " . count($cacheData['mission']['events']) . "\n";
echo "📊 Metrics:\n";
echo "   - Raw events: " . ($metrics['raw_event_count'] ?? 0) . "\n";
echo "   - Merged events: " . ($metrics['merged_events'] ?? 0) . "\n";
echo "   - Duplicates suppressed: " . ($metrics['duplicates_suppressed'] ?? 0) . "\n";
echo "\n";
echo "🚀 Deployment ready - clients will load cached data\n";
