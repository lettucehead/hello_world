#!/bin/bash
# GitHub SSH Setup and Push v0.1.0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="./logs/github-setup_${TIMESTAMP}.log"
TEMPFILE="./.temp_github_$$"

mkdir -p ./logs

trap "rm -f $TEMPFILE" EXIT

do_listing() {
    echo ""
    echo "============================================================"
    echo "SETUP SUMMARY"
    echo "============================================================"
    echo ""
    echo "Repository: https://github.com/${GITHUB_USER}/${REPO}"
    echo ""
    echo "Local files:"
    git ls-tree --name-only HEAD | sed 's/^/  /'
    echo ""
    echo "Remote files:"
    git ls-tree --name-only origin/main | sed 's/^/  /'
    echo ""
}

main() {
    echo "============================================================"
    echo "GITHUB SSH SETUP - $(date)"
    echo "============================================================"
    echo ""
    
    # Get configuration
    read -p "GitHub username: " GITHUB_USER
    read -p "Repository name: " REPO
    read -p "Files to add (space-separated, or 'all'): " FILES_INPUT
    
    echo ""
    
    # 1. Check/create SSH key
    echo "[1/7] Checking SSH key..."
    if [ ! -f ~/.ssh/id_ed25519.pub ]; then
        read -p "No SSH key found. Create one? (y/n): " CREATE_KEY
        if [ "$CREATE_KEY" = "y" ]; then
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
            echo "✗ SSH key required"
            exit 1
        fi
    else
        echo "✓ SSH key exists"
    fi
    
    # 2. Test GitHub connection
    echo ""
    echo "[2/7] Testing GitHub connection..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "✓ GitHub SSH authenticated"
    else
        echo ""
        echo "If not authenticated, add your key to GitHub:"
        echo ""
        cat ~/.ssh/id_ed25519.pub
        echo ""
        echo "Go to: https://github.com/settings/keys"
        echo ""
        read -p "Press Enter to continue anyway..."
    fi
    
    # 3. Configure git identity
    echo ""
    echo "[3/7] Checking git identity..."
    if [ -z "$(git config --global user.email)" ]; then
        read -p "Git email: " GIT_EMAIL
        read -p "Git name: " GIT_NAME
        git config --global user.email "$GIT_EMAIL"
        git config --global user.name "$GIT_NAME"
        echo "✓ Git identity configured"
    else
        echo "✓ Git identity: $(git config --global user.name) <$(git config --global user.email)>"
    fi
    
    # 4. Initialize repo
    echo ""
    echo "[4/7] Initializing git repository..."
    if [ ! -d .git ]; then
        git init
        echo "✓ Initialized new repository"
    else
        echo "✓ Repository exists"
    fi
    
    # 5. Set remote
    echo ""
    echo "[5/7] Setting remote..."
    git remote remove origin 2>/dev/null
    git remote add origin git@github.com:${GITHUB_USER}/${REPO}.git
    echo "✓ Remote set to git@github.com:${GITHUB_USER}/${REPO}.git"
    
    # 6. Add files
    echo ""
    echo "[6/7] Adding files..."
    if [ "$FILES_INPUT" = "all" ]; then
        git add .
        echo "✓ Added all files"
    else
        git add $FILES_INPUT
        echo "✓ Added: $FILES_INPUT"
    fi
    
    # Check if there's anything to commit
    if git diff --cached --quiet; then
        echo "No new changes to commit"
    else
        read -p "Commit message: " COMMIT_MSG
        git commit -m "$COMMIT_MSG"
        echo "✓ Committed"
    fi
    
    # Ensure we're on main branch
    git branch -M main
    
    # 7. Push
    echo ""
    echo "[7/7] Pushing to GitHub..."
    
    # Fetch remote to check state
    git fetch origin 2>/dev/null
    
    # Check if remote has commits
    if git rev-parse origin/main &>/dev/null; then
        echo "Remote has existing commits."
        echo ""
        echo "Options:"
        echo "  1. Merge (keep both local and remote files)"
        echo "  2. Force push (overwrite remote with local)"
        echo "  3. Cancel"
        echo ""
        read -p "Choose (1/2/3): " PUSH_OPTION
        
        case $PUSH_OPTION in
            1)
                git pull origin main --allow-unrelated-histories --no-rebase
                git push origin main
                ;;
            2)
                read -p "Are you sure? This will overwrite remote. (yes/no): " CONFIRM
                if [ "$CONFIRM" = "yes" ]; then
                    git push origin main --force
                else
                    echo "Cancelled"
                    exit 0
                fi
                ;;
            3)
                echo "Cancelled"
                exit 0
                ;;
            *)
                echo "Invalid option"
                exit 1
                ;;
        esac
    else
        # No remote commits, just push
        git push -u origin main
    fi
    
    echo ""
    echo "✓ Push complete"
    
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
if command -v pbcopy &>/dev/null; then
    cat "$TEMPFILE" | pbcopy 2>/dev/null && echo "✓ Copied to clipboard"
elif command -v xclip &>/dev/null; then
    cat "$TEMPFILE" | xclip -selection clipboard 2>/dev/null && echo "✓ Copied to clipboard"
fi

echo "✓ Saved to: $LOGFILE"
