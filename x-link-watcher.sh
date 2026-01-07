#!/bin/bash
# X Link Watcher - monitors Obsidian vault, fetches X content via syndication API, analyzes with LLM
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Config
VAULT_DIR="${VAULT_DIR:-/home/obsidian/automation-vault}"
OUTPUT_DIR="${OUTPUT_DIR:-$VAULT_DIR/x-analyses}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/x-link-watcher}"
PROCESSED_FILE="$STATE_DIR/processed-links"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

mkdir -p "$STATE_DIR" "$OUTPUT_DIR"
touch "$PROCESSED_FILE"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

extract_x_links() {
    grep -oE 'https?://(x\.com|twitter\.com)/[A-Za-z0-9_]+/status/[0-9]+' "$1" 2>/dev/null | sort -u || true
}

fetch_tweet() {
    local url="$1"
    "$SCRIPT_DIR/fetch-tweet.sh" "$url" 2>/dev/null || echo "Could not fetch tweet"
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

    log "  Fetching via syndication API..."
    local content
    content=$(fetch_tweet "$link")

    if [[ -z "$content" || "$content" == "Could not fetch tweet" || ${#content} -lt 50 ]]; then
        log "  ERROR: Could not fetch content"
        return 1
    fi

    log "  Analyzing with Claude..."
    local analysis
    analysis=$(analyze_with_claude "$content" "$link")

    if [[ -z "$analysis" || "$analysis" == "Analysis failed" ]]; then
        log "  ERROR: Analysis failed"
        return 1
    fi

    local tweet_id=$(echo "$link" | grep -oE '[0-9]+$')
    local username=$(echo "$link" | grep -oE '(x\.com|twitter\.com)/[A-Za-z0-9_]+' | cut -d'/' -f2)
    local output_file="$OUTPUT_DIR/$(date '+%Y-%m-%d')-${username}-${tweet_id}.md"

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
$content
\`\`\`
EOF

    log "  ✓ Saved to: $output_file"
    echo "$link" >> "$PROCESSED_FILE"
}

process_file() {
    local file="$1"
    local filename=$(basename "$file")
    local links=$(extract_x_links "$file")
    [[ -z "$links" ]] && return

    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        grep -qF "$link" "$PROCESSED_FILE" 2>/dev/null && continue
        process_link "$link" "$filename" || true
    done <<< "$links"
}

check_api_key() {
    if [[ -z "$ANTHROPIC_API_KEY" ]]; then
        echo "ERROR: ANTHROPIC_API_KEY not set"
        exit 1
    fi
}

main() {
    check_api_key
    log "Scanning existing files..."
    find "$VAULT_DIR" -name "*.md" -type f ! -path "*/.obsidian/*" ! -path "*/x-analyses/*" 2>/dev/null | while read -r f; do
        process_file "$f"
    done
    log "Watching $VAULT_DIR for X links..."
    log "Output: $OUTPUT_DIR"
    log "---"
    inotifywait -m -r -e modify -e create -e moved_to --exclude '(\.obsidian|x-analyses)' --format '%w%f' "$VAULT_DIR" 2>/dev/null | while read -r file; do
        [[ "$file" == *.md ]] && process_file "$file"
    done
}

main "$@"
