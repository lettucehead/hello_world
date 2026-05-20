// Job Scraper Configuration v0.1.0
// Optimized for 8GB RAM with ~400MB available

export default {
  // Browser settings - ultra conservative for memory constraints
  browser: {
    maxContexts: 1,
    navigationTimeout: 20000,
    extractionTimeout: 10000,
    delayBetweenPages: 2000,
    
    // Chromium launch arguments for minimal memory
    launchArgs: [
      '--disable-gpu',
      '--disable-dev-shm-usage',
      '--disable-setuid-sandbox',
      '--no-first-run',
      '--no-sandbox',
      '--no-zygote',
      '--single-process',
      '--disable-extensions',
      '--disable-background-networking',
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-breakpad',
      '--disable-component-extensions-with-background-pages',
      '--disable-component-update',
      '--disable-default-apps',
      '--disable-features=TranslateUI',
      '--disable-hang-monitor',
      '--disable-ipc-flooding-protection',
      '--disable-popup-blocking',
      '--disable-prompt-on-repost',
      '--disable-renderer-backgrounding',
      '--disable-sync',
      '--enable-features=NetworkService,NetworkServiceInProcess',
      '--force-color-profile=srgb',
      '--metrics-recording-only',
      '--mute-audio'
    ]
  },

  // Resource blocking - block everything non-essential
  blocking: {
    resourceTypes: ['image', 'stylesheet', 'font', 'media', 'other'],
    urlPatterns: [
      '*google-analytics*',
      '*googletagmanager*',
      '*facebook*',
      '*doubleclick*',
      '*analytics*',
      '*tracking*',
      '*advertisement*',
      '*ads.*'
    ]
  },

  // Database settings
  database: {
    path: 'data/scraper.sqlite',
    walMode: true,
    cacheSize: 256
  },

  // File paths
  paths: {
    inputUrls: 'data/input/urls.txt',
    outputDir: 'data/output',
    logsDir: 'logs'
  },

  // Memory thresholds (in MB)
  memory: {
    warningThreshold: 300,
    criticalThreshold: 200,
    checkInterval: 10
  },

  // Retry settings
  retry: {
    maxAttempts: 2,
    delayMs: 5000
  }
};
