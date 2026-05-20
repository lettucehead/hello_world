#!/bin/bash
# Job Scraper Wrapper v0.1.0

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="logs/scrape_${TIMESTAMP}.log"
TEMPFILE="logs/.temp_output_$$"

# Ensure directories exist
mkdir -p logs data/output data/input

# Colors (if terminal supports)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to show memory status
show_memory() {
    echo ""
    echo "============================================================"
    echo "MEMORY STATUS"
    echo "============================================================"
    if command -v free &> /dev/null; then
        free -h
    else
        # ChromeOS/Crostini might not have free
        cat /proc/meminfo | head -20
    fi
    echo ""
}

# Function to do directory listing
do_listing() {
    echo ""
    echo "============================================================"
    echo "OUTPUT FILES"
    echo "============================================================"
    echo ""
    echo "Data output (newest first):"
    ls -latr data/output/ 2>/dev/null || echo "(empty)"
    echo ""
    echo "Log files:"
    ls -latr logs/*.log 2>/dev/null | tail -5 || echo "(none)"
    echo ""
    echo "Database:"
    ls -lah data/*.sqlite 2>/dev/null || echo "(not created yet)"
    echo ""
}

# Pre-flight checks
preflight_check() {
    echo "Running pre-flight checks..."
    echo ""
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}ERROR: Node.js not found${NC}"
        echo "Install with: sudo apt install nodejs"
        exit 1
    fi
    echo "✓ Node.js $(node --version)"
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}ERROR: npm not found${NC}"
        exit 1
    fi
    echo "✓ npm $(npm --version)"
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo ""
        echo -e "${YELLOW}Installing dependencies...${NC}"
        npm install
    fi
    echo "✓ Dependencies installed"
    
    # Check if input URLs exist
    if [ ! -f "data/input/urls.txt" ]; then
        echo ""
        echo -e "${YELLOW}WARNING: No input URLs file found${NC}"
        echo "Create data/input/urls.txt with job posting URLs (one per line)"
    else
        URL_COUNT=$(grep -c "^http" data/input/urls.txt 2>/dev/null || echo "0")
        echo "✓ Input file: ${URL_COUNT} URLs"
    fi
    
    echo ""
}

# Main execution
main() {
    echo "============================================================"
    echo "JOB SCRAPER v0.1.0"
    echo "Started: $(date)"
    echo "============================================================"
    echo ""
    
    # Run preflight
    preflight_check
    
    # Show initial memory
    show_memory
    
    # Run the scraper
    echo "============================================================"
    echo "RUNNING SCRAPER"
    echo "============================================================"
    echo ""
    
    node src/index.js
    SCRAPE_EXIT=$?
    
    if [ $SCRAPE_EXIT -ne 0 ]; then
        echo ""
        echo -e "${RED}>>> Scraper exited with code: $SCRAPE_EXIT${NC}"
    else
        echo ""
        echo -e "${GREEN}>>> Scraper completed successfully${NC}"
    fi
    
    # Show final memory
    show_memory
    
    # Show output files
    do_listing
    
    echo "============================================================"
    echo "DONE"
    echo "============================================================"
    echo "Log saved: $LOGFILE"
    echo "Finished: $(date)"
    echo "============================================================"
    
    return $SCRAPE_EXIT
}

# Start output capture
exec > >(tee "$TEMPFILE") 2>&1

# Run main
main
EXIT_CODE=$?

# Stop capture
exec > /dev/tty 2>&1

# Save log
cp "$TEMPFILE" "$LOGFILE" 2>/dev/null || true
rm -f "$TEMPFILE"

# Try to copy to clipboard (macOS/Linux)
if command -v pbcopy &> /dev/null; then
    cat "$LOGFILE" | pbcopy
    echo ""
    echo "✓ Copied to clipboard (pbcopy)"
elif command -v xclip &> /dev/null; then
    cat "$LOGFILE" | xclip -selection clipboard
    echo ""
    echo "✓ Copied to clipboard (xclip)"
fi

exit $EXIT_CODE
