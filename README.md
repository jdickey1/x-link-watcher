# X Link Watcher

Monitors an Obsidian vault for X/Twitter links and queues them for processing.

## How It Works

1. Watches your Obsidian vault for file changes (using inotifywait)
2. When you add an X link to any markdown file (e.g., daily notes), it detects it
3. Adds the link to `x-link-queue.md` with metadata
4. Tracks processed links to avoid duplicates

## Installation

```bash
# Clone the repo
git clone https://github.com/YOURUSER/x-link-watcher.git
cd x-link-watcher

# Install as systemd service (defaults to obsidian user)
./install.sh

# Or specify user and vault path
./install.sh myuser /path/to/vault
```

## Usage

Just add X links to any markdown file in your vault. The watcher will automatically queue them in `x-link-queue.md`:

```markdown
# x-link-queue.md

## Pending

- [ ] https://x.com/someuser/status/123456789
  - Source: 2026-01-07.md
  - Added: 2026-01-07 14:30
```

## Configuration

Environment variables (set in systemd service or shell):

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULT_DIR` | `/home/obsidian/automation-vault` | Obsidian vault path |
| `QUEUE_FILE` | `$VAULT_DIR/x-link-queue.md` | Where to write queued links |
| `STATE_DIR` | `~/.local/state/x-link-watcher` | State/processed links storage |

## Service Commands

```bash
sudo systemctl status x-link-watcher    # Check status
sudo systemctl restart x-link-watcher   # Restart
sudo journalctl -u x-link-watcher -f    # Follow logs
```

## Processing the Queue

The queue file is plain markdown with checkboxes. Process it however you like:

- Manually review and check off items
- Script that feeds links to an AI for analysis
- Integration with other tools

Example processing script (not included):
```bash
# Extract unchecked links and process with claude-code
grep '^\- \[ \] https' x-link-queue.md | sed 's/- \[ \] //' | while read link; do
    claude -p "Analyze this X post: $link" >> analysis.md
done
```
