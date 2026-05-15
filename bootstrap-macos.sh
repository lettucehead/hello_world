#!/bin/bash
# macOS Fresh Install Bootstrap v0.7.0
set -uo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="./logs/bootstrap-macos_${TIMESTAMP}.log"
TEMPFILE="./.temp_bootstrap_$$"

mkdir -p ./logs

trap "rm -f $TEMPFILE" EXIT

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "-n" ]; then
    DRY_RUN=true
    shift
fi

run() {
    if [ "$DRY_RUN" = true ]; then
        printf "[DRY RUN] %s\n" "$*"
    else
        eval "$*"
    fi
}

info() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
error() { printf "[ERROR] %s\n" "$*"; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

append_if_missing() {
    local file="$1"
    local marker="$2"
    local content="$3"
    mkdir -p "$(dirname "$file")"
    if [ "$DRY_RUN" = true ]; then
        printf "[DRY RUN] append to %s if missing %s\n" "$file" "$marker"
    elif ! grep -Fq "$marker" "$file" 2>/dev/null; then
        printf "%s\n" "$content" >> "$file"
    fi
}

brew_install() {
    local package="$1"
    if ! brew info "$package" &>/dev/null; then
        warn "$package not found in Homebrew, skipping"
        return
    fi
    if ! brew list --formula "$package" &>/dev/null; then
        info "Installing $package..."
        [ "$DRY_RUN" = true ] && printf "[DRY RUN] brew install %s\n" "$package" && return
        brew install "$package" || warn "Failed to install $package"
    else
        info "$package already installed"
    fi
}

brew_cask_install() {
    local package="$1"
    if ! brew list --cask "$package" &>/dev/null; then
        info "Installing $package..."
        [ "$DRY_RUN" = true ] && printf "[DRY RUN] brew install --cask %s\n" "$package" && return
        brew install --cask "$package" || warn "Failed to install $package"
    else
        info "$package already installed"
    fi
}

do_listing() {
    echo ""
    echo "============================================================"
    echo "BOOTSTRAP SUMMARY"
    echo "============================================================"
    echo ""
    echo "Installed packages:"
    brew list --formula | wc -l | xargs printf "  Formulae: %s\n"
    brew list --cask | wc -l | xargs printf "  Casks: %s\n"
    echo ""
    echo "SSH key:"
    [ -f ~/.ssh/id_ed25519.pub ] && echo "  $(cat ~/.ssh/id_ed25519.pub | cut -c1-50)..."
    echo ""
    echo "Git config:"
    echo "  Name:  $(git config --global user.name 2>/dev/null || echo 'not set')"
    echo "  Email: $(git config --global user.email 2>/dev/null || echo 'not set')"
    echo ""
    echo "Network:"
    echo "  Local IP:     $(ipconfig getifaddr en0 2>/dev/null || echo 'unknown')"
    echo "  Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'not configured')"
    echo ""
}

main() {
    echo "============================================================"
    echo "macOS FRESH INSTALL BOOTSTRAP - $(date)"
    echo "============================================================"
    echo ""

    #=========================================================================
    # STEP 1: Xcode CLI tools
    #=========================================================================
    info "[1/12] Checking Xcode CLI tools..."
    if ! xcode-select -p &>/dev/null; then
        info "Installing Xcode CLI tools..."
        xcode-select --install 2>/dev/null || true
        
        echo ""
        echo "============================================================"
        echo "WAITING FOR XCODE CLI TOOLS"
        echo "============================================================"
        echo ""
        echo "  ⌘ Cmd+Tab to find the 'Install Command Line Developer Tools' window"
        echo "  Click 'Install' and wait 5-10 minutes"
        echo ""
        
        if [ "$DRY_RUN" = false ]; then
            until xcode-select -p &>/dev/null; do
                if ps aux | grep -i "Install Command Line" | grep -v grep > /dev/null; then
                    PROC_INFO=$(ps aux | grep -i "Install Command Line" | grep -v grep | awk '{printf "PID: %s, CPU: %s%%, MEM: %s%%", $2, $3, $4}')
                    echo "$(date '+%H:%M:%S') - Installer running ($PROC_INFO)"
                    echo "                ⌘ Cmd+Tab if you don't see the installer window"
                else
                    echo "$(date '+%H:%M:%S') - Waiting for installer popup... (⌘ Cmd+Tab to check)"
                fi
                sleep 30
            done
        fi
        
        echo ""
        info "Xcode CLI tools installed!"
    else
        info "Xcode CLI tools already installed"
    fi

    #=========================================================================
    # STEP 2: Homebrew
    #=========================================================================
    info "[2/12] Checking Homebrew..."
    if ! command_exists brew; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        info "Homebrew already installed"
    fi

    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    append_if_missing ~/.zprofile "# Homebrew" $'\n# Homebrew\neval "$(/opt/homebrew/bin/brew shellenv)"\n'

    #=========================================================================
    # STEP 3: Languages
    #=========================================================================
    info "[3/12] Installing languages..."
    brew_install node
    brew_install python
    brew_install r
    brew_install julia
    brew_install go
    brew_install lua

    #=========================================================================
    # STEP 4: Package managers
    #=========================================================================
    info "[4/12] Installing package managers..."
    brew_install nvm
    command_exists uv || curl -LsSf https://astral.sh/uv/install.sh | sh || true
    command_exists R && R --quiet -e 'install.packages("pak", repos="https://cloud.r-project.org/")' || true

    #=========================================================================
    # STEP 5: Data tools
    #=========================================================================
    info "[5/12] Installing data tools..."
    brew_install duckdb
    brew_install sqlite
    brew_install xsv
    brew_install jq
    brew_install yq

    #=========================================================================
    # STEP 6: Database clients & HTTP tools
    #=========================================================================
    info "[6/12] Installing database clients and HTTP tools..."
    brew_install curl
    brew_install wget
    brew_install xh
    brew_install httpie

    #=========================================================================
    # STEP 7: Cloud & Git tooling
    #=========================================================================
    info "[7/12] Installing cloud and Git tooling..."
    brew_install awscli
    brew_install terraform
    brew_install rclone
    brew_install git
    brew_install gh
    brew_install lazygit
    brew_install delta

    #=========================================================================
    # STEP 8: File & system utilities
    #=========================================================================
    info "[8/12] Installing file and system utilities..."
    brew_install eza
    brew_install bat
    brew_install fd
    brew_install ripgrep
    brew_install fzf
    brew_install zoxide
    brew_install tree
    brew_install htop
    brew_install btop

    #=========================================================================
    # STEP 9: Remote tools
    #=========================================================================
    info "[9/12] Installing remote tools..."
    brew_install tmux
    brew_install rsync

    #=========================================================================
    # STEP 10: Editors
    #=========================================================================
    info "[10/12] Installing editors..."
    brew_install vim
    brew_install neovim
    brew_cask_install visual-studio-code

    #=========================================================================
    # STEP 11: Automation
    #=========================================================================
    info "[11/12] Installing automation tools..."
    brew_install just
    brew_install direnv
    brew_install tldr

    #=========================================================================
    # STEP 12: SSH, Tailscale, Git config
    #=========================================================================
    info "[12/12] Configuring SSH, Tailscale, and Git..."

    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    fi

    sudo systemsetup -setremotelogin on 2>/dev/null || true

    brew_cask_install tailscale
    [ -d /Applications/Tailscale.app ] && open /Applications/Tailscale.app

    echo ""
    echo "============================================================"
    echo "ADD SSH KEY TO GITHUB"
    echo "============================================================"
    echo ""
    cat ~/.ssh/id_ed25519.pub
    echo ""
    cat ~/.ssh/id_ed25519.pub | pbcopy && echo "(Copied to clipboard)"
    echo ""
    echo "1. Go to: https://github.com/settings/keys"
    echo "2. Click 'New SSH key' and paste"
    echo "============================================================"
    open "https://github.com/settings/keys" 2>/dev/null || true

    [ "$DRY_RUN" = false ] && read -rp "Press Enter after adding SSH key..."

    echo ""
    info "Configure Tailscale in the menu bar, then continue."
    [ "$DRY_RUN" = false ] && read -rp "Press Enter when done..."

    echo ""
    if [ "$DRY_RUN" = false ]; then
        read -rp "Git name: " GIT_NAME
        read -rp "Git email: " GIT_EMAIL
    else
        GIT_NAME="Dry Run"
        GIT_EMAIL="dryrun@example.com"
    fi
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    git config --global init.defaultBranch main
    git config --global core.pager delta

    command_exists gh && gh auth login -p ssh -h github.com || true

    append_if_missing ~/.zshrc "# bootstrap" $'\n# bootstrap\neval "$(zoxide init zsh)"\neval "$(direnv hook zsh)"\nalias ls="eza"\nalias ll="eza -la"\nalias cat="bat --style=plain"\nalias lg="lazygit"\n'

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
