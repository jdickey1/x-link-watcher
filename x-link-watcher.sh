#!/bin/bash
# X Link Watcher - monitors Obsidian vault, fetches X content, analyzes with LLM
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Config
VAULT_DIR="${VAULT_DIR:-/home/obsidian/automation-vault}"
OUTPUT_DIR="${OUTPUT_DIR:-$VAULT_DIR/x-analyses}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/x-link-watcher}"
PROCESSED_FILE="$STATE_DIR/processed-links"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

# Create directories
mkdir -p "$STATE_DIR" "$OUTPUT_DIR"
touch "$PROCESSED_FILE"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

extract_x_links() {
    local file="$1"
    grep -oE 'https?://(x\.com|twitter\.com)/[A-Za-z0-9_]+/status/[0-9]+' "$file" 2>/dev/null | sort -u || true
}

fetch_content() {
    local url="$1"
    # jina.ai reader - handles JS, returns markdown
    curl -sL --max-time 30 "https://r.jina.ai/$url" 2>/dev/null | head -c 12000
}

analyze_with_claude() {
    local content="$1"
    local link="$2"

    local payload=$(jq -n \
        --arg content "$content" \
        --arg link "$link" \
        '{
            model: "claude-sonnet-4-20250514",
            max_tokens: 1024,
            messages: [{
                role: "user",
                content: ("Analyze this X/Twitter post. Provide:\n1. **Summary** (1-2 sentences)\n2. **Category** (tech/politics/business/culture/science/other)\n3. **Key Claims** (bullet points if factual claims made)\n4. **Sentiment** (positive/negative/neutral/mixed)\n5. **Worth Following Up?** (yes/no + brief reason)\n\nSource: " + $link + "\n\nContent:\n" + $content)
            }]
        }')

    curl -s --max-time 60 https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload" | jq -r '.content[0].text // "Analysis failed"'
}

process_link() {
    local link="$1"
    local source_file="$2"

    log "Processing: $link"

    # Fetch content
    log "  Fetching content..."
    local content
    content=$(fetch_content "$link")

    if [[ -z "$content" || ${#content} -lt 100 ]]; then
        log "  ERROR: Could not fetch content"
        return 1
    fi

    # Analyze
    log "  Analyzing with Claude..."
    local analysis
    analysis=$(analyze_with_claude "$content" "$link")

    if [[ -z "$analysis" || "$analysis" == "Analysis failed" ]]; then
        log "  ERROR: Analysis failed"
        return 1
    fi

    # Extract username and tweet ID for filename
    local tweet_id=$(echo "$link" | grep -oE '[0-9]+$')
    local username=$(echo "$link" | grep -oE '(x\.com|twitter\.com)/[A-Za-z0-9_]+' | cut -d'/' -f2)
    local date_str=$(date '+%Y-%m-%d')
    local output_file="$OUTPUT_DIR/${date_str}-${username}-${tweet_id}.md"

    # Write analysis to file
    cat > "$output_file" << EOF
# X Analysis: @${username}

**Source**: $link
**Analyzed**: $(date '+%Y-%m-%d %H:%M')
**From**: $source_file

---

$analysis

---

## Raw Content

\`\`\`
${content:0:4000}
\`\`\`
EOF

    log "  ✓ Saved to: $output_file"
    echo "$link" >> "$PROCESSED_FILE"
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

        process_link "$link" "$filename" || true
    done <<< "$links"
}

check_api_key() {
    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        echo "ERROR: ANTHROPIC_API_KEY environment variable not set"
        echo "Add to /etc/systemd/system/x-link-watcher.service:"
        echo "  Environment=ANTHROPIC_API_KEY=your-key-here"
        exit 1
    fi
}

scan_existing() {
    log "Scanning existing files for unprocessed links..."
    find "$VAULT_DIR" -name "*.md" -type f ! -path "*/.obsidian/*" ! -path "*/x-analyses/*" 2>/dev/null | while read -r file; do
        process_file "$file"
    done
}

watch_vault() {
    log "Watching $VAULT_DIR for X links..."
    log "Output dir: $OUTPUT_DIR"
    log "---"

    inotifywait -m -r -e modify -e create -e moved_to \
        --exclude '(\.obsidian|x-analyses)' \
        --format '%w%f' "$VAULT_DIR" 2>/dev/null | while read -r file; do
        if [[ "$file" == *.md ]]; then
            process_file "$file"
        fi
    done
}

main() {
    check_api_key
    scan_existing
    watch_vault
}

main "$@"
