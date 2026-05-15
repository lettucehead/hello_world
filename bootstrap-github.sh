#!/bin/bash
# Bootstrap GitHub Setup v0.1.0
# Run this on a new computer to get github-setup.sh

GITHUB_USER="lettucehead"
REPO="hello_world"

echo "============================================================"
echo "BOOTSTRAP GITHUB - $(date)"
echo "============================================================"
echo ""

# 1. Check for git
echo "[1/4] Checking git..."
if ! command -v git &>/dev/null; then
    echo "Installing git..."
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y git
    elif command -v brew &>/dev/null; then
        brew install git
    else
        echo "✗ Please install git manually"
        exit 1
    fi
fi
echo "✓ git installed"

# 2. Create SSH key if needed
echo ""
echo "[2/4] Checking SSH key..."
if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    read -p "Email for SSH key: " EMAIL
    ssh-keygen -t ed25519 -C "$EMAIL" -N "" -f ~/.ssh/id_ed25519
    echo ""
    echo "============================================================"
    echo "ADD THIS KEY TO GITHUB"
    echo "============================================================"
    echo ""
    echo "1. Go to: https://github.com/settings/keys"
    echo "2. Click 'New SSH key'"
    echo "3. Paste this key:"
    echo ""
    cat ~/.ssh/id_ed25519.pub
    echo ""
    echo "============================================================"
    echo ""
    read -p "Press Enter after adding key to GitHub..."
else
    echo "✓ SSH key exists"
fi

# 3. Configure git identity
echo ""
echo "[3/4] Checking git identity..."
if [ -z "$(git config --global user.email)" ]; then
    read -p "Git email: " GIT_EMAIL
    read -p "Git name: " GIT_NAME
    git config --global user.email "$GIT_EMAIL"
    git config --global user.name "$GIT_NAME"
fi
echo "✓ Git identity: $(git config --global user.name) <$(git config --global user.email)>"

# 4. Clone repo
echo ""
echo "[4/4] Cloning repository..."
CLONE_DIR="$HOME/${REPO}"

if [ -d "$CLONE_DIR" ]; then
    echo "Directory exists. Pulling latest..."
    cd "$CLONE_DIR"
    git pull origin main
else
    git clone git@github.com:${GITHUB_USER}/${REPO}.git "$CLONE_DIR"
    cd "$CLONE_DIR"
fi

chmod +x *.sh 2>/dev/null

echo ""
echo "============================================================"
echo "SETUP COMPLETE"
echo "============================================================"
echo ""
echo "Repository cloned to: $CLONE_DIR"
echo ""
echo "Available scripts:"
ls -1 *.sh 2>/dev/null | sed 's/^/  .\//'
echo ""
echo "Next steps:"
echo "  cd $CLONE_DIR"
echo "  ./github-setup.sh"
echo ""
