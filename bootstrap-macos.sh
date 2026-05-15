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
        bash -c "$*"
    fi
}

info() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
error() { printf "[ERROR] %s\n" "$*"; exit 1; }

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

install_brew() {
    if ! command_exists brew; then
        info "Installing Homebrew..."
        run "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    else
        info "Homebrew already installed"
    fi
    if [ -x "/opt/homebrew/bin/brew" ]; then
        if [ "$DRY_RUN" = true ]; then
            printf "[DRY RUN] eval \"$(/opt/homebrew/bin/brew shellenv)\"\n"
        else
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    elif command_exists brew; then
        if [ "$DRY_RUN" = true ]; then
            printf "[DRY RUN] eval \"$(brew shellenv)\"\n"
        else
            eval "$(brew shellenv)"
        fi
    fi
}

brew_install() {
    local package="$1"
    shift
    if ! brew list --formula "$package" >/dev/null 2>&1; then
        info "Installing $package..."
        if [ "$DRY_RUN" = true ]; then
            printf "[DRY RUN] brew install %s %s\n" "$package" "$*"
        else
            brew install "$package" "$@"
        fi
    else
        info "$package is already installed"
    fi
}

brew_cask_install() {
    local package="$1"
    if ! brew list --cask --versions "$package" >/dev/null 2>&1; then
        info "Installing $package..."
        if [ "$DRY_RUN" = true ]; then
            printf "[DRY RUN] brew install --cask %s\n" "$package"
        else
            brew install --cask "$package"
        fi
    else
        info "$package is already installed"
    fi
}

install_gh_extension() {
    local extension="$1"
    if ! gh extension list | grep -q "^$extension" 2>/dev/null; then
        info "Installing gh extension $extension..."
        gh extension install "$extension"
    else
        info "gh extension $extension already installed"
    fi
}

install_brew

info "Installing Xcode CLI tools..."
if ! xcode-select -p >/dev/null 2>&1; then
    run "xcode-select --install 2>/dev/null || true"
else
    info "Xcode CLI tools already installed"
fi

info "Installing languages..."
brew_install node
brew_install python
brew_install r
brew_install julia
brew_install go
brew_install lua

info "Installing package managers..."
brew_install nvm
if ! command_exists uv; then
    run "curl -LsSf https://astral.sh/uv/install.sh | sh"
fi
if command_exists R; then
    run "R --quiet -e 'install.packages(\"pak\", repos=\"https://cloud.r-project.org/\")'"
fi

info "Installing data tools..."
brew_install duckdb
brew_install sqlite
brew_install xsv
brew_install jq
brew_install yq
if command_exists uv; then
    run "uv pip install csvkit || true"
fi

info "Installing database clients..."
if command_exists uv; then
    run "uv pip install pgcli mycli litecli || true"
fi
brew_install usql

info "Installing HTTP tooling..."
brew_install curl
brew_install wget
brew_install xh
brew_install httpie
if command_exists uv; then
    run "uv pip install mitmproxy || true"
fi

info "Installing cloud tooling..."
brew_install awscli
brew_install aws-vault
brew_install terraform
brew_install rclone
brew_cask_install session-manager-plugin

info "Installing Git tooling..."
brew_install git
brew_install gh
brew_install lazygit
brew_install delta
if command_exists gh; then
    install_gh_extension dlvhdr/gh-dash
fi

info "Installing file utilities..."
brew_install eza
brew_install bat
brew_install fd
brew_install ripgrep
brew_install fzf
brew_install zoxide
brew_install broot
brew_install ranger
brew_install ncdu
brew_install tree
brew_install trash-cli

info "Installing system utilities..."
brew_install htop
brew_install btop
brew_install procs
brew_install duf

info "Installing remote utilities..."
brew_install mosh
brew_install rsync
brew_install tmux
brew_install nmap
brew_install netcat
brew_install wireshark

info "Installing containers and reverse-engineering tools..."
brew_install podman
brew_install dive
brew_install hexyl
brew_install binwalk
brew_install binutils

info "Installing publishing tools..."
brew_install quarto
brew_install pandoc
brew_install hugo
brew_install tinytex
brew_install asciidoctor
brew_install glow

info "Installing editors..."
brew_install vim
brew_install neovim
brew_cask_install visual-studio-code
brew_cask_install positron

info "Installing automation tooling..."
brew_install just
brew_install hyperfine
brew_install direnv
if ! command_exists playwright; then
    run "npm install -g playwright"
fi
if command_exists playwright; then
    run "npx playwright install --with-deps || true"
fi

info "Installing utilities..."
brew_install tldr

info "Installing R packages..."
if command_exists R; then
    R --quiet -e 'pak::pak(c("knitr", "rmarkdown"))'
fi

info "Installing Julia packages..."
if command_exists julia; then
    julia -e 'using Pkg; Pkg.add("IJulia")'
fi

info "Configuring SSH..."
if [ "$DRY_RUN" = true ]; then
    printf "[DRY RUN] sudo systemsetup -setremotelogin on || true\n"
else
    sudo systemsetup -setremotelogin on || true
fi
run "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    run "ssh-keygen -t ed25519 -N \"\" -f ~/.ssh/id_ed25519"
fi
append_if_missing ~/.ssh/config "# hello_world ssh config" $'\n# hello_world ssh config\nHost *\n    ServerAliveInterval 60\n    AddKeysToAgent yes\n    UseKeychain yes\n'
if [ "$DRY_RUN" = true ]; then
    printf "[DRY RUN] chmod 600 ~/.ssh/config\n"
else
    chmod 600 ~/.ssh/config
fi

info "Installing Tailscale..."
brew_install tailscale
if [ -d /Applications/Tailscale.app ]; then
    run "open /Applications/Tailscale.app || true"
fi
info "Approve Tailscale in the menu bar, then continue."
if [ "$DRY_RUN" = false ]; then
    read -rp "Press Enter when done... "
else
    printf "[DRY RUN] skip Tailscale approval prompt\n"
fi

info "Configuring Git..."
if [ "$DRY_RUN" = false ]; then
    read -rp "Git name: " GIT_NAME
    read -rp "Git email: " GIT_EMAIL
else
    GIT_NAME="Dry Run"
    GIT_EMAIL="dryrun@example.com"
    printf "[DRY RUN] set Git name and email to %s / %s\n" "$GIT_NAME" "$GIT_EMAIL"
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
append_if_missing ~/.zshrc "# hello_world bootstrap" $'\n# hello_world bootstrap\neval "$(/opt/homebrew/bin/brew shellenv)"\neval "$(zoxide init zsh)"\neval "$(direnv hook zsh)"\nalias ls=\'eza\'\nalias ll=\'eza -la\'\nalias cat=\'bat --style=plain\'\nalias grep=\'rg\'\nalias find=\'fd\'\nalias du=\'duf\'\nalias ps=\'procs\'\nalias rm=\'trash\'\nalias cd=\'z\'\nalias lg=\'lazygit\'\nalias gs=\'git status\'\nalias ga=\'git add\'\nalias gc=\'git commit\'\nalias gp=\'git push\'\nalias csv=\'xsv\'\nalias duck=\'duckdb\'\nalias http=\'xh\'\nalias pg=\'pgcli\'\nalias my=\'mycli\'\nalias lite=\'litecli\'\nalias tf=\'terraform\'\nalias cleanup=\'brew cleanup && npm cache clean --force && uv cache clean\'\n'

info "Bootstrap complete. Run 'source ~/.zshrc' or restart your terminal to apply shell changes."

if [ "$(uname)" = "Darwin" ]; then
    echo ""
    echo "=== Done ==="
    echo "Local SSH: $(whoami)@$(ipconfig getifaddr en0 2>/dev/null || echo 'unknown')"
    echo "Tailscale SSH: $(whoami)@$(tailscale ip -4 2>/dev/null || echo 'approve device')"
    echo ""
    echo "GitHub Copilot: Sign in via VS Code (Ctrl+Shift+P → GitHub Copilot: Sign In)"
fi
