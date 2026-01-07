#!/usr/bin/env node
// Simple webhook server to receive X links for processing
const http = require('http');
const { execSync, spawn } = require('child_process');
const path = require('path');

const PORT = process.env.PORT || 3099;
const API_KEY = process.env.WEBHOOK_API_KEY || '';
const SCRIPT_DIR = __dirname;

const log = (msg) => console.log(`[${new Date().toISOString()}] ${msg}`);

function extractXLink(text) {
    const match = text.match(/https?:\/\/(x\.com|twitter\.com)\/[A-Za-z0-9_]+\/status\/[0-9]+/);
    return match ? match[0] : null;
}

async function processLink(link) {
    return new Promise((resolve, reject) => {
        log(`Processing: ${link}`);

        const proc = spawn('bash', [path.join(SCRIPT_DIR, 'process-webhook.sh'), link], {
            env: { ...process.env, LINK: link }
        });

        let output = '';
        proc.stdout.on('data', (data) => { output += data; });
        proc.stderr.on('data', (data) => { output += data; });

        proc.on('close', (code) => {
            if (code === 0) {
                resolve(output.trim());
            } else {
                reject(new Error(`Process failed: ${output}`));
            }
        });
    });
}

const server = http.createServer(async (req, res) => {
    // CORS headers for iOS Shortcuts
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    if (req.method === 'GET' && req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok' }));
        return;
    }

    if (req.method !== 'POST' || !req.url.startsWith('/x')) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Not found' }));
        return;
    }

    // Check API key if configured
    if (API_KEY) {
        const auth = req.headers.authorization;
        if (!auth || auth !== `Bearer ${API_KEY}`) {
            res.writeHead(401, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Unauthorized' }));
            return;
        }
    }

    // Parse body
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', async () => {
        try {
            let link;

            // Try JSON first, then plain text
            try {
                const json = JSON.parse(body);
                link = json.url || json.link || json.text;
            } catch {
                link = body.trim();
            }

            // Extract X link from text
            const xLink = extractXLink(link);

            if (!xLink) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'No valid X/Twitter link found' }));
                return;
            }

            log(`Received: ${xLink}`);

            // Process async, respond immediately
            res.writeHead(202, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ status: 'processing', link: xLink }));

            // Process in background
            processLink(xLink)
                .then(result => log(`Done: ${xLink}`))
                .catch(err => log(`Error: ${err.message}`));

        } catch (err) {
            log(`Error: ${err.message}`);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: err.message }));
        }
    });
});

server.listen(PORT, () => {
    log(`X Link webhook listening on port ${PORT}`);
    log(`POST /x with {"url": "https://x.com/..."} or plain text`);
});
