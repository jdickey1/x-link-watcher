#!/bin/bash
# Process a single X link from webhook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK="$1"

VAULT_DIR="${VAULT_DIR:-/home/obsidian/automation-vault}"
OUTPUT_DIR="${OUTPUT_DIR:-$VAULT_DIR/x-analyses}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/x-link-watcher}"
PROCESSED_FILE="$STATE_DIR/processed-links"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

mkdir -p "$STATE_DIR" "$OUTPUT_DIR"
touch "$PROCESSED_FILE"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Check if already processed
if grep -qF "$LINK" "$PROCESSED_FILE" 2>/dev/null; then
    log "Already processed: $LINK"
    exit 0
fi

# Fetch tweet
log "Fetching: $LINK"
content=$("$SCRIPT_DIR/fetch-tweet.sh" "$LINK" 2>/dev/null) || {
    log "ERROR: Could not fetch tweet"
    exit 1
}

if [[ -z "$content" || ${#content} -lt 50 ]]; then
    log "ERROR: Empty or too short content"
    exit 1
fi

# Analyze with Claude
log "Analyzing with Claude..."
payload=$(jq -n \
    --arg content "$content" \
    --arg link "$LINK" \
    '{
        model: "claude-sonnet-4-20250514",
        max_tokens: 1024,
        messages: [{
            role: "user",
            content: ("Analyze this X/Twitter post. Provide:\n1. **Summary** (1-2 sentences)\n2. **Category** (tech/politics/business/culture/science/other)\n3. **Key Claims** (bullet points if factual claims made)\n4. **Sentiment** (positive/negative/neutral/mixed)\n5. **Worth Following Up?** (yes/no + brief reason)\n\nSource: " + $link + "\n\nContent:\n" + $content)
        }]
    }')

analysis=$(curl -s --max-time 60 https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$payload" | jq -r '.content[0].text // "Analysis failed"')

if [[ -z "$analysis" || "$analysis" == "Analysis failed" ]]; then
    log "ERROR: Analysis failed"
    exit 1
fi

# Save output
tweet_id=$(echo "$LINK" | grep -oE '[0-9]+$')
username=$(echo "$LINK" | grep -oE '(x\.com|twitter\.com)/[A-Za-z0-9_]+' | cut -d'/' -f2)
output_file="$OUTPUT_DIR/$(date '+%Y-%m-%d')-${username}-${tweet_id}.md"

cat > "$output_file" << EOF
# X Analysis: @${username}

**Source**: $LINK
**Analyzed**: $(date '+%Y-%m-%d %H:%M')
**Via**: webhook

---

$analysis

---

## Raw Content

\`\`\`
$content
\`\`\`
EOF

echo "$LINK" >> "$PROCESSED_FILE"
log "✓ Saved: $output_file"
