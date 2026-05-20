#!/usr/bin/env node
// Job Scraper v0.1.0
// Main entry point

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

import settings from '../config/settings.js';
import * as browser from './browser.js';
import * as storage from './storage.js';
import { extract } from './extractor.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// State
let isShuttingDown = false;
let currentUrl = null;
let stats = {
  processed: 0,
  success: 0,
  failed: 0,
  startTime: null
};

// Utility functions
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function formatDuration(ms) {
  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  
  if (hours > 0) {
    return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${seconds % 60}s`;
  }
  return `${seconds}s`;
}

function loadUrlsFromFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.log(`[Main] URL file not found: ${filePath}`);
    return [];
  }

  const content = fs.readFileSync(filePath, 'utf-8');
  const urls = content
    .split('\n')
    .map(line => line.trim())
    .filter(line => line && !line.startsWith('#') && line.startsWith('http'));

  console.log(`[Main] Loaded ${urls.length} URLs from ${filePath}`);
  return urls;
}

function printProgress() {
  const elapsed = Date.now() - stats.startTime;
  const rate = stats.processed > 0 ? (stats.processed / (elapsed / 1000 / 60)).toFixed(1) : 0;
  const successRate = stats.processed > 0 ? ((stats.success / stats.processed) * 100).toFixed(1) : 0;
  
  const mem = browser.getMemoryUsage();
  
  console.log('');
  console.log('─'.repeat(60));
  console.log(`Progress: ${stats.processed} processed | ${stats.success} success | ${stats.failed} failed`);
  console.log(`Rate: ${rate}/min | Success: ${successRate}% | Elapsed: ${formatDuration(elapsed)}`);
  console.log(`Memory: Heap ${mem.heapUsed}MB / ${mem.heapTotal}MB | RSS ${mem.rss}MB`);
  console.log('─'.repeat(60));
  console.log('');
}

function printFinalReport() {
  const elapsed = Date.now() - stats.startTime;
  const dbStats = storage.getStats();
  
  console.log('');
  console.log('═'.repeat(60));
  console.log('FINAL REPORT');
  console.log('═'.repeat(60));
  console.log('');
  console.log(`Duration: ${formatDuration(elapsed)}`);
  console.log(`Processed: ${stats.processed}`);
  console.log(`Success: ${stats.success}`);
  console.log(`Failed: ${stats.failed}`);
  console.log(`Success Rate: ${stats.processed > 0 ? ((stats.success / stats.processed) * 100).toFixed(1) : 0}%`);
  console.log('');
  console.log('Database Status:');
  console.log(`  Total URLs: ${dbStats.totalUrls}`);
  console.log(`  Total Jobs: ${dbStats.totalJobs}`);
  console.log('');
  console.log('URLs by Status:');
  for (const row of dbStats.urls) {
    console.log(`  ${row.status}: ${row.count}`);
  }
  console.log('');
  console.log('Jobs by Site:');
  for (const row of dbStats.jobs) {
    console.log(`  ${row.site}: ${row.count}`);
  }
  
  if (dbStats.recentErrors.length > 0) {
    console.log('');
    console.log('Recent Errors:');
    for (const err of dbStats.recentErrors) {
      console.log(`  ${err.url.substring(0, 50)}...`);
      console.log(`    ${err.error}`);
    }
  }
  
  console.log('');
  console.log('═'.repeat(60));
}

async function processUrl({ url, source_index }) {
  currentUrl = url;

  const result = await extract(url);

  // Log to database
  storage.logScrape(url, result.success, result.error, result.duration);

  if (result.success && result.data) {
    storage.saveJob({ ...result.data, source_index });
    storage.markProcessed(url, true);
    stats.success++;
  } else {
    storage.markProcessed(url, false, result.error);
    stats.failed++;
  }

  stats.processed++;
  currentUrl = null;

  return result;
}

async function runScraper() {
  stats.startTime = Date.now();
  
  console.log('');
  console.log('═'.repeat(60));
  console.log('JOB SCRAPER v0.1.0');
  console.log('═'.repeat(60));
  console.log(`Started: ${new Date().toISOString()}`);
  console.log('');

  // Initialize components
  console.log('[Main] Initializing...');
  storage.initialize();
  
  // Load URLs from file
  const inputPath = path.resolve(__dirname, '..', settings.paths.inputUrls);
  const fileUrls = loadUrlsFromFile(inputPath);
  
  if (fileUrls.length > 0) {
    storage.addUrls(fileUrls);
  }

  // Get pending URLs
  const pendingUrls = storage.getPendingUrls();
  
  if (pendingUrls.length === 0) {
    console.log('[Main] No URLs to process');
    storage.close();
    return;
  }

  console.log(`[Main] ${pendingUrls.length} URLs to process`);
  console.log('');

  // Initialize browser
  await browser.initialize();
  console.log('');

  // Process URLs
  for (const entry of pendingUrls) {
    if (isShuttingDown) {
      console.log('[Main] Shutdown requested, stopping...');
      break;
    }

    await processUrl(entry);

    // Print progress every N URLs
    if (stats.processed % settings.memory.checkInterval === 0) {
      printProgress();
      
      // Force garbage collection hint
      if (global.gc) {
        global.gc();
      }
    }

    // Delay between pages
    if (!isShuttingDown) {
      await sleep(settings.browser.delayBetweenPages);
    }
  }

  // Export results
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 19);
  const jsonPath = path.resolve(__dirname, '..', settings.paths.outputDir, `jobs_${timestamp}.json`);
  const csvPath = path.resolve(__dirname, '..', settings.paths.outputDir, `jobs_${timestamp}.csv`);
  
  storage.exportToJson(jsonPath);
  storage.exportToCsv(csvPath);

  // Final report
  printFinalReport();

  // Cleanup
  await browser.shutdown();
  storage.close();
  
  console.log('');
  console.log(`[Main] Completed at ${new Date().toISOString()}`);
}

// Graceful shutdown handler
async function shutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;
  
  console.log('');
  console.log(`[Main] Received ${signal}, shutting down gracefully...`);
  
  if (currentUrl) {
    console.log(`[Main] Waiting for current URL: ${currentUrl}`);
  }
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

// Handle uncaught errors
process.on('uncaughtException', async (err) => {
  console.error('[Main] Uncaught exception:', err);
  await browser.shutdown();
  storage.close();
  process.exit(1);
});

process.on('unhandledRejection', async (reason, promise) => {
  console.error('[Main] Unhandled rejection:', reason);
});

// Run
runScraper().catch(async (err) => {
  console.error('[Main] Fatal error:', err);
  await browser.shutdown();
  storage.close();
  process.exit(1);
});
