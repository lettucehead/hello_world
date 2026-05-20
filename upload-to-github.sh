#!/bin/bash
# Upload setup scripts to GitHub v0.1.0

GITHUB_USER="lettucehead"
REPO="hello_world"
BRANCH="main"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="./logs/upload-to-github_${TIMESTAMP}.log"
TEMPFILE="./.temp_upload_$$"

mkdir -p ./logs

trap "rm -f $TEMPFILE" EXIT

do_listing() {
    echo ""
    echo "============================================================"
    echo "UPLOAD SUMMARY"
    echo "============================================================"
    echo ""
    echo "Repository: https://github.com/${GITHUB_USER}/${REPO}"
    echo ""
    echo "Files uploaded:"
    echo "  - mac-setup.sh"
    echo "  - chromebook-setup.sh"
    echo ""
}

create_mac_setup() {
    cat > mac-setup.sh << 'MACSCRIPT'
#!/bin/bash
# Mac to Chromebook SSH Setup via Tailscale v0.1.0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="./logs/mac-setup_${TIMESTAMP}.log"
TEMPFILE="./.temp_setup_$$"

mkdir -p ./logs

trap "rm -f $TEMPFILE" EXIT

do_listing() {
    echo ""
    echo "============================================================"
    echo "SETUP SUMMARY"
    echo "============================================================"
    echo ""
    echo "Target: ${CHROMEBOOK_USER}@${CHROMEBOOK_IP}"
    echo "Helper script: ~/job-helper.sh"
    echo ""
    echo "Commands available:"
    echo "  ~/job-helper.sh add 'URL'"
    echo "  ~/job-helper.sh list"
    echo "  ~/job-helper.sh run"
    echo "  ~/job-helper.sh status"
    echo "  ~/job-helper.sh download"
    echo "  ~/job-helper.sh ssh"
}

create_helper_script() {
    cat > ~/job-helper.sh << HELPER
#!/bin/bash
# Job Scraper Helper v0.1.0

CHROMEBOOK="${CHROMEBOOK_USER}@${CHROMEBOOK_IP}"
REMOTE_DIR="${REMOTE_DIR}"

show_help() {
    echo "Job Scraper Helper"
    echo ""
    echo "Usage: job-helper.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  add 'URL'    Add a job URL to scrape"
    echo "  list         List all saved URLs"
    echo "  run          Run the scraper"
    echo "  status       Check scraper status"
    echo "  download     Download results to Mac"
    echo "  ssh          SSH into Chromebook"
    echo "  help         Show this help"
}

case "\\\$1" in
    add)
        [ -z "\\\$2" ] && echo "Usage: job-helper.sh add 'URL'" && exit 1
        ssh \\\$CHROMEBOOK "cd \\\$REMOTE_DIR && ./add-url.sh '\\\$2'"
        ;;
    list)
        ssh \\\$CHROMEBOOK "cd \\\$REMOTE_DIR && ./list-urls.sh"
        ;;
    run)
        ssh \\\$CHROMEBOOK "cd \\\$REMOTE_DIR && ./run-scraper.sh"
        ;;
    status)
        ssh \\\$CHROMEBOOK "cd \\\$REMOTE_DIR && ./status.sh"
        ;;
    download)
        mkdir -p ~/Downloads/job-scraper-results
        scp -r \\\$CHROMEBOOK:\\\$REMOTE_DIR/output/* ~/Downloads/job-scraper-results/
        echo "✓ Downloaded to ~/Downloads/job-scraper-results/"
        ;;
    ssh)
        ssh \\\$CHROMEBOOK
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo "Unknown command: \\\$1"
        show_help
        exit 1
        ;;
esac
HELPER
    chmod +x ~/job-helper.sh
}

main() {
    echo "============================================================"
    echo "MAC TO CHROMEBOOK SSH SETUP - \$(date)"
    echo "============================================================"
    echo ""
    
    read -p "Chromebook Tailscale IP (run 'tailscale ip -4' on Chromebook): " CHROMEBOOK_IP
    read -p "Chromebook username: " CHROMEBOOK_USER
    read -p "Remote project directory [~/job-scraper]: " REMOTE_DIR
    REMOTE_DIR=\${REMOTE_DIR:-~/job-scraper}
    
    echo ""
    echo "Target: \${CHROMEBOOK_USER}@\${CHROMEBOOK_IP}"
    echo ""
    
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo "[1/4] Creating SSH key..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    else
        echo "[1/4] ✓ SSH key exists"
    fi
    
    echo "[2/4] Copying SSH key to Chromebook..."
    ssh-copy-id -i ~/.ssh/id_ed25519.pub \${CHROMEBOOK_USER}@\${CHROMEBOOK_IP}
    
    echo "[3/4] Creating ~/job-helper.sh..."
    create_helper_script
    
    echo "[4/4] Testing connection..."
    if ssh -o ConnectTimeout=5 \${CHROMEBOOK_USER}@\${CHROMEBOOK_IP} "echo '✓ Connection successful'"; then
        do_listing
    else
        echo "✗ Connection failed"
        exit 1
    fi
}

exec > >(tee "\$TEMPFILE") 2>&1
main "\$@"
exec > /dev/tty 2>&1
cp "\$TEMPFILE" "\$LOGFILE"
cat "\$TEMPFILE" | pbcopy 2>/dev/null && echo "✓ Copied to clipboard"
echo "✓ Saved to: \$LOGFILE"
MACSCRIPT
}

create_chromebook_setup() {
    cat > chromebook-setup.sh << 'CBSCRIPT'
#!/bin/bash
# Chromebook to Mac SSH Setup via Tailscale v0.1.0

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="./logs/chromebook-setup_${TIMESTAMP}.log"
TEMPFILE="./.temp_setup_$$"

mkdir -p ./logs

trap "rm -f $TEMPFILE" EXIT

do_listing() {
    echo ""
    echo "============================================================"
    echo "SETUP SUMMARY"
    echo "============================================================"
    echo ""
    echo "Target: ${MAC_USER}@${MAC_IP}"
    echo "Helper script: ~/send-to-mac.sh"
    echo ""
    echo "Commands available:"
    echo "  ~/send-to-mac.sh jobs"
    echo "  ~/send-to-mac.sh files <files>"
    echo "  ~/send-to-mac.sh logs"
}

create_helper_script() {
    cat > ~/send-to-mac.sh << HELPER
#!/bin/bash
# Send to Mac v0.1.0

MAC="${MAC_USER}@${MAC_IP}"
DEST="${DEST_DIR}"
LOG_DIR="${LOG_DIR}"

mkdir -p "\\\$LOG_DIR"
LOGFILE="\\\$LOG_DIR/send-to-mac_\\\$(date +%Y%m%d_%H%M%S).log"

log() { echo "\\\$1" | tee -a "\\\$LOGFILE"; }

show_help() {
    echo "Send to Mac"
    echo ""
    echo "Usage: send-to-mac.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  jobs             Send job scraper results"
    echo "  files <files>    Send specific files"
    echo "  logs             Send log files"
    echo "  help             Show this help"
}

ssh \\\$MAC "mkdir -p \\\$DEST" 2>/dev/null

case "\\\$1" in
    jobs)
        log "Sending job scraper results..."
        scp -r ~/job-scraper/output \\\$MAC:\\\$DEST/job-scraper/ 2>&1 | tee -a "\\\$LOGFILE"
        ;;
    files)
        shift
        [ \\\$# -eq 0 ] && echo "Usage: send-to-mac.sh files <file1> <file2>..." && exit 1
        log "Sending files: \\\$@"
        scp "\\\$@" \\\$MAC:\\\$DEST/ 2>&1 | tee -a "\\\$LOGFILE"
        ;;
    logs)
        log "Sending logs..."
        scp -r ~/job-scraper/logs \\\$MAC:\\\$DEST/job-scraper-logs/ 2>&1 | tee -a "\\\$LOGFILE"
        ;;
    help|--help|-h|"")
        show_help
        exit 0
        ;;
    *)
        echo "Unknown command: \\\$1"
        show_help
        exit 1
        ;;
esac

log ""
log "============================================================"
log "TRANSFER SUMMARY"
log "============================================================"
log ""
log "Sent to: \\\$MAC:\\\$DEST"
echo "✓ Log saved to: \\\$LOGFILE"
HELPER
    chmod +x ~/send-to-mac.sh
}

main() {
    echo "============================================================"
    echo "CHROMEBOOK TO MAC SSH SETUP - \$(date)"
    echo "============================================================"
    echo ""
    
    read -p "Mac Tailscale IP (run 'tailscale ip -4' on Mac): " MAC_IP
    read -p "Mac username: " MAC_USER
    read -p "Destination directory on Mac [~/Downloads/from-chromebook]: " DEST_DIR
    DEST_DIR=\${DEST_DIR:-~/Downloads/from-chromebook}
    LOG_DIR="\$HOME/job-scraper/logs"
    
    echo ""
    echo "Target: \${MAC_USER}@\${MAC_IP}"
    echo ""
    
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        echo "[1/4] Creating SSH key..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    else
        echo "[1/4] ✓ SSH key exists"
    fi
    
    echo "[2/4] Copying SSH key to Mac..."
    ssh-copy-id -i ~/.ssh/id_ed25519.pub \${MAC_USER}@\${MAC_IP}
    
    echo "[3/4] Creating ~/send-to-mac.sh..."
    create_helper_script
    
    echo "[4/4] Testing connection..."
    if ssh -o ConnectTimeout=5 \${MAC_USER}@\${MAC_IP} "echo '✓ Connection successful'"; then
        do_listing
    else
        echo "✗ Connection failed"
        exit 1
    fi
}

exec > >(tee "\$TEMPFILE") 2>&1
main "\$@"
exec > /dev/tty 2>&1
cp "\$TEMPFILE" "\$LOGFILE"
cat "\$TEMPFILE" | xclip -selection clipboard 2>/dev/null && echo "✓ Copied to clipboard"
echo "✓ Saved to: \$LOGFILE"
CBSCRIPT
}

main() {
    echo "============================================================"
    echo "UPLOAD TO GITHUB - $(date)"
    echo "============================================================"
    echo ""
    
    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        echo "✗ GitHub CLI (gh) not installed"
        echo "  Install: brew install gh (Mac) or see https://cli.github.com"
        exit 1
    fi
    
    # Check auth
    if ! gh auth status &> /dev/null; then
        echo "GitHub CLI not authenticated. Running: gh auth login"
        gh auth login
    fi
    
    echo "[1/4] Creating script files..."
    create_mac_setup
    create_chromebook_setup
    chmod +x mac-setup.sh chromebook-setup.sh
    echo "✓ Created mac-setup.sh"
    echo "✓ Created chromebook-setup.sh"
    
    echo ""
    echo "[2/4] Checking repository..."
    if ! gh repo view ${GITHUB_USER}/${REPO} &> /dev/null; then
        echo "Creating repository ${REPO}..."
        gh repo create ${REPO} --public --confirm
    else
        echo "✓ Repository exists"
    fi
    
    echo ""
    echo "[3/4] Initializing git..."
    if [ ! -d .git ]; then
        git init
        git branch -M ${BRANCH}
    fi
    
    git remote remove origin 2>/dev/null
    git remote add origin git@github.com:${GITHUB_USER}/${REPO}.git
    
    echo ""
    echo "[4/4] Pushing to GitHub..."
    git add mac-setup.sh chromebook-setup.sh
    git commit -m "Add Tailscale SSH setup scripts" 2>/dev/null || git commit --amend -m "Add Tailscale SSH setup scripts"
    git push -u origin ${BRANCH} --force
    
    do_listing
}

exec > >(tee "$TEMPFILE") 2>&1
main "$@"
exec > /dev/tty 2>&1
cp "$TEMPFILE" "$LOGFILE"
cat "$TEMPFILE" | pbcopy 2>/dev/null && echo "✓ Copied to clipboard"
echo "✓ Saved to: $LOGFILE"
