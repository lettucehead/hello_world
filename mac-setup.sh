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
