#!/usr/bin/env node
// Render the same flashed word five ways, back to back, to choose between.
//
//   node flash_samples.js <background.png> [out.mp4]
//
// The current flash just appears and disappears, which reads as a subtitle
// rather than as a hit. These are attempts at making it land. Each variant gets
// the same word over the same frame, a label in the corner, and a moment of
// stillness after it so the settled state can be judged as well as the entrance.
//
// WHOLE FRAMES, not a word layer composited later. Three of these move or flash
// the PICTURE as well as the word -- a shake, a white hit -- and doing that in
// CSS on a container with the background inside it is one mechanism instead of
// two. It costs a screenshot per frame, which at 25fps for a second is nothing.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const bubble = require('./lib/bubble');

const FONTS = path.join(__dirname, 'fonts');
const BG = process.argv[2];
const OUT = process.argv[3] || path.join(__dirname, 'out', 'flash_samples.mp4');
if (!BG || !fs.existsSync(BG)) {
  console.error('usage: flash_samples.js <background.png> [out.mp4]');
  process.exit(1);
}
const WORD = process.env.WORD || 'Decentralized';
const W = 1080, H = 2220, FPS = 25;
const IN_FRAMES = 25;      // one second of entrance
const HOLD_FRAMES = 20;    // then a beat of stillness

// Easing. `out` for things arriving, `back` for the overshoot that makes a
// movement read as a hit rather than a slide.
const outCubic = p => 1 - Math.pow(1 - p, 3);
const outBack = (p, s = 1.9) => 1 + (s + 1) * Math.pow(p - 1, 3) + s * Math.pow(p - 1, 2);
const clamp01 = p => Math.max(0, Math.min(1, p));

/// Each variant maps frame progress (0..1 over the entrance) to the state of
/// the word and of the frame behind it.
const VARIANTS = [
  {
    name: 'SLAM',
    note: 'huge and blurred, driven down onto the frame',
    at: p => {
      const e = outCubic(clamp01(p / 0.28));
      return { scale: 3.4 - 2.4 * e, alpha: e, blur: 14 * (1 - e), shake: 0, hit: 0 };
    },
  },
  {
    name: 'BURST',
    note: 'from nothing, overshoots, settles',
    at: p => {
      const e = outBack(clamp01(p / 0.34));
      return { scale: 0.15 + 0.85 * e, alpha: clamp01(p / 0.12), blur: 0, shake: 0, hit: 0 };
    },
  },
  {
    name: 'SHOCKWAVE',
    note: 'lands instantly, a ghost of itself expands away',
    at: p => ({
      scale: 1, alpha: 1, blur: 0, shake: 0, hit: 0,
      ghost: { scale: 1 + 1.1 * outCubic(clamp01(p / 0.5)), alpha: 0.55 * (1 - clamp01(p / 0.5)) },
    }),
  },
  {
    name: 'CHROMA',
    note: 'red and cyan copies converging',
    at: p => {
      const e = outCubic(clamp01(p / 0.36));
      return { scale: 1, alpha: 1, blur: 0, shake: 0, hit: 0, split: 46 * (1 - e) };
    },
  },
  {
    name: 'STAMP',
    note: 'the whole picture takes the impact',
    at: p => {
      const e = outCubic(clamp01(p / 0.16));
      const k = clamp01(1 - (p - 0.16) / 0.22);
      return {
        scale: 1.9 - 0.9 * e, alpha: e, blur: 0, hit: p < 0.09 ? 0.5 : 0,
        shake: p > 0.14 ? 26 * k * Math.sin(p * 92) : 0,
      };
    },
  },
];

function page(bgDataUri, s, label) {
  const ghost = s.ghost ? `<div class="w ghost" style="
      transform:translate(-50%,-50%) scale(${s.ghost.scale});opacity:${s.ghost.alpha}">${WORD}</div>` : '';
  const split = s.split ? `
    <div class="w chroma" style="transform:translate(calc(-50% - ${s.split}px),-50%);color:#ff2d2d">${WORD}</div>
    <div class="w chroma" style="transform:translate(calc(-50% + ${s.split}px),-50%);color:#00e5ff">${WORD}</div>` : '';
  return `<!doctype html><meta charset="utf-8"><style>
    ${bubble.fontFaces(FONTS)}
    html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:#000}
    #stage{position:relative;width:${W}px;height:${H}px;
      transform:translate(${s.shake.toFixed(2)}px,${(s.shake * 0.6).toFixed(2)}px)}
    #bg{position:absolute;inset:0;width:${W}px;height:${H}px}
    .w{position:absolute;left:50%;top:44%;width:${W}px;margin-left:${-W / 2}px;
      font:800 132px/1.05 'Inter',system-ui,sans-serif;letter-spacing:-2px;
      text-align:center;color:#fff;white-space:nowrap;
      text-shadow:0 6px 30px rgba(0,0,0,.85),0 2px 6px rgba(0,0,0,.9)}
    .ghost{text-shadow:none;color:#fff}
    .chroma{mix-blend-mode:screen;text-shadow:none;opacity:.85}
    #hit{position:absolute;inset:0;background:#fff;opacity:${s.hit}}
    #label{position:absolute;left:0;right:0;top:120px;text-align:center;
      font:700 34px/1 'Inter',system-ui,sans-serif;color:#fff;letter-spacing:3px;
      text-shadow:0 2px 8px rgba(0,0,0,.9)}
  </style>
  <div id="stage">
    <img id="bg" src="${bgDataUri}">
    ${ghost}${split}
    <div class="w" style="transform:translate(-50%,-50%) scale(${s.scale.toFixed(3)});
      opacity:${s.alpha.toFixed(3)};filter:blur(${(s.blur || 0).toFixed(2)}px)">${WORD}</div>
    <div id="hit"></div>
    <div id="label">${label}</div>
  </div>`;
}

(async () => {
  const work = OUT.replace(/\.mp4$/, '') + '.work';
  fs.rmSync(work, { recursive: true, force: true });
  fs.mkdirSync(work, { recursive: true });
  const bg = 'data:image/png;base64,' + fs.readFileSync(BG).toString('base64');

  const browser = await chromium.launch();
  const p = await browser.newPage({ viewport: { width: W, height: H } });
  let n = 0;
  for (const v of VARIANTS) {
    for (let i = 0; i < IN_FRAMES + HOLD_FRAMES; i++) {
      const prog = Math.min(1, i / IN_FRAMES);
      const s = { blur: 0, shake: 0, hit: 0, ...v.at(prog) };
      await p.setContent(page(bg, s, `${v.name} — ${v.note}`));
      if (n === 0) await p.evaluate(() => document.fonts.ready);
      await p.screenshot({ path: path.join(work, `f${String(n++).padStart(4, '0')}.png`) });
    }
    console.log(`  ${v.name}: ${IN_FRAMES + HOLD_FRAMES} frames`);
  }
  await browser.close();

  execFileSync('ffmpeg', ['-y', '-v', 'error', '-framerate', String(FPS),
    '-i', path.join(work, 'f%04d.png'), '-c:v', 'libx264', '-crf', '18',
    '-preset', 'medium', '-pix_fmt', 'yuv420p', OUT], { stdio: 'inherit' });
  console.log(`\n-> ${OUT}  (${n} frames, ${(n / FPS).toFixed(1)}s, ${VARIANTS.length} variants)`);
})();
