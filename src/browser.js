// Browser Manager v0.1.0
// Memory-conscious Chromium management

import { chromium } from 'playwright';
import settings from '../config/settings.js';

let browser = null;
let context = null;

export async function initialize() {
  if (browser) {
    console.log('[Browser] Already initialized');
    return;
  }

  console.log('[Browser] Launching Chromium with memory-optimized settings...');
  
  browser = await chromium.launch({
    headless: true,
    args: settings.browser.launchArgs
  });

  context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    bypassCSP: true,
    ignoreHTTPSErrors: true
  });

  console.log('[Browser] Ready');
}

export async function getPage() {
  if (!context) {
    throw new Error('Browser not initialized. Call initialize() first.');
  }

  const page = await context.newPage();

  // Set up request interception for resource blocking
  await page.route('**/*', (route) => {
    const request = route.request();
    const resourceType = request.resourceType();
    const url = request.url();

    // Block by resource type
    if (settings.blocking.resourceTypes.includes(resourceType)) {
      return route.abort();
    }

    // Block by URL pattern
    for (const pattern of settings.blocking.urlPatterns) {
      const regex = new RegExp(pattern.replace(/\*/g, '.*'));
      if (regex.test(url)) {
        return route.abort();
      }
    }

    return route.continue();
  });

  // Set timeouts
  page.setDefaultTimeout(settings.browser.navigationTimeout);
  page.setDefaultNavigationTimeout(settings.browser.navigationTimeout);

  return page;
}

export async function closePage(page) {
  if (page) {
    try {
      await page.close();
    } catch (err) {
      console.log('[Browser] Page already closed');
    }
  }
}

export async function shutdown() {
  console.log('[Browser] Shutting down...');
  
  if (context) {
    try {
      await context.close();
    } catch (err) {
      // Ignore
    }
    context = null;
  }

  if (browser) {
    try {
      await browser.close();
    } catch (err) {
      // Ignore
    }
    browser = null;
  }

  console.log('[Browser] Closed');
}

export function getMemoryUsage() {
  const used = process.memoryUsage();
  return {
    heapUsed: Math.round(used.heapUsed / 1024 / 1024),
    heapTotal: Math.round(used.heapTotal / 1024 / 1024),
    external: Math.round(used.external / 1024 / 1024),
    rss: Math.round(used.rss / 1024 / 1024)
  };
}
