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
// --no-fade: cut to it and cut away. A card that argues something wants easing
// in; a one-second title does not -- at that length the fade IS most of the
// clip, and it reads as the video hesitating rather than as a title.
const NO_FADE = process.argv.includes('--no-fade');

// --words makes a word-by-word card: the words arrive one at a time and stay.
// Anything else is a plain card, first line large and the rest smaller.
const argv = process.argv.slice(2);
const wordMode = argv.includes('--words');
const [out, secs, ...rest] = argv.filter(a => a !== '--words' && a !== '--no-fade');
const lines = rest;
if (!lines.length) {
  console.error('usage: card.js <out.mp4> <seconds> "<heading>" ["<line>" ...]\n' +
                '       card.js <out.mp4> <seconds> --words "Our." "Own." ...');
  process.exit(1);
}
const DUR = +secs;
// A short card cannot spend most of itself fading.
const FADE = NO_FADE ? 0 : Math.min(FADE_MAX, DUR * 0.14);

const card = require('./lib/card');
const page = card.page(lines, { W, H, fontsDir: FONTS });
// A word takes this long to arrive; the finished line then holds for DUR.
const STEP = +(process.env.WORD_STEP || 0.62);

(async () => {
  // Scratch beside the output, named after it -- the same rule annotate.js
  // follows. It used to be out/card/, shared by every build and never cleaned,
  // so stills from six different sections piled up in one directory under names
  // like splice0_3.png that said nothing about where they came from.
  //
  // Existing already is an error: output paths are stamped, so a repeat means
  // something is being overwritten.
  const work = out.replace(/\.mp4$/, '') + '.work';
  if (fs.existsSync(work)) {
    throw new Error(`${work} already exists -- ${path.basename(out)} has been built `
      + 'before. Build directories are stamped; two builds should never share a path.');
  }
  fs.mkdirSync(work, { recursive: true });

  const browser = await chromium.launch();
  const p = await browser.newPage({ viewport: { width: W, height: H } });

  const shoot = async (html, file) => {
    await p.setContent(html);
    await p.evaluate(() => document.fonts.ready);
    await p.screenshot({ path: file });
  };

  if (wordMode) {
    // One still per word, each held for STEP, then the finished line for DUR.
    // Concatenated rather than cross-faded: the words are meant to land.
    const pngs = [];
    for (let n = 1; n <= lines.length; n++) {
      const f = path.join(work, `${n}.png`);
      await shoot(card.wordsPage(lines, n, { W, H, fontsDir: FONTS }), f);
      pngs.push(f);
    }
    await browser.close();
    const inputs = [], chain = [];
    pngs.forEach((f, i) => {
      const d = i === pngs.length - 1 ? DUR : STEP;
      inputs.push('-loop', '1', '-t', String(d), '-i', f);
      chain.push(`[${i}:v]fps=25,setsar=1[w${i}]`);
    });
    const last = pngs.length - 1;
    execFileSync('ffmpeg', ['-y', '-v', 'error', ...inputs, '-filter_complex',
      `${chain.join(';')};${pngs.map((_, i) => `[w${i}]`).join('')}` +
      `concat=n=${pngs.length}:v=1:a=0,format=yuv420p,` +
      (NO_FADE ? '[v]'
               : `fade=t=in:st=0:d=${FADE},` +
                 `fade=t=out:st=${(STEP * last + DUR - FADE).toFixed(2)}:d=${FADE}[v]`),
      '-map', '[v]', '-c:v', 'libx264', '-crf', '19', '-preset', 'medium', out],
      { stdio: 'inherit' });
    console.log(`-> ${out}  (${(STEP * last + DUR).toFixed(2)}s, ${lines.length} words)  ` +
                lines.join(' '));
    return;
  }

  const png = path.join(work, 'card.png');
  await shoot(page, png);
  await browser.close();

  execFileSync('ffmpeg', ['-y', '-v', 'error', '-loop', '1', '-t', String(DUR), '-i', png,
    '-vf', 'fps=25,format=yuv420p' + (NO_FADE ? ''
             : `,fade=t=in:st=0:d=${FADE},fade=t=out:st=${(DUR - FADE).toFixed(2)}:d=${FADE}`),
    '-c:v', 'libx264', '-crf', '19', '-preset', 'medium', out], { stdio: 'inherit' });
  console.log(`-> ${out}  (${DUR}s)  ${lines.join(' / ')}`);
})();
