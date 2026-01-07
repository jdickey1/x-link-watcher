# X Link Watcher

Watches your Obsidian vault for X/Twitter links, fetches thread content, and analyzes them with Claude.

## How It Works

```
Daily Note → Detect X Link → Fetch Thread → Claude Analysis → Obsidian Note
   (2 clicks)     (instant)      (jina.ai)      (API call)      (x-analyses/)
```

1. You share an X link to your daily note (iOS share sheet, etc.)
2. Watcher detects the file change via inotifywait
3. Fetches the thread content using jina.ai reader
4. Sends to Claude API for categorization and analysis
5. Writes structured analysis to `x-analyses/` folder in your vault

## Installation

```bash
git clone https://github.com/jdickey1/x-link-watcher.git
cd x-link-watcher

# Install as systemd service
./install.sh obsidian /path/to/vault

# Add your Anthropic API key to the service
sudo systemctl edit x-link-watcher
# Add: Environment=ANTHROPIC_API_KEY=sk-ant-...
```

Or manually:
```bash
# Create service file
sudo cp x-link-watcher.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now x-link-watcher
```

## Configuration

Environment variables (set in systemd service):

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULT_DIR` | `/home/obsidian/automation-vault` | Obsidian vault path |
| `OUTPUT_DIR` | `$VAULT_DIR/x-analyses` | Where analysis notes go |
| `ANTHROPIC_API_KEY` | (required) | Your Claude API key |

## Output Format

Each analyzed link creates a note like:

```markdown
# X Analysis: @username

**Source**: https://x.com/user/status/123
**Analyzed**: 2026-01-07 14:30
**From**: 2026-01-07.md

---

1. **Summary**: Brief description of the post
2. **Category**: tech/politics/business/culture/science/other
3. **Key Claims**: Bullet points of factual claims
4. **Sentiment**: positive/negative/neutral/mixed
5. **Worth Following Up?**: yes/no + reason

---

## Raw Content
(fetched thread content)
```

## Commands

```bash
sudo journalctl -u x-link-watcher -f    # Follow logs
sudo systemctl restart x-link-watcher   # Restart
sudo systemctl status x-link-watcher    # Check status
```

## Manual Processing

Process a single link:
```bash
export ANTHROPIC_API_KEY=sk-ant-...
./process-link.sh "https://x.com/user/status/123"
```

## How Content is Fetched

Uses [jina.ai reader](https://jina.ai/reader/) to fetch X content:
- Free, no authentication needed
- Handles JavaScript rendering
- Returns clean markdown

## Dependencies

- `inotify-tools` - file watching
- `curl` - HTTP requests
- `jq` - JSON processing
- Anthropic API key
