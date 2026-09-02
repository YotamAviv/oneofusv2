#!/usr/bin/env node
// Renders speech bubbles as full-frame transparent PNGs and composites them onto
// a clip with ffmpeg.
//
//   node bubbles.js captions/milhouse_identity_bar.json out/clip.mp4 out/clip_bubbles.mp4
//
// Bubbles are drawn in a headless browser rather than by ffmpeg's subtitle
// renderer: ASS can't draw a tail that points at a thing on screen, and CSS can.
// Each cue names an `anchor` — the point on the frame the bubble is about — and
// the tail is built to reach it.

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const W = 1080, H = 1920;
const FONTS = path.join(__dirname, 'fonts');

const STYLES = {
  narrator: {
    font: "'Inter', system-ui, sans-serif",
    size: 44, weight: 600, lineHeight: 1.34,
    fill: 'rgba(17,23,31,.94)',
    text: '#f4f7fb',
    border: 'rgba(255,255,255,.16)',
    pointer: 'rgba(17,23,31,.95)',     // leader/ring: must read over the light UI
    accent: 'rgba(120,190,255,.85)',   // thin top rule, ties it to the app's blue
    radius: 26,
    maxWidth: 800,
  },
  milhouse: {
    font: "'Comic Neue', 'Comic Sans MS', cursive",
    size: 50, weight: 700, lineHeight: 1.26,
    fill: '#fffdf4',
    text: '#1d2733',
    border: '#2b3a4d',
    pointer: '#2b3a4d',
    accent: null,
    radius: 34,
    maxWidth: 720,
  },
};

// The page draws one bubble, measures itself, and reports its geometry so the
// tail can be built against real numbers rather than guesses.
const PAGE = `<!doctype html><meta charset="utf-8">
<style>
  @font-face { font-family:'Comic Neue'; src:url('FONT_COMIC') format('truetype'); font-weight:700; }
  @font-face { font-family:'Inter'; src:url('FONT_INTER') format('truetype'); font-weight:600; }
  html,body { margin:0; width:${W}px; height:${H}px; background:transparent; overflow:hidden; }
  #stage { position:relative; width:${W}px; height:${H}px; }
  svg { position:absolute; inset:0; width:100%; height:100%; overflow:visible; }
  #b {
    position:absolute; box-sizing:border-box;
    padding:24px 32px 26px; text-align:center; white-space:pre-wrap;
    filter: drop-shadow(0 10px 26px rgba(0,0,0,.42));
  }
  #b .rule { height:3px; border-radius:2px; margin:0 auto 14px; width:64px; }
</style>
<div id="stage"><svg id="tail"></svg><div id="b"></div></div>
<script>
window.render = (cue, st) => {
  const b = document.getElementById('b');
  b.style.font = st.weight + ' ' + st.size + 'px/' + st.lineHeight + ' ' + st.font;
  b.style.background = st.fill;
  b.style.color = st.text;
  b.style.border = '2.5px solid ' + st.border;
  b.style.borderRadius = st.radius + 'px';
  b.style.maxWidth = st.maxWidth + 'px';
  b.innerHTML = (st.accent ? '<div class="rule" style="background:' + st.accent + '"></div>' : '')
              + cue.text.replace(/&/g,'&amp;').replace(/</g,'&lt;');

  // Measure, then place: centred horizontally unless the cue says otherwise,
  // and vertically wherever the cue puts it.
  b.style.left = '0px'; b.style.top = '0px';
  const w = b.getBoundingClientRect().width, h = b.getBoundingClientRect().height;
  const x = cue.x != null ? cue.x : Math.round((${W} - w) / 2);
  const y = cue.y;
  b.style.left = x + 'px'; b.style.top = y + 'px';

  // Point at the anchor. Near anchors get a real speech-bubble tail; far ones get
  // a thin leader line ending in a ring. A tail stretched across half the frame
  // reads as a spike laid over the UI, not as a bubble.
  const TAIL_MAX = 240;
  const [ax, ay] = cue.anchor;
  const above = ay < y + h / 2;                 // anchor above the bubble?
  const edgeY = above ? y : y + h;
  const half = Math.min(46, w / 5);             // half-width of the tail's base
  const bx = Math.max(x + st.radius + half, Math.min(x + w - st.radius - half, ax));
  const dx = ax - bx, dy = ay - edgeY;
  const dist = Math.hypot(dx, dy) || 1;
  const ux = dx / dist, uy = dy / dist;
  const shadow = 'filter:drop-shadow(0 6px 14px rgba(0,0,0,.32))';
  const svg = document.getElementById('tail');

  if (dist <= TAIL_MAX) {
    // Tapered, slightly curved tail: wide where it leaves the bubble, a point
    // where it lands. Drawn under the bubble so the base seam is hidden.
    const tipX = ax - ux * 8, tipY = ay - uy * 8;
    const c = 0.58;                             // how far along the control sits
    const cax = bx - half * 0.30 + dx * c, cay = edgeY + dy * c;
    const cbx = bx + half * 0.30 + dx * c, cby = edgeY + dy * c;
    svg.innerHTML =
      '<path d="M ' + (bx - half) + ' ' + edgeY +
      ' Q ' + cax + ' ' + cay + ' ' + tipX + ' ' + tipY +
      ' Q ' + cbx + ' ' + cby + ' ' + (bx + half) + ' ' + edgeY + ' Z"' +
      ' fill="' + st.fill + '" stroke="' + st.border + '" stroke-width="2.5"' +
      ' stroke-linejoin="round" style="' + shadow + '"/>';
  } else {
    const sx = bx, sy = edgeY;
    const ex = ax - ux * 17, ey = ay - uy * 17; // stop at the ring's edge
    svg.innerHTML =
      '<line x1="' + sx + '" y1="' + sy + '" x2="' + ex + '" y2="' + ey + '"' +
      ' stroke="rgba(255,255,255,.85)" stroke-width="7" stroke-linecap="round"/>' +
      '<line x1="' + sx + '" y1="' + sy + '" x2="' + ex + '" y2="' + ey + '"' +
      ' stroke="' + st.pointer + '" stroke-width="3.5" stroke-linecap="round" style="' + shadow + '"/>' +
      '<circle cx="' + ax + '" cy="' + ay + '" r="17" fill="none"' +
      ' stroke="rgba(255,255,255,.85)" stroke-width="7"/>' +
      '<circle cx="' + ax + '" cy="' + ay + '" r="17" fill="none"' +
      ' stroke="' + st.pointer + '" stroke-width="3.5" style="' + shadow + '"/>';
  }
  return { w, h, x, y, tail: dist <= TAIL_MAX ? 'tail' : 'leader' };
};
</script>`;

async function main() {
  const [spec, inVideo, outVideo] = process.argv.slice(2);
  if (!outVideo) throw new Error('usage: bubbles.js <cues.json> <in.mp4> <out.mp4>');
  const cues = JSON.parse(fs.readFileSync(spec, 'utf8'));

  const work = path.join(__dirname, 'out', 'bubbles');
  fs.rmSync(work, { recursive: true, force: true });
  fs.mkdirSync(work, { recursive: true });

  const b64 = f => 'data:font/ttf;base64,' + fs.readFileSync(path.join(FONTS, f)).toString('base64');
  const html = PAGE
    .replace('FONT_COMIC', b64('ComicNeue-Bold.ttf'))
    .replace('FONT_INTER', b64('Inter-SemiBold.ttf'));

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  await page.setContent(html);
  await page.evaluate(() => document.fonts.ready);

  for (const [i, cue] of cues.entries()) {
    const st = STYLES[cue.style];
    if (!st) throw new Error(`unknown style '${cue.style}' in cue ${i}`);
    const box = await page.evaluate(([c, s]) => window.render(c, s), [cue, st]);
    await page.screenshot({ path: path.join(work, `${i}.png`), omitBackground: true });
    console.log(`${cue.start.toFixed(1)}-${cue.end.toFixed(1)}s  ${cue.style.padEnd(8)} `
      + `${Math.round(box.w)}x${Math.round(box.h)} @${box.x},${box.y} -> anchor ${cue.anchor}  `
      + cue.text.replace(/\n/g, ' ').slice(0, 44));
  }
  await browser.close();

  // One overlay per cue, each faded in and out and gated to its window.
  const FADE = 0.28;
  const inputs = [];
  const chain = [];
  cues.forEach((c, i) => {
    inputs.push('-loop', '1', '-t', String(c.end - c.start + 0.1), '-i', path.join(work, `${i}.png`));
    chain.push(`[${i + 1}:v]format=rgba,`
      + `fade=t=in:st=0:d=${FADE}:alpha=1,`
      + `fade=t=out:st=${(c.end - c.start - FADE).toFixed(2)}:d=${FADE}:alpha=1,`
      + `setpts=PTS-STARTPTS+${c.start}/TB[o${i}]`);
  });
  let last = '[0:v]';
  const overlays = cues.map((c, i) => {
    const out = i === cues.length - 1 ? '[v]' : `[t${i}]`;
    const s = `${last}[o${i}]overlay=0:0:enable='between(t,${c.start},${c.end})'${out}`;
    last = `[t${i}]`;
    return s;
  });
  const filter = chain.concat(overlays).join(';');

  const { spawnSync } = require('child_process');
  const r = spawnSync('ffmpeg', ['-y', '-v', 'error', '-i', inVideo, ...inputs,
    '-filter_complex', filter, '-map', '[v]', '-map', '0:a?',
    '-c:v', 'libx264', '-crf', '20', '-preset', 'slow', '-pix_fmt', 'yuv420p',
    '-c:a', 'copy', outVideo], { stdio: 'inherit' });
  if (r.status !== 0) process.exit(r.status);
  console.log('\n->', outVideo);
}

main();
