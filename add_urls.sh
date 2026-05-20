#!/bin/bash
# Add URLs to input file

INPUT_FILE="data/input/urls.txt"

if [ $# -eq 0 ]; then
    echo "Usage: ./add_urls.sh <url1> [url2] [url3] ..."
    echo ""
    echo "Or pipe URLs:"
    echo "  cat my_urls.txt | ./add_urls.sh"
    echo ""
    echo "Current URLs in file:"
    if [ -f "$INPUT_FILE" ]; then
        wc -l < "$INPUT_FILE"
    else
        echo "0"
    fi
    exit 0
fi

# Ensure directory exists
mkdir -p "$(dirname "$INPUT_FILE")"

# Add URLs from arguments
for url in "$@"; do
    echo "$url" >> "$INPUT_FILE"
    echo "Added: $url"
done

echo ""
echo "Total URLs: $(wc -l < "$INPUT_FILE")"
