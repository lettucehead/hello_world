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
