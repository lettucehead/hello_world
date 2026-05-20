#!/bin/bash
# Export scraped data

FORMAT=${1:-both}

echo "Exporting data (format: $FORMAT)..."
node src/export.js "$FORMAT"
