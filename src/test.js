#!/usr/bin/env node
// Test Script v0.1.0
// Quick functionality test

import * as browser from './browser.js';
import { extract, getSupportedSites } from './extractor.js';

async function test() {
  console.log('Job Scraper Test v0.1.0');
  console.log('');
  console.log('Supported sites:', getSupportedSites().join(', '));
  console.log('');

  // Test URL - replace with a real job posting URL
  const testUrl = process.argv[2];
  
  if (!testUrl) {
    console.log('Usage: node src/test.js <url>');
    console.log('');
    console.log('Example:');
    console.log('  node src/test.js "https://www.indeed.com/viewjob?jk=abc123"');
    process.exit(0);
  }

  console.log('Testing URL:', testUrl);
  console.log('');

  try {
    await browser.initialize();
    
    const result = await extract(testUrl);
    
    console.log('');
    console.log('═'.repeat(60));
    console.log('RESULT');
    console.log('═'.repeat(60));
    console.log('');
    console.log('Success:', result.success);
    console.log('Site:', result.site);
    console.log('Duration:', result.duration, 'ms');
    
    if (result.error) {
      console.log('Error:', result.error);
    }
    
    if (result.data) {
      console.log('');
      console.log('Extracted Data:');
      console.log('  Title:', result.data.title || '(not found)');
      console.log('  Company:', result.data.company || '(not found)');
      console.log('  Location:', result.data.location || '(not found)');
      console.log('  Salary:', result.data.salary || '(not found)');
      console.log('  Job Type:', result.data.jobType || '(not found)');
      console.log('  Posted:', result.data.postedDate || '(not found)');
      
      if (result.data.description) {
        console.log('  Description:', result.data.description.substring(0, 200) + '...');
      }
    }
    
    console.log('');
    console.log('Memory:', browser.getMemoryUsage());
    
  } catch (err) {
    console.error('Test failed:', err);
  } finally {
    await browser.shutdown();
  }
}

test();
