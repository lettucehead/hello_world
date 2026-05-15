#!/bin/bash
# System Report v0.1.0
# Records what was installed, where, and disk usage

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="./logs/system-report_${TIMESTAMP}.log"
TEMPFILE="./.temp_report_$$"

mkdir -p ./logs

trap "rm -f $TEMPFILE" EXIT

do_listing() {
    echo ""
    echo "============================================================"
    echo "REPORT SAVED"
    echo "============================================================"
    echo ""
    echo "Log: $LOGFILE"
    echo ""
}

main() {
    echo "============================================================"
    echo "SYSTEM REPORT - $(date)"
    echo "============================================================"
    echo ""

    #=========================================================================
    # DISK USAGE SUMMARY
    #=========================================================================
    echo "============================================================"
    echo "DISK USAGE SUMMARY"
    echo "============================================================"
    echo ""
    
    echo "Overall disk usage:"
    df -h / | tail -1 | awk '{printf "  Total: %s\n  Used: %s (%s)\n  Free: %s\n", $2, $3, $5, $4}'
    echo ""

    echo "Installation locations:"
    echo ""
    
    # Homebrew
    if [ -d /opt/homebrew ]; then
        BREW_SIZE=$(du -sh /opt/homebrew 2>/dev/null | cut -f1)
        echo "  /opt/homebrew (Homebrew):          $BREW_SIZE"
    fi
    
    # Homebrew Casks (Applications)
    if [ -d /Applications ]; then
        APPS_SIZE=$(du -sh /Applications 2>/dev/null | cut -f1)
        echo "  /Applications:                     $APPS_SIZE"
    fi
    
    # Xcode CLI tools
    if [ -d /Library/Developer/CommandLineTools ]; then
        XCODE_SIZE=$(du -sh /Library/Developer/CommandLineTools 2>/dev/null | cut -f1)
        echo "  /Library/Developer/CommandLineTools: $XCODE_SIZE"
    fi
    
    # User directories
    if [ -d ~/.local ]; then
        LOCAL_SIZE=$(du -sh ~/.local 2>/dev/null | cut -f1)
        echo "  ~/.local:                          $LOCAL_SIZE"
    fi
    
    if [ -d ~/.cargo ]; then
        CARGO_SIZE=$(du -sh ~/.cargo 2>/dev/null | cut -f1)
        echo "  ~/.cargo (Rust):                   $CARGO_SIZE"
    fi
    
    if [ -d ~/.npm ]; then
        NPM_SIZE=$(du -sh ~/.npm 2>/dev/null | cut -f1)
        echo "  ~/.npm:                            $NPM_SIZE"
    fi
    
    if [ -d ~/Library/Caches/Homebrew ]; then
        BREW_CACHE=$(du -sh ~/Library/Caches/Homebrew 2>/dev/null | cut -f1)
        echo "  ~/Library/Caches/Homebrew:         $BREW_CACHE"
    fi
    
    echo ""

    #=========================================================================
    # HOMEBREW FORMULAE
    #=========================================================================
    echo "============================================================"
    echo "HOMEBREW FORMULAE ($(brew list --formula | wc -l | xargs) packages)"
    echo "============================================================"
    echo ""
    
    printf "%-25s %-15s %s\n" "PACKAGE" "VERSION" "SIZE"
    printf "%-25s %-15s %s\n" "-------" "-------" "----"
    
    for pkg in $(brew list --formula); do
        VERSION=$(brew info --json=v2 "$pkg" 2>/dev/null | grep -o '"installed":\[{"version":"[^"]*"' | head -1 | cut -d'"' -f6)
        CELLAR_PATH=$(brew --cellar "$pkg" 2>/dev/null)
        if [ -d "$CELLAR_PATH" ]; then
            SIZE=$(du -sh "$CELLAR_PATH" 2>/dev/null | cut -f1)
        else
            SIZE="?"
        fi
        printf "%-25s %-15s %s\n" "$pkg" "${VERSION:-?}" "$SIZE"
    done
    
    echo ""
    TOTAL_FORMULAE=$(du -sh /opt/homebrew/Cellar 2>/dev/null | cut -f1)
    echo "Total formulae size: $TOTAL_FORMULAE"
    echo ""

    #=========================================================================
    # HOMEBREW CASKS
    #=========================================================================
    echo "============================================================"
    echo "HOMEBREW CASKS ($(brew list --cask | wc -l | xargs) packages)"
    echo "============================================================"
    echo ""
    
    printf "%-30s %s\n" "PACKAGE" "SIZE"
    printf "%-30s %s\n" "-------" "----"
    
    for cask in $(brew list --cask); do
        # Try to find the app in /Applications
        APP_NAME=$(brew info --cask "$cask" 2>/dev/null | grep -o '/Applications/[^)]*' | head -1)
        if [ -n "$APP_NAME" ] && [ -d "$APP_NAME" ]; then
            SIZE=$(du -sh "$APP_NAME" 2>/dev/null | cut -f1)
        else
            SIZE="?"
        fi
        printf "%-30s %s\n" "$cask" "$SIZE"
    done
    
    echo ""
    if [ -d /opt/homebrew/Caskroom ]; then
        TOTAL_CASKS=$(du -sh /opt/homebrew/Caskroom 2>/dev/null | cut -f1)
        echo "Total caskroom size: $TOTAL_CASKS"
    fi
    echo ""

    #=========================================================================
    # LANGUAGES & RUNTIMES
    #=========================================================================
    echo "============================================================"
    echo "LANGUAGES & RUNTIMES"
    echo "============================================================"
    echo ""
    
    printf "%-15s %-20s %s\n" "LANGUAGE" "VERSION" "PATH"
    printf "%-15s %-20s %s\n" "--------" "-------" "----"
    
    # Node
    if command -v node &>/dev/null; then
        printf "%-15s %-20s %s\n" "Node.js" "$(node --version 2>/dev/null)" "$(which node)"
    fi
    
    # Python
    if command -v python3 &>/dev/null; then
        printf "%-15s %-20s %s\n" "Python" "$(python3 --version 2>/dev/null | cut -d' ' -f2)" "$(which python3)"
    fi
    
    # R
    if command -v R &>/dev/null; then
        printf "%-15s %-20s %s\n" "R" "$(R --version 2>/dev/null | head -1 | cut -d' ' -f3)" "$(which R)"
    fi
    
    # Julia
    if command -v julia &>/dev/null; then
        printf "%-15s %-20s %s\n" "Julia" "$(julia --version 2>/dev/null | cut -d' ' -f3)" "$(which julia)"
    fi
    
    # Go
    if command -v go &>/dev/null; then
        printf "%-15s %-20s %s\n" "Go" "$(go version 2>/dev/null | cut -d' ' -f3 | sed 's/go//')" "$(which go)"
    fi
    
    # Lua
    if command -v lua &>/dev/null; then
        printf "%-15s %-20s %s\n" "Lua" "$(lua -v 2>/dev/null | cut -d' ' -f2)" "$(which lua)"
    fi
    
    # Ruby (system)
    if command -v ruby &>/dev/null; then
        printf "%-15s %-20s %s\n" "Ruby" "$(ruby --version 2>/dev/null | cut -d' ' -f2)" "$(which ruby)"
    fi
    
    echo ""

    #=========================================================================
    # CLI TOOLS
    #=========================================================================
    echo "============================================================"
    echo "CLI TOOLS"
    echo "============================================================"
    echo ""
    
    printf "%-15s %-20s %s\n" "TOOL" "VERSION" "PATH"
    printf "%-15s %-20s %s\n" "----" "-------" "----"
    
    TOOLS=(
        "git:git --version | cut -d' ' -f3"
        "gh:gh --version | head -1 | cut -d' ' -f3"
        "lazygit:lazygit --version | cut -d' ' -f6 | tr -d ','"
        "delta:delta --version | cut -d' ' -f2"
        "duckdb:duckdb --version | cut -d' ' -f2"
        "jq:jq --version | tr -d 'jq-'"
        "yq:yq --version | cut -d' ' -f4"
        "xh:xh --version | cut -d' ' -f2"
        "eza:eza --version | head -1 | cut -d' ' -f2"
        "bat:bat --version | cut -d' ' -f2"
        "fd:fd --version | cut -d' ' -f2"
        "rg:rg --version | head -1 | cut -d' ' -f2"
        "fzf:fzf --version | cut -d' ' -f1"
        "zoxide:zoxide --version | cut -d' ' -f2"
        "tmux:tmux -V | cut -d' ' -f2"
        "vim:vim --version | head -1 | cut -d' ' -f5"
        "nvim:nvim --version | head -1 | cut -d' ' -f2"
        "terraform:terraform --version | head -1 | cut -d' ' -f2 | tr -d 'v'"
        "aws:aws --version | cut -d' ' -f1 | cut -d'/' -f2"
    )
    
    for tool_spec in "${TOOLS[@]}"; do
        TOOL=$(echo "$tool_spec" | cut -d: -f1)
        VERSION_CMD=$(echo "$tool_spec" | cut -d: -f2-)
        if command -v "$TOOL" &>/dev/null; then
            VERSION=$(eval "$VERSION_CMD" 2>/dev/null || echo "?")
            printf "%-15s %-20s %s\n" "$TOOL" "$VERSION" "$(which $TOOL)"
        fi
    done
    
    echo ""

    #=========================================================================
    # APPLICATIONS (CASKS)
    #=========================================================================
    echo "============================================================"
    echo "APPLICATIONS"
    echo "============================================================"
    echo ""
    
    APPS=(
        "Visual Studio Code:/Applications/Visual Studio Code.app"
        "Tailscale:/Applications/Tailscale.app"
    )
    
    printf "%-30s %-10s %s\n" "APPLICATION" "INSTALLED" "SIZE"
    printf "%-30s %-10s %s\n" "-----------" "---------" "----"
    
    for app_spec in "${APPS[@]}"; do
        APP_NAME=$(echo "$app_spec" | cut -d: -f1)
        APP_PATH=$(echo "$app_spec" | cut -d: -f2)
        if [ -d "$APP_PATH" ]; then
            SIZE=$(du -sh "$APP_PATH" 2>/dev/null | cut -f1)
            printf "%-30s %-10s %s\n" "$APP_NAME" "✓" "$SIZE"
        else
            printf "%-30s %-10s %s\n" "$APP_NAME" "✗" "-"
        fi
    done
    
    echo ""

    #=========================================================================
    # CONFIGURATION FILES
    #=========================================================================
    echo "============================================================"
    echo "CONFIGURATION FILES"
    echo "============================================================"
    echo ""
    
    CONFIG_FILES=(
        "$HOME/.zshrc"
        "$HOME/.zprofile"
        "$HOME/.ssh/config"
        "$HOME/.ssh/id_ed25519.pub"
        "$HOME/.gitconfig"
    )
    
    printf "%-40s %-10s %s\n" "FILE" "EXISTS" "SIZE"
    printf "%-40s %-10s %s\n" "----" "------" "----"
    
    for cfg in "${CONFIG_FILES[@]}"; do
        if [ -f "$cfg" ]; then
            SIZE=$(du -h "$cfg" 2>/dev/null | cut -f1)
            printf "%-40s %-10s %s\n" "$cfg" "✓" "$SIZE"
        else
            printf "%-40s %-10s %s\n" "$cfg" "✗" "-"
        fi
    done
    
    echo ""

    #=========================================================================
    # GIT CONFIGURATION
    #=========================================================================
    echo "============================================================"
    echo "GIT CONFIGURATION"
    echo "============================================================"
    echo ""
    
    echo "Global config:"
    git config --global --list 2>/dev/null | sed 's/^/  /'
    echo ""

    #=========================================================================
    # SSH KEYS
    #=========================================================================
    echo "============================================================"
    echo "SSH KEYS"
    echo "============================================================"
    echo ""
    
    if [ -f ~/.ssh/id_ed25519.pub ]; then
        echo "Public key:"
        cat ~/.ssh/id_ed25519.pub | sed 's/^/  /'
    else
        echo "  No SSH key found"
    fi
    echo ""

    #=========================================================================
    # NETWORK
    #=========================================================================
    echo "============================================================"
    echo "NETWORK"
    echo "============================================================"
    echo ""
    
    echo "  Hostname:      $(hostname)"
    echo "  Local IP:      $(ipconfig getifaddr en0 2>/dev/null || echo 'unknown')"
    echo "  Tailscale IP:  $(tailscale ip -4 2>/dev/null || echo 'not configured')"
    echo ""

    #=========================================================================
    # SHELL ALIASES
    #=========================================================================
    echo "============================================================"
    echo "SHELL ALIASES (from ~/.zshrc)"
    echo "============================================================"
    echo ""
    
    if [ -f ~/.zshrc ]; then
        grep "^alias" ~/.zshrc 2>/dev/null | sed 's/^/  /' || echo "  No aliases found"
    fi
    echo ""

    #=========================================================================
    # ESTIMATED BOOTSTRAP SIZE
    #=========================================================================
    echo "============================================================"
    echo "ESTIMATED BOOTSTRAP INSTALLATION SIZE"
    echo "============================================================"
    echo ""
    
    TOTAL=0
    
    # Homebrew
    if [ -d /opt/homebrew ]; then
        BREW_BYTES=$(du -s /opt/homebrew 2>/dev/null | cut -f1)
        TOTAL=$((TOTAL + BREW_BYTES))
        echo "  Homebrew (/opt/homebrew):           $(du -sh /opt/homebrew 2>/dev/null | cut -f1)"
    fi
    
    # Xcode CLI
    if [ -d /Library/Developer/CommandLineTools ]; then
        XCODE_BYTES=$(du -s /Library/Developer/CommandLineTools 2>/dev/null | cut -f1)
        TOTAL=$((TOTAL + XCODE_BYTES))
        echo "  Xcode CLI tools:                    $(du -sh /Library/Developer/CommandLineTools 2>/dev/null | cut -f1)"
    fi
    
    # VS Code
    if [ -d "/Applications/Visual Studio Code.app" ]; then
        VSCODE_BYTES=$(du -s "/Applications/Visual Studio Code.app" 2>/dev/null | cut -f1)
        TOTAL=$((TOTAL + VSCODE_BYTES))
        echo "  Visual Studio Code:                 $(du -sh "/Applications/Visual Studio Code.app" 2>/dev/null | cut -f1)"
    fi
    
    # Tailscale
    if [ -d "/Applications/Tailscale.app" ]; then
        TS_BYTES=$(du -s "/Applications/Tailscale.app" 2>/dev/null | cut -f1)
        TOTAL=$((TOTAL + TS_BYTES))
        echo "  Tailscale:                          $(du -sh "/Applications/Tailscale.app" 2>/dev/null | cut -f1)"
    fi
    
    echo ""
    
    # Convert to human readable
    if [ $TOTAL -gt 1048576 ]; then
        TOTAL_HR=$(echo "scale=1; $TOTAL / 1048576" | bc)G
    elif [ $TOTAL -gt 1024 ]; then
        TOTAL_HR=$(echo "scale=1; $TOTAL / 1024" | bc)M
    else
        TOTAL_HR="${TOTAL}K"
    fi
    
    echo "  ----------------------------------------"
    echo "  TOTAL ESTIMATED:                    $TOTAL_HR"
    echo ""

    do_listing
}

# Start output capture
exec > >(tee "$TEMPFILE") 2>&1

main "$@"

# Stop capture
exec > /dev/tty 2>&1

# Save log
cp "$TEMPFILE" "$LOGFILE"

# Copy to clipboard
cat "$TEMPFILE" | pbcopy 2>/dev/null && echo "✓ Output copied to clipboard"

echo "✓ Log saved to: $LOGFILE"
