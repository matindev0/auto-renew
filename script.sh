#!/bin/bash

# زانیارییەکان ڕاستەوخۆ لێرەدا بنووسە
BOT_TOKEN="your_telegram_bot_token"
SITE_KEY="your_site_key"
CAPTCHA_API_KEY="your_2captcha_api_key"
USERNAME="your_username"
PASSWORD="your_password"

# فەرمانەکانی Node.js لە bash
node <<EOF
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const TelegramBot = require('node-telegram-bot-api');
const solver = require('2captcha');

puppeteer.use(StealthPlugin());

const bot = new TelegramBot("$BOT_TOKEN", { polling: true });

const LOGIN_URL = "https://mcserverhost.com/login";
const SERVER_URL = "https://mcserverhost.com/dashboard";

async function solveCaptcha(page) {
    console.log("🟡 Solving CAPTCHA...");
    const result = await solver.solveRecaptchaV2("$CAPTCHA_API_KEY", "$SITE_KEY", LOGIN_URL);

    await page.evaluate(token => {
        document.querySelector("#g-recaptcha-response").innerHTML = token;
    }, result);

    console.log("✅ CAPTCHA Solved!");
}

async function loginAndRenew(chatId) {
    const browser = await puppeteer.launch({ headless: false, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
    const page = await browser.newPage();

    console.log("🔵 Opening login page...");
    bot.sendMessage(chatId, "🔵 Logging in...");

    await page.goto(LOGIN_URL, { waitUntil: "networkidle2" });

    await page.type('input[name="username"]', "$USERNAME");
    await page.type('input[name="password"]', "$PASSWORD");

    await solveCaptcha(page);

    await page.click("button[type=submit]");
    await page.waitForNavigation();

    console.log("✅ Logged in successfully!");
    bot.sendMessage(chatId, "✅ Logged in successfully!");

    setInterval(async () => {
        try {
            await page.goto(SERVER_URL, { waitUntil: "networkidle2" });
            console.log("🟢 Checking Renew Button...");

            const renewButton = await page.$("button:has-text('RENEW')");
            if (renewButton) {
                await renewButton.click();
                console.log("✅ Server Renewed!");
                bot.sendMessage(chatId, "✅ Server Renewed!");
            } else {
                console.log("⚠️ No Renew Button Found!");
                bot.sendMessage(chatId, "⚠️ No Renew Button Found!");
            }

        } catch (error) {
            console.error("❌ Error renewing server:", error);
            bot.sendMessage(chatId, "❌ Error renewing server!");
        }
    }, 30000);  // هەر ٣٠ چرکە جارێک `renew` بکات
}

bot.onText(/\/start/, (msg) => {
    bot.sendMessage(msg.chat.id, "👋 Hello! Use /renew to start auto-renewing your server.");
});

bot.onText(/\/renew/, (msg) => {
    bot.sendMessage(msg.chat.id, "🔄 Starting auto-renew process...");
    loginAndRenew(msg.chat.id);
});
EOF
