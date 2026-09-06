#!/usr/bin/env node
// Render the same follow-up line five ways, over the real footage, to choose between.
//
//   node flash_tail_samples.js <section.mp4> <flash_end_seconds> [out.mp4]
//   TEXT="..." node flash_tail_samples.js out/vouch/<stamp>/section.mp4 33.4
//
// A flash is one word that hits and blows apart. This is the thing that could
// come after it: a sentence that arrives as the letters leave, and STAYS -- long
// enough to be read, which a flash never is. Five entrances, same words, same
// place, over the same seconds of the same take.
//
// OVER THE FOOTAGE, not over a still. The question being asked is whether the
// line reads while the beat's bubble is already on screen and the shattered word
// is still clearing, and a still cannot answer that. So each variant is the same
// six seconds of the built section with a different overlay on it, and the five
// are joined end to end with a label in the corner.
//
// Nothing here is wired into a build. It renders samples and stops; when one of
// these wins, it becomes `tail:` on a flash cue in video/*.yaml and moves into
// annotate.js. See video/README.md.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const bubble = require('./lib/bubble');

const FONTS = path.join(__dirname, 'fonts');
const SRC = process.argv[2];
const FLASH_END = parseFloat(process.argv[3]);
const OUT = process.argv[4] || path.join(__dirname, 'out', 'flash_tail_samples.mp4');
if (!SRC || !fs.existsSync(SRC) || !isFinite(FLASH_END)) {
  console.error('usage: flash_tail_samples.js <section.mp4> <flash_end_seconds> [out.mp4]');
  process.exit(1);
}

const TEXT = process.env.TEXT ||
  "No owner but us. Yours from your point of view; anyone's from theirs.";
// The two halves, for the variants that bring them in separately. Splitting on
// the first sentence stop rather than on a count of words: the break is where
// the meaning breaks.
const [LEAD, REST] = (() => {
  const i = TEXT.indexOf('. ');
  return i < 0 ? [TEXT, ''] : [TEXT.slice(0, i + 1), TEXT.slice(i + 2)];
})();

const FPS = 25;
// The window: a beat before the shatter starts, and long enough afterwards to
// judge whether the line outstays its welcome.
const LEAD_IN = 1.2;                       // footage before the tail arrives
const CLIP = 6.0;                          // total seconds shown per variant
const START = Math.max(0, FLASH_END - LEAD_IN);
const TAIL_AT = LEAD_IN;                   // when the tail begins, within the clip
const TAIL_FRAMES = Math.round((CLIP - TAIL_AT) * FPS);

const probe = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v',
  '-show_entries', 'stream=width,height', '-of', 'default=nw=1:nk=1', SRC],
  { encoding: 'utf8' }).trim().split('\n');
const W = +probe[0], H = +probe[1];

const clamp01 = p => Math.max(0, Math.min(1, p));
const outCubic = p => 1 - Math.pow(1 - p, 3);
const outBack = (p, s = 1.5) => 1 + (s + 1) * Math.pow(p - 1, 3) + s * Math.pow(p - 1, 2);

/// Where the line sits: the space the flashed word just left, which on this
/// section is empty app chrome above the beat's bubble.
const TOP = '34%';
const BODY = `font:800 62px/1.32 'Inter',system-ui,sans-serif;letter-spacing:-1px;`;
const AMBER = '#FF9A12';
const SHADOW = `text-shadow:0 0 2px rgba(120,40,0,.9),0 4px 16px rgba(0,0,0,.55),
                0 0 40px rgba(255,140,20,.55)`;
const WHITE_SHADOW = `text-shadow:0 2px 10px rgba(0,0,0,.85),0 0 30px rgba(0,0,0,.6)`;

function shell(inner, extraCss = '') {
  return `<!doctype html><meta charset="utf-8"><style>
    ${bubble.fontFaces(FONTS)}
    html,body{margin:0;width:${W}px;height:${H}px;overflow:hidden;background:transparent}
    #t{position:absolute;left:90px;right:90px;top:${TOP};text-align:center;${BODY}}
    ${extraCss}
  </style>${inner}`;
}

/// Each variant maps a frame index (0..) to one transparent frame. `frames` is
/// how many are distinct; everything after is the settled state, so a six-second
/// hold costs twenty renders rather than a hundred and fifty.
const VARIANTS = [
  {
    name: 'RISE',
    note: 'the whole line fades up into the space the word left',
    frames: 18,
    html: k => {
      const e = outCubic(clamp01(k / 14));
      return shell(`<div id="t" style="color:${AMBER};${SHADOW};
        opacity:${e.toFixed(3)};transform:translateY(${(46 * (1 - e)).toFixed(1)}px)">${TEXT}</div>`);
    },
  },
  {
    name: 'WORDS',
    note: 'word by word, each one staying',
    frames: 40,
    html: k => {
      const words = TEXT.split(' ');
      const per = 2.2;                      // frames between arrivals
      const spans = words.map((w, i) => {
        const e = outCubic(clamp01((k - i * per) / 5));
        return `<span style="display:inline-block;opacity:${e.toFixed(3)};
          transform:translateY(${(18 * (1 - e)).toFixed(1)}px)">${w}</span>`;
      }).join(' ');
      return shell(`<div id="t" style="color:${AMBER};${SHADOW}">${spans}</div>`);
    },
  },
  {
    name: 'TWO BEATS',
    note: 'the claim, then the explanation under it',
    frames: 34,
    html: k => {
      const a = outCubic(clamp01(k / 12));
      const b = outCubic(clamp01((k - 15) / 12));
      return shell(`<div id="t">
        <div style="color:${AMBER};${SHADOW};opacity:${a.toFixed(3)};
          transform:translateY(${(40 * (1 - a)).toFixed(1)}px)">${LEAD}</div>
        <div style="color:#fff;${WHITE_SHADOW};font-size:52px;margin-top:14px;
          opacity:${b.toFixed(3)};transform:translateY(${(30 * (1 - b)).toFixed(1)}px)">${REST}</div>
      </div>`);
    },
  },
  {
    name: 'PLATE',
    note: 'a dark plate, so it reads over anything',
    frames: 20,
    html: k => {
      const e = outBack(clamp01(k / 16));
      return shell(`<div id="t" style="opacity:${clamp01(k / 5).toFixed(3)};
          transform:scale(${(0.9 + 0.1 * e).toFixed(3)})">
          <div class="plate">${TEXT}</div>
        </div>`,
        `.plate{display:inline-block;padding:26px 38px;border-radius:28px;
           background:rgba(14,19,26,.92);border:1px solid rgba(255,255,255,.14);
           color:#f4f7fb;box-shadow:0 14px 40px rgba(0,0,0,.55)}`);
    },
  },
  {
    name: 'WIPE',
    note: 'swept on left to right, an amber rule left behind',
    frames: 24,
    html: k => {
      const e = outCubic(clamp01(k / 18));
      const pct = (e * 100).toFixed(1);
      return shell(`<div id="t" style="color:#fff;${WHITE_SHADOW}">
          <span class="mask" style="--p:${pct}%">${TEXT}</span>
          <div class="rule" style="width:${(e * 62).toFixed(1)}%"></div>
        </div>`,
        `.mask{-webkit-mask-image:linear-gradient(90deg,#000 var(--p),
           rgba(0,0,0,.06) calc(var(--p) + 9%));-webkit-mask-size:100% 100%}
         .rule{height:5px;border-radius:3px;margin:20px auto 0;background:${AMBER};
           box-shadow:0 0 24px rgba(255,154,18,.8)}`);
    },
  },
];

(async () => {
  const work = OUT.replace(/\.mp4$/, '') + '.work';
  fs.rmSync(work, { recursive: true, force: true });
  fs.mkdirSync(work, { recursive: true });

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  let warmed = false;
  for (const [i, v] of VARIANTS.entries()) {
    const dir = path.join(work, `v${i}`);
    fs.mkdirSync(dir);
    const name = k => path.join(dir, `f${String(k).padStart(4, '0')}.png`);
    for (let k = 0; k < v.frames; k++) {
      await page.setContent(v.html(k));
      if (!warmed) { await page.evaluate(() => document.fonts.ready); warmed = true; }
      await page.screenshot({ path: name(k), omitBackground: true });
    }
    // The settled frame, repeated for the hold. Copies, not renders: the point
    // of the hold is that nothing is moving.
    for (let k = v.frames; k < TAIL_FRAMES; k++) fs.copyFileSync(name(v.frames - 1), name(k));
    console.log(`  ${v.name}: ${v.frames} rendered, ${TAIL_FRAMES} frames`);
  }
  await browser.close();

  // One clip per variant: the same seconds of the take, the overlay laid on at
  // TAIL_AT, and the variant's name burned into the corner so a viewer watching
  // the file back knows which one they are looking at.
  const font = path.join(FONTS, 'Inter-SemiBold.ttf');
  const clips = [];
  VARIANTS.forEach((v, i) => {
    const clip = path.join(work, `clip${i}.mp4`);
    const label = `${v.name} — ${v.note}`.replace(/[:']/g, '').replace(/,/g, '\\,');
    execFileSync('ffmpeg', ['-y', '-v', 'error',
      '-ss', START.toFixed(3), '-t', CLIP.toFixed(3), '-i', SRC,
      '-framerate', String(FPS), '-itsoffset', TAIL_AT.toFixed(3),
      '-i', path.join(work, `v${i}`, 'f%04d.png'),
      '-filter_complex',
      `[1:v]format=rgba[w];[0:v][w]overlay=0:0[o];` +
      `[o]drawtext=fontfile=${font}:text='${label}':x=(w-text_w)/2:y=140:` +
      `fontsize=38:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=16[v]`,
      '-map', '[v]', '-t', CLIP.toFixed(3),
      '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-pix_fmt', 'yuv420p',
      clip], { stdio: 'inherit' });
    clips.push(clip);
  });

  const list = path.join(work, 'clips.txt');
  fs.writeFileSync(list, clips.map(c => `file '${c}'`).join('\n') + '\n');
  execFileSync('ffmpeg', ['-y', '-v', 'error', '-f', 'concat', '-safe', '0',
    '-i', list, '-c', 'copy', OUT], { stdio: 'inherit' });
  console.log(`\n-> ${OUT}  (${VARIANTS.length} variants, ${(VARIANTS.length * CLIP).toFixed(0)}s)`);
})();
