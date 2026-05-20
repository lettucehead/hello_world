#!/bin/bash
# Show scraper status

echo "============================================================"
echo "JOB SCRAPER STATUS"
echo "============================================================"
echo ""

# Database stats
if [ -f "data/scraper.sqlite" ]; then
    echo "Database: data/scraper.sqlite"
    echo "Size: $(du -h data/scraper.sqlite | cut -f1)"
    echo ""
    
    if command -v sqlite3 &> /dev/null; then
        echo "URL Status:"
        sqlite3 data/scraper.sqlite "SELECT status, COUNT(*) FROM urls GROUP BY status;"
        echo ""
        echo "Jobs by Site:"
        sqlite3 data/scraper.sqlite "SELECT site, COUNT(*) FROM jobs GROUP BY site;"
        echo ""
        echo "Total Jobs: $(sqlite3 data/scraper.sqlite 'SELECT COUNT(*) FROM jobs;')"
    else
        echo "(Install sqlite3 for detailed stats)"
    fi
else
    echo "Database: Not created yet"
fi

echo ""
echo "Input URLs:"
if [ -f "data/input/urls.txt" ]; then
    echo "  File: data/input/urls.txt"
    echo "  Count: $(grep -c '^http' data/input/urls.txt 2>/dev/null || echo 0)"
else
    echo "  (No input file)"
fi

echo ""
echo "Output Files:"
ls -lah data/output/*.json data/output/*.csv 2>/dev/null || echo "  (None yet)"

echo ""
echo "Recent Logs:"
ls -latr logs/*.log 2>/dev/null | tail -3 || echo "  (None)"

echo ""
echo "============================================================"
