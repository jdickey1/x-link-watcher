#!/bin/bash
# Process a single X link: fetch content, send to LLM, return analysis
set -euo pipefail

LINK="$1"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

if [[ -z "$ANTHROPIC_API_KEY" ]]; then
    echo "ERROR: ANTHROPIC_API_KEY not set" >&2
    exit 1
fi

# Fetch X content using jina reader (converts to markdown)
fetch_content() {
    local url="$1"
    # jina.ai reader - free, no auth needed, handles JS rendering
    curl -sL "https://r.jina.ai/$url" 2>/dev/null | head -c 8000
}

# Send to Claude API for analysis
analyze_content() {
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
                content: ("Analyze this X/Twitter post. Provide:\n1. **Summary** (1-2 sentences)\n2. **Category** (tech/politics/business/culture/other)\n3. **Key Claims** (bullet points if any factual claims)\n4. **Sentiment** (positive/negative/neutral/mixed)\n5. **Worth Following Up?** (yes/no + why)\n\nSource: " + $link + "\n\nContent:\n" + $content)
            }]
        }')

    curl -s https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload" | jq -r '.content[0].text // "Analysis failed"'
}

echo "Fetching content from $LINK..."
content=$(fetch_content "$LINK")

if [[ -z "$content" || "$content" == *"error"* ]]; then
    echo "ERROR: Could not fetch content from $LINK" >&2
    exit 1
fi

echo "Analyzing with Claude..."
analysis=$(analyze_content "$content" "$LINK")

echo "$analysis"
