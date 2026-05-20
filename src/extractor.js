// Job Extractor v0.1.0
// Generic extraction with site-specific enhancements

import * as cheerio from 'cheerio';
import { getPage, closePage } from './browser.js';
import settings from '../config/settings.js';

// Site detection patterns
const SITE_PATTERNS = {
  indeed: /indeed\.com/i,
  linkedin: /linkedin\.com\/jobs/i,
  glassdoor: /glassdoor\.com/i,
  ziprecruiter: /ziprecruiter\.com/i,
  monster: /monster\.com/i,
  dice: /dice\.com/i
};

// Site-specific selectors
const SELECTORS = {
  indeed: {
    title: '.jobsearch-JobInfoHeader-title, h1[data-testid="jobsearch-JobInfoHeader-title"]',
    company: '[data-testid="inlineHeader-companyName"], .jobsearch-InlineCompanyRating-companyHeader a',
    location: '[data-testid="job-location"], .jobsearch-JobInfoHeader-subtitle > div:last-child',
    salary: '#salaryInfoAndJobType span, .jobsearch-JobMetadataHeader-item',
    description: '#jobDescriptionText, .jobsearch-jobDescriptionText'
  },
  linkedin: {
    title: '.top-card-layout__title, h1.topcard__title',
    company: '.topcard__org-name-link, a.topcard__org-name-link',
    location: '.topcard__flavor--bullet, span.topcard__flavor:nth-child(2)',
    salary: '.salary, .compensation__salary',
    description: '.description__text, .show-more-less-html__markup'
  },
  glassdoor: {
    title: '[data-test="jobTitle"], .css-1vg6q84',
    company: '[data-test="employerName"], .css-87uc0g',
    location: '[data-test="location"], .css-56kyx5',
    salary: '[data-test="detailSalary"], .css-1bluz6i',
    description: '.jobDescriptionContent, .desc'
  },
  generic: {
    title: 'h1, .job-title, .jobtitle, [class*="title"]',
    company: '.company, .employer, [class*="company"], [class*="employer"]',
    location: '.location, [class*="location"], [class*="address"]',
    salary: '.salary, .compensation, [class*="salary"], [class*="pay"]',
    description: '.description, .job-description, [class*="description"]'
  }
};

function detectSite(url) {
  for (const [site, pattern] of Object.entries(SITE_PATTERNS)) {
    if (pattern.test(url)) {
      return site;
    }
  }
  return 'generic';
}

function extractText($, selectors) {
  for (const selector of selectors.split(', ')) {
    const element = $(selector).first();
    if (element.length) {
      const text = element.text().trim();
      if (text) return text;
    }
  }
  return null;
}

function extractSalary(text) {
  if (!text) return null;
  
  // Common salary patterns
  const patterns = [
    /\$[\d,]+(?:\.\d{2})?\s*(?:-|to|–)\s*\$[\d,]+(?:\.\d{2})?/i,
    /\$[\d,]+(?:\.\d{2})?\s*(?:per|\/|a)\s*(?:year|yr|hour|hr|month|week)/i,
    /\$[\d,]+(?:\.\d{2})?(?:k)?/i,
    /[\d,]+(?:\.\d{2})?\s*(?:-|to|–)\s*[\d,]+(?:\.\d{2})?\s*(?:USD|per year|annually)/i
  ];

  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) return match[0];
  }
  
  return null;
}

function cleanText(text) {
  if (!text) return null;
  return text
    .replace(/\s+/g, ' ')
    .replace(/\n+/g, ' ')
    .trim();
}

export async function extract(url) {
  const startTime = Date.now();
  let page = null;
  
  const result = {
    url,
    success: false,
    data: null,
    error: null,
    duration: 0,
    site: null,
    extractedAt: new Date().toISOString()
  };

  try {
    // Detect site type
    result.site = detectSite(url);
    const selectors = SELECTORS[result.site] || SELECTORS.generic;
    
    console.log(`[Extractor] Processing ${url}`);
    console.log(`[Extractor] Detected site: ${result.site}`);

    // Get page and navigate
    page = await getPage();
    
    const response = await page.goto(url, {
      waitUntil: 'domcontentloaded',
      timeout: settings.browser.navigationTimeout
    });

    if (!response) {
      throw new Error('No response received');
    }

    const status = response.status();
    if (status >= 400) {
      throw new Error(`HTTP ${status}`);
    }

    // Wait a moment for any immediate JS execution
    await page.waitForTimeout(1000);

    // Get HTML and parse with Cheerio
    const html = await page.content();
    const $ = cheerio.load(html);

    // Extract fields
    const title = cleanText(extractText($, selectors.title));
    const company = cleanText(extractText($, selectors.company));
    const location = cleanText(extractText($, selectors.location));
    const descriptionRaw = extractText($, selectors.description);
    const description = cleanText(descriptionRaw);
    
    // Try to find salary in multiple places
    let salary = cleanText(extractText($, selectors.salary));
    if (!salary && descriptionRaw) {
      salary = extractSalary(descriptionRaw);
    }

    // Extract additional metadata
    const postedDate = cleanText(extractText($, '.date, .posted, [class*="date"], [class*="posted"], time'));
    const jobType = cleanText(extractText($, '.job-type, [class*="job-type"], [class*="employment"]'));

    result.data = {
      title,
      company,
      location,
      salary,
      description: description ? description.substring(0, 5000) : null,
      postedDate,
      jobType,
      url,
      site: result.site
    };

    // Validate we got at least some data
    const hasData = title || company || description;
    if (!hasData) {
      throw new Error('No data extracted - page may require JavaScript');
    }

    result.success = true;
    console.log(`[Extractor] Success: "${title || 'No title'}" at "${company || 'Unknown company'}"`);

  } catch (err) {
    result.error = err.message;
    console.log(`[Extractor] Failed: ${err.message}`);
  } finally {
    await closePage(page);
    result.duration = Date.now() - startTime;
  }

  return result;
}

export function getSupportedSites() {
  return Object.keys(SITE_PATTERNS);
}
