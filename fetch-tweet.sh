#!/bin/bash
# Fetch tweet content using Twitter's syndication API (no auth required)
set -euo pipefail

URL="$1"

# Extract username and tweet ID from URL
if [[ "$URL" =~ (x\.com|twitter\.com)/([^/]+)/status/([0-9]+) ]]; then
    USERNAME="${BASH_REMATCH[2]}"
    TWEET_ID="${BASH_REMATCH[3]}"
else
    echo "Error: Invalid X/Twitter URL"
    exit 1
fi

# Fetch from syndication API (returns HTML with embedded JSON)
RESPONSE=$(curl -sL --max-time 15 \
    -H "User-Agent: Mozilla/5.0 (compatible)" \
    "https://syndication.twitter.com/srv/timeline-profile/screen-name/$USERNAME" 2>/dev/null)

if [[ -z "$RESPONSE" ]]; then
    echo "Error: Could not fetch data"
    exit 1
fi

# Extract the JSON data from __NEXT_DATA__ script tag
JSON_DATA=$(echo "$RESPONSE" | grep -oP '(?<=<script id="__NEXT_DATA__" type="application/json">).*?(?=</script>)' | head -1)

if [[ -z "$JSON_DATA" ]]; then
    echo "Error: Could not parse response"
    exit 1
fi

# Find the specific tweet by ID and format output
echo "$JSON_DATA" | jq -r --arg tid "$TWEET_ID" '
.props.pageProps.timeline.entries[]
| select(.content.tweet.id_str == $tid)
| .content.tweet
| "Author: \(.user.name) (@\(.user.screen_name))\nPosted: \(.created_at)\n\nTweet:\n\(.full_text)\n\nMetrics:\n- Likes: \(.favorite_count)\n- Retweets: \(.retweet_count)\n- Replies: \(.reply_count)"
' 2>/dev/null

# If specific tweet not found, check if it's in recent tweets
if [[ $? -ne 0 ]] || [[ -z "$(echo "$JSON_DATA" | jq -r --arg tid "$TWEET_ID" '.props.pageProps.timeline.entries[] | select(.content.tweet.id_str == $tid)')" ]]; then
    echo "Note: Tweet $TWEET_ID not in recent timeline. Showing author's recent tweets:"
    echo ""
    echo "$JSON_DATA" | jq -r '
    .props.pageProps.timeline.entries[0:3][]
    | .content.tweet
    | "---\n\(.full_text)\n(\(.favorite_count) likes, \(.created_at | split(" ")[0:3] | join(" ")))"
    ' 2>/dev/null
fi
