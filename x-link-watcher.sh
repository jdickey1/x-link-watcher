#!/bin/bash
# X Link Watcher - monitors Obsidian vault for new X/Twitter links
# Queues them for processing

set -euo pipefail

# Config (override via environment or config file)
VAULT_DIR="${VAULT_DIR:-/home/obsidian/automation-vault}"
QUEUE_FILE="${QUEUE_FILE:-$VAULT_DIR/x-link-queue.md}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/x-link-watcher}"
PROCESSED_FILE="$STATE_DIR/processed-links"

# Create state directory
mkdir -p "$STATE_DIR"
touch "$PROCESSED_FILE"

# Initialize queue file if needed
init_queue() {
    if [[ ! -f "$QUEUE_FILE" ]]; then
        cat > "$QUEUE_FILE" << 'EOF'
# X Link Queue

Links captured from daily notes, ready for processing.

## Pending

EOF
    fi
}

extract_x_links() {
    local file="$1"
    # Match x.com and twitter.com links (handles trailing punctuation)
    grep -oE 'https?://(x\.com|twitter\.com)/[A-Za-z0-9_]+/status/[0-9]+' "$file" 2>/dev/null | sort -u || true
}

process_file() {
    local file="$1"
    local filename=$(basename "$file")
    local links
    links=$(extract_x_links "$file")

    [[ -z "$links" ]] && return

    while IFS= read -r link; do
        [[ -z "$link" ]] && continue

        # Skip if already processed
        if grep -qF "$link" "$PROCESSED_FILE" 2>/dev/null; then
            continue
        fi

        # Add to queue with metadata
        echo "- [ ] $link" >> "$QUEUE_FILE"
        echo "  - Source: $filename" >> "$QUEUE_FILE"
        echo "  - Added: $(date '+%Y-%m-%d %H:%M')" >> "$QUEUE_FILE"
        echo "" >> "$QUEUE_FILE"

        # Mark as processed
        echo "$link" >> "$PROCESSED_FILE"
        echo "[$(date '+%H:%M:%S')] Queued: $link (from $filename)"
    done <<< "$links"
}

scan_existing() {
    echo "Scanning existing files for unprocessed links..."
    find "$VAULT_DIR" -name "*.md" -type f ! -path "*/.obsidian/*" ! -name "x-link-queue.md" | while read -r file; do
        process_file "$file"
    done
}

watch_vault() {
    echo "Watching $VAULT_DIR for X links..."
    echo "Queue file: $QUEUE_FILE"
    echo "---"

    inotifywait -m -r -e modify -e create -e moved_to \
        --exclude '(\.obsidian|x-link-queue\.md)' \
        --format '%w%f' "$VAULT_DIR" 2>/dev/null | while read -r file; do
        if [[ "$file" == *.md ]]; then
            process_file "$file"
        fi
    done
}

main() {
    init_queue
    scan_existing
    watch_vault
}

main "$@"
