#!/bin/bash
# System Report v0.2.0 (fast)

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="./logs/system-report_${TIMESTAMP}.log"

mkdir -p ./logs

main() {
    echo "============================================================"
    echo "SYSTEM REPORT - $(date)"
    echo "============================================================"

    echo ""
    echo "=== DISK USAGE ==="
    df -h / | tail -1 | awk '{printf "Total: %s | Used: %s (%s) | Free: %s\n", $2, $3, $5, $4}'

    echo ""
    echo "=== INSTALLATION SIZES ==="
    du -sh /opt/homebrew /Library/Developer/CommandLineTools "/Applications/Visual Studio Code.app" /Applications/Tailscale.app ~/.local ~/.cargo ~/.npm 2>/dev/null

    echo ""
    echo "=== HOMEBREW FORMULAE ($(brew list --formula | wc -l | xargs)) ==="
    brew list --formula --versions

    echo ""
    echo "=== HOMEBREW CASKS ($(brew list --cask | wc -l | xargs)) ==="
    brew list --cask --versions

    echo ""
    echo "=== LANGUAGES ==="
    node --version 2>/dev/null && echo "  node: $(which node)"
    python3 --version 2>/dev/null && echo "  python: $(which python3)"
    R --version 2>/dev/null | head -1
    julia --version 2>/dev/null
    go version 2>/dev/null
    lua -v 2>/dev/null

    echo ""
    echo "=== GIT CONFIG ==="
    git config --global --list 2>/dev/null

    echo ""
    echo "=== SSH KEY ==="
    cat ~/.ssh/id_ed25519.pub 2>/dev/null || echo "No key found"

    echo ""
    echo "=== NETWORK ==="
    echo "Local: $(ipconfig getifaddr en0 2>/dev/null || echo unknown)"
    echo "Tailscale: $(tailscale ip -4 2>/dev/null || echo 'not configured')"

    echo ""
    echo "=== SHELL ALIASES ==="
    grep "^alias" ~/.zshrc 2>/dev/null || echo "None"
}

main 2>&1 | tee "$LOGFILE"

echo ""
echo "✓ Saved to: $LOGFILE"
