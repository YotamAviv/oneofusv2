#!/usr/bin/env node
// Render a full-screen text card and make a clip of it.
//
//   node card.js out/card_install.mp4 3.5 "Use the app store links" "to install ONE-OF-US.NET"
//
// First line is the heading, the rest are subordinate. Sized for the takes:
// 1080x2220, the emulator's screen, so cards and footage cut together without
// scaling.
//
// A card is where the video says something the app cannot say for itself -- here,
// that installing an app is a thing people already know how to do, and that the
// video is not going to spend forty seconds on the Play Store to prove it.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const W = 1080, H = 2220;
const FONTS = path.join(__dirname, 'fonts');
const FADE_MAX = 0.4;

const [out, secs, ...lines] = process.argv.slice(2);
if (!lines.length) {
  console.error('usage: card.js <out.mp4> <seconds> "<heading>" ["<line>" ...]');
  process.exit(1);
}
const DUR = +secs;
// A short card cannot spend most of itself fading.
const FADE = Math.min(FADE_MAX, DUR * 0.14);

const page = require('./lib/card').page(lines, { W, H, fontsDir: FONTS });

(async () => {
  const work = path.join(__dirname, 'out', 'card');
  fs.mkdirSync(work, { recursive: true });
  const png = path.join(work, path.basename(out).replace(/\.mp4$/, '.png'));

  const browser = await chromium.launch();
  const p = await browser.newPage({ viewport: { width: W, height: H } });
  await p.setContent(page);
  await p.evaluate(() => document.fonts.ready);
  await p.screenshot({ path: png });
  await browser.close();

  execFileSync('ffmpeg', ['-y', '-v', 'error', '-loop', '1', '-t', String(DUR), '-i', png,
    '-vf', `fps=25,format=yuv420p,fade=t=in:st=0:d=${FADE},` +
           `fade=t=out:st=${(DUR - FADE).toFixed(2)}:d=${FADE}`,
    '-c:v', 'libx264', '-crf', '19', '-preset', 'medium', out], { stdio: 'inherit' });
  console.log(`-> ${out}  (${DUR}s)  ${lines.join(' / ')}`);
})();
