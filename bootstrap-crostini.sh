#!/bin/bash
set -euo pipefail

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
error() { printf "[ERROR] %s\n" "$*"; exit 1; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

apt_package_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

append_if_missing() {
    local file="$1"
    local marker="$2"
    local content="$3"

    mkdir -p "$(dirname "$file")"
    if [ "$DRY_RUN" = true ]; then
        if ! grep -Fq "$marker" "$file" 2>/dev/null; then
            printf "[DRY RUN] append to %s: %s\n" "$file" "$marker"
        fi
    else
        if ! grep -Fq "$marker" "$file" 2>/dev/null; then
            printf "%s\n" "$content" >> "$file"
        fi
    fi
}

apt_update() {
    if [ "$DRY_RUN" = true ]; then
        printf "[DRY RUN] sudo apt-get update\n"
    else
        sudo apt-get update
    fi
}

apt_install_packages() {
    local packages=("$@")
    local missing=()
    for pkg in "${packages[@]}"; do
        if ! apt_package_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        info "All packages are already installed"
        return
    fi

    info "Installing apt packages: ${missing[*]}"
    apt_update
    if [ "$DRY_RUN" = true ]; then
        printf "[DRY RUN] sudo apt-get install -y %s\n" "${missing[*]}"
    else
        sudo apt-get install -y "${missing[@]}"
    fi
}

install_brewgh() {
    if ! command_exists gh && [ "$DRY_RUN" = false ]; then
        if ! apt_package_installed gh; then
            warn "gh is not installed and may not be available in apt sources"
        fi
    fi
}

PACKAGES=(
    build-essential curl wget git gh git-delta lazygit nodejs npm python3 python3-pip python3-venv
    r-base julia golang-go lua5.4 zsh fzf ripgrep fd-find bat jq yq 
    ranger ncdu tree trash-cli htop btop mosh rsync nmap netcat podman binwalk binutils pandoc
)

info "Installing Crostini packages..."
apt_install_packages "${PACKAGES[@]}"

info "Installing nvm..."
if [ ! -d "$HOME/.nvm" ]; then
    run "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.6/install.sh | bash"
else
    info "nvm already installed"
fi

if [ "$DRY_RUN" = false ] && command_exists bash && [ -f "$HOME/.nvm/nvm.sh" ]; then
    source "$HOME/.nvm/nvm.sh"
    if command_exists nvm; then
        run "nvm install --lts"
    fi
fi

info "Installing Python tools..."
if command_exists python3; then
    run "python3 -m pip install --user csvkit pgcli mycli litecli mitmproxy"
fi

info "Installing Playwright..."
if command_exists npm; then
    run "npm install -g playwright"
fi
if command_exists playwright; then
    run "npx playwright install --with-deps || true"
fi

info "Configuring SSH..."
run "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    run "ssh-keygen -t ed25519 -N \"\" -f ~/.ssh/id_ed25519"
else
    info "SSH key already exists"
fi
append_if_missing "$HOME/.ssh/config" "# crostini ssh config" $'\n# crostini ssh config\nHost *\n    ServerAliveInterval 60\n    AddKeysToAgent yes\n'
if [ "$DRY_RUN" = true ]; then
    printf "[DRY RUN] chmod 600 %s/.ssh/config\n" "$HOME"
else
    chmod 600 "$HOME/.ssh/config"
fi

info "Configuring Git..."
if [ "$DRY_RUN" = false ]; then
    read -rp "Git name: " GIT_NAME
    read -rp "Git email: " GIT_EMAIL
else
    GIT_NAME="Dry Run"
    GIT_EMAIL="dryrun@example.com"
    printf "[DRY RUN] git config user.name %s\n" "$GIT_NAME"
    printf "[DRY RUN] git config user.email %s\n" "$GIT_EMAIL"
fi
run "git config --global user.name \"$GIT_NAME\""
run "git config --global user.email \"$GIT_EMAIL\""
run "git config --global init.defaultBranch main"
run "git config --global core.pager delta"
run "git config --global delta.side-by-side true"

if command_exists gh; then
    run "gh auth login -p ssh -h github.com || true"
fi

info "Installing VS Code extensions..."
EXTENSIONS=(
    ms-python.python ms-python.vscode-pylance ms-toolsai.jupyter
    REditorSupport.r quarto.quarto ms-toolsai.datawrangler
    mechatroner.rainbow-csv GrapeCity.gc-excelviewer qwtel.sqlite-viewer
    duckdb.duckdb-vscode dbaeumer.vscode-eslint esbenp.prettier-vscode
    ritwickdey.LiveServer humao.rest-client rangav.vscode-thunder-client
    eamodio.gitlens mhutchie.git-graph usernamehw.errorlens
    wayou.vscode-todo-highlight streetsidesoftware.code-spell-checker
    christian-kohler.path-intellisense ms-vscode-remote.remote-ssh
    ms-azuretools.vscode-docker redhat.vscode-yaml hashicorp.terraform
    golang.go julialang.language-julia sumneko.lua
    GitHub.copilot GitHub.copilot-chat
)
for ext in "${EXTENSIONS[@]}"; do
    if command_exists code; then
        run "code --install-extension \"$ext\" --force 2>/dev/null || true"
    fi
done

info "Adding shell configuration..."
append_if_missing "$HOME/.bashrc" "# crostini bootstrap" $'\n# crostini bootstrap\nexport PATH="$HOME/.local/bin:$PATH"\nif [ -s "$HOME/.nvm/nvm.sh" ]; then\n  source "$HOME/.nvm/nvm.sh"\nfi\n'
append_if_missing "$HOME/.zshrc" "# crostini bootstrap" $'\n# crostini bootstrap\nexport PATH="$HOME/.local/bin:$PATH"\nif [ -s "$HOME/.nvm/nvm.sh" ]; then\n  source "$HOME/.nvm/nvm.sh"\nfi\n'

info "Bootstrap complete. Run 'source ~/.bashrc' or restart your terminal to apply shell changes."
