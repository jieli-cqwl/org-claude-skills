#!/usr/bin/env node
/**
 * Darwin Skill - 高清截图脚本
 *
 * 用法: node scripts/screenshot.mjs [html文件路径] [输出png路径]
 *
 * 特性:
 * - 2x deviceScaleFactor，输出高清图
 * - 只截 .card 元素，无多余背景
 * - 等待字体加载完成
 * - 适合 CLI / 自动化调用
 */

import { createRequire } from 'module';
const require = createRequire(import.meta.url);

function loadPlaywright() {
  try {
    return require('playwright');
  } catch {}

  try {
    return require('playwright-core');
  } catch {}

  throw new Error('未找到 playwright 或 playwright-core，请先在当前环境安装可用的 Playwright 依赖');
}

const pw = loadPlaywright();
const htmlPath = process.argv[2] || new URL('../templates/result-card.html', import.meta.url).pathname;
const outputPath = process.argv[3] || new URL('../templates/result-card.png', import.meta.url).pathname;

async function screenshot() {
  const browser = await pw.chromium.launch();

  try {
    const context = await browser.newContext({
      viewport: { width: 920, height: 1600 },
      deviceScaleFactor: 2,
    });

    const page = await context.newPage();

    await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(2000);

    const card = await page.locator('.card');
    await card.screenshot({
      path: outputPath,
      type: 'png',
    });

    console.log(`截图完成: ${outputPath}`);

    const box = await card.boundingBox();
    console.log(`卡片尺寸: ${Math.round(box.width)}x${Math.round(box.height)}px (CSS)`);
    console.log(`输出尺寸: ${Math.round(box.width * 2)}x${Math.round(box.height * 2)}px (2x高清)`);
  } finally {
    await browser.close();
  }
}

screenshot().catch(err => {
  console.error('截图失败:', err.message);
  process.exit(1);
});
