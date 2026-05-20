#!/usr/bin/env node
// Export Utility v0.1.0
// Standalone script to export data

import path from 'path';
import { fileURLToPath } from 'url';
import * as storage from './storage.js';
import settings from '../config/settings.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function main() {
  const args = process.argv.slice(2);
  const format = args[0] || 'both';
  
  console.log('Export Utility v0.1.0');
  console.log('');
  
  storage.initialize();
  
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 19);
  const outputDir = path.resolve(__dirname, '..', settings.paths.outputDir);
  
  if (format === 'json' || format === 'both') {
    const jsonPath = path.join(outputDir, `jobs_${timestamp}.json`);
    storage.exportToJson(jsonPath);
  }
  
  if (format === 'csv' || format === 'both') {
    const csvPath = path.join(outputDir, `jobs_${timestamp}.csv`);
    storage.exportToCsv(csvPath);
  }
  
  // Print stats
  const stats = storage.getStats();
  console.log('');
  console.log('Database Statistics:');
  console.log(`  Total Jobs: ${stats.totalJobs}`);
  console.log(`  Total URLs: ${stats.totalUrls}`);
  
  storage.close();
}

main();
