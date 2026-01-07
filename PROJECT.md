# X Link Watcher Project

## Vision

A 2-click workflow to capture interesting X posts, get AI analysis, and generate project plans:

```
X Post → Grok Summary → Daily Note → LiveSync → Watcher → Claude Analysis → Project Plan → User Approval
```

## The Full Flow

1. **User sees something interesting on X**
2. **User shares X link to Grok** - Grok evaluates/expands/summarizes the content
3. **Grok generates a share link** with its analysis
4. **User shares Grok link to Obsidian daily note** (2 clicks)
5. **LiveSync syncs** the daily note to `/home/obsidian/automation-vault/YYYY-MM-DD.md`
6. **Watcher detects new Grok link** in the daily note
7. **Claude Code reads Grok content** and understands the idea
8. **Claude Code creates a project plan** based on:
   - The idea from Grok's analysis
   - Knowledge of VPS structure and tools
   - Knowledge of Mac Mini server structure and tools
9. **Plan is submitted to user** for review and approval

## Current State

### What's Built

| Component | Status | Location |
|-----------|--------|----------|
| File watcher (inotifywait) | ✅ Working | `/home/obsidian/x-link-watcher/x-link-watcher.sh` |
| Tweet fetcher (syndication API) | ✅ Working | `/home/obsidian/x-link-watcher/fetch-tweet.sh` |
| Tweet fetcher (Playwright) | ✅ Built | `/home/obsidian/x-link-watcher/fetch-tweet.js` |
| Claude analysis | ✅ Working | Integrated in watcher |
| Webhook server | ✅ Working | `/home/obsidian/x-link-watcher/webhook.js` |
| Systemd services | ✅ Running | `x-link-watcher.service`, `x-link-webhook.service` |
| LiveSync | ✅ Working | Syncs to `/home/obsidian/automation-vault/` |
| GitHub repo | ✅ Created | https://github.com/jdickey1/x-link-watcher |

### What's NOT Built Yet

| Component | Status | Notes |
|-----------|--------|-------|
| Grok link detection | ❌ Not built | Watcher currently only looks for X links, not grok.com links |
| Grok content fetcher | ❌ Not built | Need Playwright to bypass Cloudflare protection |
| Project plan generator | ❌ Not built | Claude Code integration to create implementation plans |
| Plan submission to user | ❌ Not built | Notification/approval workflow |
| VPS/Mac Mini context | ❌ Not built | Need to provide Claude with system knowledge |

## Architecture

### Files

```
/home/obsidian/x-link-watcher/
├── x-link-watcher.sh      # Main file watcher daemon
├── fetch-tweet.sh         # Fetch tweets via syndication API
├── fetch-tweet.js         # Fetch tweets via Playwright (backup)
├── process-webhook.sh     # Process links from webhook
├── webhook.js             # HTTP webhook server
├── package.json           # Node dependencies
├── node_modules/          # Playwright, etc.
├── README.md              # Usage docs
└── PROJECT.md             # This file
```

### Services

```
x-link-watcher.service     # Port: N/A (file watcher)
x-link-webhook.service     # Port: 3099 (proxied via nginx)
```

### Endpoints

- `https://obsidian.jdkey.com/x` - Webhook for direct link submission (POST)
- `https://obsidian.jdkey.com/` - CouchDB for LiveSync

### Data Flow

```
/home/obsidian/automation-vault/YYYY-MM-DD.md  (daily note, synced via LiveSync)
         ↓
   inotifywait detects change
         ↓
   x-link-watcher.sh extracts links
         ↓
   fetch-tweet.sh or fetch-grok.sh (TBD)
         ↓
   Claude API analysis
         ↓
/home/obsidian/automation-vault/x-analyses/    (output notes)
```

## Next Steps to Complete

### 1. Add Grok Link Detection
Update `x-link-watcher.sh` to detect `grok.com/share/` links in addition to X links.

### 2. Build Grok Content Fetcher
Create `fetch-grok.sh` or `fetch-grok.js` using Playwright to:
- Navigate to Grok share URL
- Wait for Cloudflare challenge
- Extract conversation content

### 3. Build Project Plan Generator
Create `generate-plan.sh` that:
- Takes Grok content as input
- Calls Claude API with:
  - The idea/concept from Grok
  - VPS context (from `/home/obsidian/automation-vault/VPS Web Projects Standards.md`)
  - Mac Mini context (TBD - need to document Mac Mini setup)
- Outputs a structured project plan

### 4. Build Approval Workflow
Options:
- Write plan to a special file, user reviews in Obsidian
- Send notification (email, push, etc.)
- Create a simple web UI for approval

## Environment

### VPS (this server)
- IP: 74.82.63.199
- Projects: jdkey, planter, sharper, winning, podstyle, vidpub, link, tru
- Standards doc: `/home/obsidian/automation-vault/VPS Web Projects Standards.md`
- Stack: Next.js (standalone), PostgreSQL (peer auth), PM2, nginx

### Mac Mini (user's local server)
- Structure: TBD - needs documentation
- Tools: TBD

### API Keys
- Anthropic: Configured in systemd service environment
- Located in: `/home/winning/app/.env`

## Session History

### 2026-01-07
1. Started from BuildFlow inspiration (Telegram → AI research)
2. Built file watcher for Obsidian vault
3. Tried multiple tweet fetching approaches:
   - jina.ai reader (blocked by X login wall)
   - Playwright scraping (X requires auth)
   - Twitter syndication API (✅ works for recent tweets)
4. Set up webhook as alternative to file watching
5. Discovered LiveSync stores encrypted data in CouchDB
6. User fixed LiveSync sync issue
7. Identified new flow: X → Grok → Obsidian → Claude
8. Documented project state (this file)

## Resume Point

To continue this project:
1. Read this document
2. Check current daily note for Grok links: `cat /home/obsidian/automation-vault/$(date +%Y-%m-%d).md`
3. Continue from "Next Steps to Complete" section above
