// Storage Manager v0.1.0
// SQLite-based persistence

import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import settings from '../config/settings.js';

let db = null;

export function initialize() {
  if (db) {
    console.log('[Storage] Already initialized');
    return;
  }

  // Ensure directory exists
  const dbDir = path.dirname(settings.database.path);
  if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
  }

  console.log('[Storage] Initializing SQLite database...');
  
  db = new Database(settings.database.path);
  
  // Configure for performance
  if (settings.database.walMode) {
    db.pragma('journal_mode = WAL');
  }
  db.pragma(`cache_size = ${settings.database.cacheSize}`);
  db.pragma('synchronous = NORMAL');

  // Create tables
  db.exec(`
    CREATE TABLE IF NOT EXISTS urls (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT UNIQUE NOT NULL,
      source_index INTEGER,
      status TEXT DEFAULT 'pending',
      attempts INTEGER DEFAULT 0,
      last_error TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      processed_at TEXT
    );

    CREATE TABLE IF NOT EXISTS jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT UNIQUE NOT NULL,
      source_index INTEGER,
      site TEXT,
      title TEXT,
      company TEXT,
      location TEXT,
      salary TEXT,
      description TEXT,
      posted_date TEXT,
      job_type TEXT,
      extracted_at TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS scrape_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      url TEXT NOT NULL,
      success INTEGER,
      error TEXT,
      duration_ms INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_urls_status ON urls(status);
    CREATE INDEX IF NOT EXISTS idx_urls_source ON urls(source_index);
    CREATE INDEX IF NOT EXISTS idx_jobs_source ON jobs(source_index);
    CREATE INDEX IF NOT EXISTS idx_jobs_company ON jobs(company);
    CREATE INDEX IF NOT EXISTS idx_jobs_site ON jobs(site);
  `);

  console.log('[Storage] Database ready');
}

// entries: array of { url, source_index? }
export function addUrls(entries) {
  const insert = db.prepare(`
    INSERT OR IGNORE INTO urls (url, source_index) VALUES (?, ?)
  `);

  const insertMany = db.transaction((entries) => {
    let added = 0;
    for (const entry of entries) {
      const url = typeof entry === 'string' ? entry : entry.url;
      const sourceIndex = typeof entry === 'string' ? null : (entry.source_index ?? null);
      const result = insert.run(url.trim(), sourceIndex);
      if (result.changes > 0) added++;
    }
    return added;
  });

  const added = insertMany(entries);
  console.log(`[Storage] Added ${added} new URLs (${entries.length - added} duplicates skipped)`);
  return added;
}

// Returns { url, source_index } objects
export function getPendingUrls(limit = 100) {
  const stmt = db.prepare(`
    SELECT url, source_index FROM urls
    WHERE status = 'pending' OR (status = 'failed' AND attempts < ?)
    ORDER BY attempts ASC, created_at ASC
    LIMIT ?
  `);

  return stmt.all(settings.retry.maxAttempts, limit);
}

export function markProcessed(url, success, error = null) {
  const stmt = db.prepare(`
    UPDATE urls 
    SET status = ?,
        attempts = attempts + 1,
        last_error = ?,
        processed_at = CURRENT_TIMESTAMP
    WHERE url = ?
  `);

  stmt.run(success ? 'completed' : 'failed', error, url);
}

export function saveJob(data) {
  const stmt = db.prepare(`
    INSERT OR REPLACE INTO jobs (
      url, source_index, site, title, company, location, salary,
      description, posted_date, job_type, extracted_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  stmt.run(
    data.url,
    data.source_index ?? null,
    data.site,
    data.title,
    data.company,
    data.location,
    data.salary,
    data.description,
    data.postedDate,
    data.jobType,
    new Date().toISOString()
  );
}

export function logScrape(url, success, error, duration) {
  const stmt = db.prepare(`
    INSERT INTO scrape_log (url, success, error, duration_ms)
    VALUES (?, ?, ?, ?)
  `);

  stmt.run(url, success ? 1 : 0, error, duration);
}

export function getStats() {
  const stats = {};
  
  stats.urls = db.prepare(`
    SELECT status, COUNT(*) as count FROM urls GROUP BY status
  `).all();

  stats.jobs = db.prepare(`
    SELECT site, COUNT(*) as count FROM jobs GROUP BY site
  `).all();

  stats.totalJobs = db.prepare(`SELECT COUNT(*) as count FROM jobs`).get().count;
  stats.totalUrls = db.prepare(`SELECT COUNT(*) as count FROM urls`).get().count;
  
  stats.recentErrors = db.prepare(`
    SELECT url, error, created_at FROM scrape_log 
    WHERE success = 0 
    ORDER BY created_at DESC 
    LIMIT 5
  `).all();

  return stats;
}

export function getAllJobs() {
  return db.prepare(`SELECT * FROM jobs ORDER BY created_at DESC`).all();
}

export function exportToJson(outputPath) {
  const jobs = getAllJobs();
  
  // Ensure output directory exists
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(outputPath, JSON.stringify(jobs, null, 2));
  console.log(`[Storage] Exported ${jobs.length} jobs to ${outputPath}`);
  return jobs.length;
}

export function exportToCsv(outputPath) {
  const jobs = getAllJobs();
  
  if (jobs.length === 0) {
    console.log('[Storage] No jobs to export');
    return 0;
  }

  const headers = ['source_index', 'title', 'company', 'location', 'salary', 'site', 'url', 'extracted_at'];
  
  const escapeCsv = (val) => {
    if (val === null || val === undefined) return '';
    const str = String(val);
    if (str.includes(',') || str.includes('"') || str.includes('\n')) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  };

  const lines = [headers.join(',')];
  for (const job of jobs) {
    const row = headers.map(h => escapeCsv(job[h]));
    lines.push(row.join(','));
  }

  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  fs.writeFileSync(outputPath, lines.join('\n'));
  console.log(`[Storage] Exported ${jobs.length} jobs to ${outputPath}`);
  return jobs.length;
}

export function close() {
  if (db) {
    db.close();
    db = null;
    console.log('[Storage] Database closed');
  }
}
