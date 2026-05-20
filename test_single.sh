#!/bin/bash
# Test single URL extraction

URL=${1:-""}

if [ -z "$URL" ]; then
    echo "Usage: ./test_single.sh <url>"
    echo ""
    echo "Example:"
    echo "  ./test_single.sh 'https://www.indeed.com/viewjob?jk=abc123'"
    exit 1
fi

# Ensure dependencies installed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

node src/test.js "$URL"
