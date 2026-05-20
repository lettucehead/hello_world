#!/usr/bin/env node
// CSV Importer
// Reads col A (Big Index) and col Q (Board) and loads them into the database

import fs from 'fs';
import path from 'path';
import * as storage from './storage.js';

function parseCsv(content) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  let i = 0;

  while (i < content.length) {
    const ch = content[i];

    if (inQuotes) {
      if (ch === '"' && content[i + 1] === '"') {
        field += '"';
        i += 2;
      } else if (ch === '"') {
        inQuotes = false;
        i++;
      } else {
        field += ch;
        i++;
      }
    } else {
      if (ch === '"') {
        inQuotes = true;
        i++;
      } else if (ch === ',') {
        row.push(field);
        field = '';
        i++;
      } else if (ch === '\r' && content[i + 1] === '\n') {
        row.push(field);
        rows.push(row);
        row = [];
        field = '';
        i += 2;
      } else if (ch === '\n') {
        row.push(field);
        rows.push(row);
        row = [];
        field = '';
        i++;
      } else {
        field += ch;
        i++;
      }
    }
  }

  if (field || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  return rows;
}

function main() {
  const csvPath = process.argv[2];
  if (!csvPath) {
    console.error('Usage: node src/import_csv.js <path-to-csv>');
    process.exit(1);
  }

  const absPath = path.resolve(csvPath);
  if (!fs.existsSync(absPath)) {
    console.error(`File not found: ${absPath}`);
    process.exit(1);
  }

  const rows = parseCsv(fs.readFileSync(absPath, 'utf-8'));

  if (rows.length < 2) {
    console.log('No data rows found');
    return;
  }

  const header = rows[0];
  const bigIndexCol = header.indexOf('Big Index');
  const boardCol = header.indexOf('Board');

  if (bigIndexCol === -1) { console.error('Column "Big Index" not found'); process.exit(1); }
  if (boardCol === -1)    { console.error('Column "Board" not found');     process.exit(1); }

  const entries = [];
  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    const board = row[boardCol]?.trim();
    if (!board?.startsWith('http')) continue;

    const raw = row[bigIndexCol]?.trim();
    const sourceIndex = raw ? Number(raw) : null;

    entries.push({ url: board, source_index: Number.isFinite(sourceIndex) ? sourceIndex : null });
  }

  console.log(`Found ${entries.length} Board URLs`);

  storage.initialize();
  storage.addUrls(entries);
  storage.close();
}

main();
