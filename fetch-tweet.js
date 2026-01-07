#!/usr/bin/env node
// Fetch tweet content using Playwright - handles login walls
const { chromium } = require('playwright');

async function fetchTweet(url) {
    const browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    try {
        const context = await browser.newContext({
            userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            viewport: { width: 1280, height: 800 }
        });
        const page = await context.newPage();

        // Block unnecessary resources
        await page.route('**/*.{png,jpg,jpeg,gif,webp}', route => route.abort());

        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(3000);

        // Dismiss login modal
        await page.keyboard.press('Escape').catch(() => {});
        await page.waitForTimeout(500);

        // Extract content
        const data = await page.evaluate(() => {
            const articles = document.querySelectorAll('article');
            if (articles.length === 0) {
                return { raw: document.body.innerText.substring(0, 8000) };
            }

            const tweets = [];
            articles.forEach((article, i) => {
                if (i > 4) return;
                const textEl = article.querySelector('[data-testid="tweetText"]');
                const text = textEl ? textEl.innerText : article.innerText.substring(0, 1000);
                const time = article.querySelector('time');
                const timestamp = time ? time.getAttribute('datetime') : '';
                tweets.push({ text, timestamp, isMain: i === 0 });
            });
            return { tweets };
        });

        return data;
    } finally {
        await browser.close();
    }
}

function formatOutput(data) {
    if (data.raw) {
        return data.raw.replace(/Don't miss what's happening.*?Sign up/gs, '').trim();
    }
    if (!data.tweets || !data.tweets.length) return 'No content';
    
    let out = '';
    data.tweets.forEach((t, i) => {
        out += i === 0 ? '--- Tweet ---\n' : `\n--- Reply ${i} ---\n`;
        if (t.timestamp) out += `Time: ${new Date(t.timestamp).toLocaleString()}\n`;
        out += t.text + '\n';
    });
    return out;
}

const url = process.argv[2];
if (!url) { console.error('Usage: node fetch-tweet.js <url>'); process.exit(1); }

fetchTweet(url).then(d => console.log(formatOutput(d))).catch(e => { console.error(e); process.exit(1); });
