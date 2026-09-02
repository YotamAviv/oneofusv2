#!/usr/bin/env node
// Annotate a take: a prompter band that scrolls along the bottom saying what the
// phone's user is doing, and beats where the video STOPS -- freeze frame, pause
// bars, everything dimmed and blurred except the one thing being talked about,
// and a bubble pointing at it.
//
//   node annotate.js cues/nerdster.json out/nerdster_<stamp>_taps.mp4
//
// Writes <in>_annotated.mp4.
//
// PROTOTYPE. The point is to see whether the pause-and-spotlight treatment
// reads, not to be a finished tool.
//
// Don't put a zoom over a beat. The zoom runs after the beats are spliced in, so
// it magnifies the frozen frame and its bubble along with everything else, and
// the bubble ends up half off the edge. A beat is already a way of pointing at
// one thing; it doesn't need the other.
//
// A cue says WHEN by naming a moment the take itself recorded -- "at":
// "tap_publish" -- rather than by a number of seconds. Reshooting is the normal
// cost of changing a word of copy, and it moves every number in the file; the
// names survive it. `after` offsets from the mark, and a plain "t" still works
// where nothing suitable is named (see lib/marks.js).
//
// The cue file is authored against the ORIGINAL timeline; a beat that stops the
// video for three seconds pushes everything after it three seconds later, and
// this does that arithmetic so the file doesn't have to.
//
//   {
//     "prompter": [ { "at": "tap_type_menu", "text": "Filter it down to books." } ],
//     "zooms": [ { "at": "statement_selected", "in": 0.6, "hold": 5, "out": 0.6,
//                  "to": [430, 900, 760] } ],   // centre x, centre y, width
//     "cards": [ { "at": "published", "after": 2.5, "hold": 3.5,
//                  "lines": ["That's it.", "..."] } ],   // stops the take
//     "beats": [ {
//        "at": "published", "after": 0.2, "hold": 3.0, "text": "Tom liked it too.",
//        "anchor": [300, 1180],            // what the tail points at
//        "spotlight": [40, 1090, 1000, 180],  // x, y, w, h -- what stays sharp
//        "y": 700                          // bubble's top edge; x optional
//     } ]
//   }
//
// What a take names is in its out/<stamp>.marks.json; a cue naming something
// that isn't there fails with the list of what is.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const bubble = require('./lib/bubble');
const { page: cardPage } = require('./lib/card');
const { loadMarks, timeOf } = require('./lib/marks');

const FONTS = path.join(__dirname, 'fonts');
const BAND_H = 300;                 // prompter band, along the bottom
const SCROLL = 0.45;                // seconds a line takes to slide into place

const [cueFile, inVideo] = process.argv.slice(2);
if (!inVideo) { console.error('usage: annotate.js <cues.json> <in.mp4>'); process.exit(1); }
const cues = JSON.parse(fs.readFileSync(cueFile, 'utf8'));

// Resolve every cue's time once, up front, so the rest of this works in
// seconds. A cue that names a mark is resolved against the take's own marks
// file; one that gives a number is taken as it is.
const marks = loadMarks(inVideo);
const resolve = (list, what) => (list || []).map(c => ({ ...c, t: timeOf(c, marks, what) }))
  .sort((a, b) => a.t - b.t);
// A beat can NAME A MEASUREMENT instead of carrying pixels.
//
//   - at: signature_shown
//     box: signatureBox      # {x, y, w, h} the take wrote into its marks
//     pad: 26
//
// anchor and spotlight are otherwise typed in by hand off a frame, which is fine
// for something fixed -- a QR code, a toolbar -- and wrong for anything whose
// position depends on the take. The signature line sits inside a scrolling view
// and lands somewhere different every time; a rectangle typed for one take
// pointed at blank white on the next. Where a shoot script can measure the
// thing, it records the box and the cue names it.
//
// Boxes are in the video's own pixels, centre and size, which is what the take
// measured them in. Explicit anchor/spotlight still win if both are given.
function fromBox(b, marks) {
  if (!b.box) return b;
  const m = marks && marks[b.box];
  if (!m) {
    const boxes = Object.entries(marks || {})
      .filter(([, v]) => v && typeof v === 'object' && 'w' in v && 'h' in v)
      .map(([k]) => k);
    throw new Error(`beat names box "${b.box}", which this take did not measure.\n` +
      `  it measured: ${boxes.join(', ') || '(none)'}`);
  }
  const pad = b.pad ?? 24;
  return {
    ...b,
    anchor: b.anchor ?? [Math.round(m.x), Math.round(m.y)],
    spotlight: b.spotlight ?? [Math.round(m.x - m.w / 2 - pad), Math.round(m.y - m.h / 2 - pad),
                               Math.round(m.w + pad * 2), Math.round(m.h + pad * 2)],
  };
}

const beats = resolve(cues.beats, 'beat').map(b => fromBox(b, marks));
const cards = resolve(cues.cards, 'card');
// A card and a beat are the same act: stop the take at a mark, hold a still for
// a moment, carry on. They differ only in what the still is -- a dimmed frame
// with a bubble on it, or a screen of text. So they are spliced together, in
// time order, and everything downstream counts them as one kind of thing.
const splices = [...beats.map(b => ({ ...b, kind: 'beat' })),
                 ...cards.map(c => ({ ...c, kind: 'card' }))].sort((a, b) => a.t - b.t);
const lines = resolve(cues.prompter, 'prompter line');
const zooms = resolve(cues.zooms, 'zoom');
console.log(marks ? `marks: ${path.basename(inVideo)} → ${Object.keys(marks).length} entries`
                  : `no marks file for ${path.basename(inVideo)} — cues must give "t"`);

const probe = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v',
  '-show_entries', 'stream=width,height', '-show_entries', 'format=duration',
  '-of', 'default=nw=1:nk=1', inVideo], { encoding: 'utf8' }).trim().split('\n');
const W = +probe[0], H = +probe[1], DUR = +probe[2];

// A cue later than the take is a cue-vs-take mismatch, and left alone each kind
// fails differently. A beat dies further down on a frame ffmpeg never wrote, so
// it at least stops; a prompter line or a zoom simply never appears, and the
// copy goes missing from the finished video with nothing said about it. That is
// how the signature chain's closing line -- the whole point of the section --
// was absent from a build that reported success.
//
// The mark being late is as likely as the take being short, and the two look
// identical from here, so name both.
for (const [what, list] of [['prompter line', lines], ['zoom', zooms],
                            ['beat or card', splices]]) {
  for (const c of list) {
    if (c.t < DUR) continue;
    throw new Error(
      `${what} at ${c.t}s is past the end of ${path.basename(inVideo)} ` +
      `(${DUR.toFixed(2)}s)` + (c.at ? `, anchored on mark "${c.at}"` : '') + '.\n' +
      '  Either the take is short -- screenrecord sometimes stops early -- or the\n' +
      '  mark is late. Check the mark against the footage before trusting it.');
  }
}

/// Where a moment in the original take lands once the pauses are spliced in.
const shift = t => t + splices.filter(b => b.t <= t).reduce((s, b) => s + b.hold, 0);

// Scratch lives beside its output, named after it: <output>.work/. Nothing is
// shared and nothing is global, so two builds cannot collide and the evidence
// stays attached to the build that made it -- the frozen frames and card stills
// in here are what you read when a beat lands in the wrong place.
//
// This used to be out/annotate/, wiped at the start of every run. That made the
// evidence survive exactly until the next build, which is the wrong half of the
// time to have it.
//
// It is an error for it to exist already. Output paths are stamped, so a
// collision means something is being overwritten, and overwriting is how a good
// build gets lost quietly.
const out = inVideo.replace(/\.mp4$/, '_annotated.mp4');
const work = out.replace(/\.mp4$/, '') + '.work';
if (fs.existsSync(work)) {
  throw new Error(`${work} already exists -- ${path.basename(out)} has been built `
    + 'before. Build directories are stamped; two builds should never share a path.');
}
fs.mkdirSync(work, { recursive: true });

(async () => {
  const browser = await chromium.launch();

  // --- the stills that get spliced in: frozen spotlit beats, and cards ---
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  for (const [i, b] of splices.entries()) {
    if (b.kind === 'card') {
      if (b.words) {
        // A word-by-word card is not a still -- the words arrive over several
        // seconds -- so card.js builds it as a clip and it is spliced as one.
        // Its real length comes back from ffprobe rather than from repeating
        // card.js's arithmetic here.
        const clip = path.join(work, `splice${i}.mp4`);
        execFileSync('node', [path.join(__dirname, 'card.js'), clip, String(b.hold),
          '--words', ...b.words.map(String)], { stdio: 'ignore' });
        b.clip = clip;
        b.hold = +execFileSync('ffprobe', ['-v', 'error', '-show_entries',
          'format=duration', '-of', 'csv=p=0', clip], { encoding: 'utf8' }).trim();
        console.log(`card @${b.t}s  ${b.hold}s  ${b.words.length} words  ` +
                    `"${b.words.join(' ').slice(0, 44)}"`);
        continue;
      }
      await page.setContent(cardPage(b.lines, { W, H, fontsDir: FONTS }));
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: path.join(work, `splice${i}.png`) });
      console.log(`card @${b.t}s  hold ${b.hold}s  "${b.lines.join(' / ').slice(0, 48)}"`);
      continue;
    }
    const frame = path.join(work, `f${i}.png`);
    execFileSync('ffmpeg', ['-y', '-v', 'error', '-ss', String(b.t), '-i', inVideo,
      '-frames:v', '1', frame]);
    // ffmpeg exits happily having written nothing when the seek is past the end,
    // and the next step then fails on a missing file several lines from the
    // cause. A beat later than the take is a cue-vs-take mismatch: say so.
    if (!fs.existsSync(frame)) {
      throw new Error(`beat at ${b.t}s is past the end of ${path.basename(inVideo)} ` +
        `(${DUR.toFixed(2)}s). The cue names a mark the take recorded, so the take ` +
        `is probably short -- screenrecord truncates when it is pulled too early.`);
    }
    await page.setContent(beatPage(frame, b));
    await page.evaluate(() => document.fonts.ready);
    const box = await page.evaluate(([c, s]) => window.renderBubble(c, s),
      [b, bubble.STYLES[b.style || 'narrator']]);
    await page.screenshot({ path: path.join(work, `splice${i}.png`) });
    console.log(`beat @${b.t}s  hold ${b.hold}s  bubble ${Math.round(box.w)}x${Math.round(box.h)} ` +
                `(${box.tail})  "${b.text.replace(/\n/g, ' ').slice(0, 40)}"`);
  }

  // --- the prompter strips: one per line, differing only in which is lit ---
  const strip = await browser.newPage({ viewport: { width: W, height: 200 } });
  const geom = [];
  for (const [i] of lines.entries()) {
    await strip.setContent(stripPage(i));
    await strip.evaluate(() => document.fonts.ready);
    const g = await strip.evaluate(() => {
      const el = document.getElementById('strip');
      const h = Math.ceil(el.getBoundingClientRect().height);
      return {
        h,
        centres: [...el.children].map(c => Math.round(c.offsetTop + c.offsetHeight / 2)),
      };
    });
    await strip.setViewportSize({ width: W, height: g.h });
    await strip.screenshot({ path: path.join(work, `strip${i}.png`), omitBackground: true });
    geom.push(g);
  }
  await browser.close();

  // What the finished timeline looks like, for whoever trims it.
  //
  // A splice STOPS the take and inserts a still, so everything after it moves
  // later -- and a word-by-word card's length is not knowable from the cue file,
  // because card.js builds it as a clip and ffprobe measures it. Writing it down
  // here is the only place that knows both. sections.py reads this to end a
  // section on its closing card instead of on whatever the take did next.
  fs.writeFileSync(out.replace(/\.mp4$/, '') + '.timeline.json', JSON.stringify({
    source: path.basename(inVideo),
    duration: DUR,
    splices: splices.map(b => ({ kind: b.kind, t: b.t, hold: +b.hold })),
  }, null, 2) + '\n');

  const paused = path.join(work, 'paused.mp4');
  spliceInPauses(paused);
  const zoomed = path.join(work, 'zoomed.mp4');
  punchIn(paused, zoomed);
  layPrompter(zoomed, out, geom);
  console.log(`\n-> ${out}`);
})();

/// A frozen frame with everything but the subject pushed back: blurred and
/// darkened, the spotlight rect left sharp, and two bars saying the video has
/// stopped on purpose rather than buffering.
function beatPage(framePath, b) {
  const img = 'data:image/png;base64,' + fs.readFileSync(framePath).toString('base64');
  const [sx, sy, sw, sh] = b.spotlight || [0, 0, W, H];
  return `<!doctype html><meta charset="utf-8"><style>
    ${bubble.fontFaces(FONTS)}
    html,body { margin:0; width:${W}px; height:${H}px; overflow:hidden; background:#000; }
    #stage { position:relative; width:${W}px; height:${H}px; }
    .frame { position:absolute; inset:0; width:${W}px; height:${H}px; }
    #back { filter: blur(9px) brightness(.42) saturate(.8); transform:scale(1.03); }
    #spot {
      position:absolute; left:${sx}px; top:${sy}px; width:${sw}px; height:${sh}px;
      overflow:hidden; border-radius:20px;
      box-shadow: 0 0 0 4px rgba(255,255,255,.9), 0 0 60px 12px rgba(0,0,0,.55);
    }
    #spot img { position:absolute; left:${-sx}px; top:${-sy}px; }
    #pause {
      position:absolute; right:48px; top:44px; display:flex; gap:16px;
      filter: drop-shadow(0 6px 18px rgba(0,0,0,.6));
    }
    #pause i { display:block; width:26px; height:86px; border-radius:6px; background:#fff; }
    ${bubble.CSS}
  </style>
  <div id="stage">
    <img id="back" class="frame" src="${img}">
    <div id="spot"><img src="${img}"></div>
    <div id="pause"><i></i><i></i></div>
    ${bubble.HTML}
  </div>
  <script>${bubble.JS(W)}</script>`;
}

/// The prompter text, all of it, with line `lit` bright and the rest receded.
/// One image per line: the strip scrolls, and the highlight moves with it.
function stripPage(lit) {
  const items = lines.map((l, i) => `<div class="l ${i === lit ? 'on' : ''}">` +
    l.text.replace(/&/g, '&amp;').replace(/</g, '&lt;') + '</div>').join('');
  return `<!doctype html><meta charset="utf-8"><style>
    ${bubble.fontFaces(FONTS)}
    html,body { margin:0; width:${W}px; background:transparent; }
    #strip { width:${W}px; padding:${BAND_H / 2}px 0; box-sizing:border-box; }
    .l {
      font: 600 40px/1.3 'Inter', system-ui, sans-serif;
      color: rgba(255,255,255,.30);
      padding: 16px 56px; text-align:left;
      text-shadow: 0 2px 10px rgba(0,0,0,.8);
    }
    .l.on { color:#fff; }
  </style><div id="strip">${items}</div>`;
}

/// Splice the frozen beats into the take. Everything downstream is on the
/// shifted clock from here on.
function spliceInPauses(out) {
  if (!splices.length) { fs.copyFileSync(inVideo, out); return; }
  const inputs = [];
  // A still gets looped for its hold; a clip is already the right length.
  splices.forEach((b, i) => b.clip
    ? inputs.push('-i', b.clip)
    : inputs.push('-loop', '1', '-t', String(b.hold),
                  '-i', path.join(work, `splice${i}.png`)));

  const parts = [];
  const chain = [`[0:v]split=${splices.length + 1}${splices.map((_, i) => `[c${i}]`).join('')}[c${splices.length}]`];
  let from = 0;
  splices.forEach((b, i) => {
    chain.push(`[c${i}]trim=${from}:${b.t},setpts=PTS-STARTPTS,fps=25,setsar=1[s${i}]`);
    chain.push(`[${i + 1}:v]fps=25,setsar=1,format=yuv420p[p${i}]`);
    parts.push(`[s${i}]`, `[p${i}]`);
    from = b.t;
  });
  chain.push(`[c${splices.length}]trim=${from},setpts=PTS-STARTPTS,fps=25,setsar=1[s${splices.length}]`);
  parts.push(`[s${splices.length}]`);
  chain.push(`${parts.join('')}concat=n=${parts.length}:v=1:a=0[v]`);

  execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', inVideo, ...inputs,
    '-filter_complex', chain.join(';'), '-map', '[v]',
    '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', '-pix_fmt', 'yuv420p', out],
    { stdio: 'inherit' });
}

/// Punch in on part of the frame and back out again.
///
/// A phone screen recorded whole is a laptop-sized thumbnail by the time anyone
/// watches it, and the moments this video exists for are made of small text -- a
/// key, a signature, a verdict. Those have to be zoomed or they are decoration.
///
/// zoompan, because it is the one filter here whose expressions are evaluated
/// per frame; crop's are evaluated once, at init. Its clock is the frame number,
/// hence on/25 rather than t.
function punchIn(src, out) {
  if (!zooms.length) { fs.copyFileSync(src, out); return; }

  // Nested ifs, innermost last: outside every cue's window the zoom is 1, which
  // is the frame as shot.
  const ramp = (base, z) => {
    let e = base;
    for (const c of zooms) {
      const t0 = shift(c.t), tIn = c.in ?? 0.6, tOut = c.out ?? 0.6;
      const t1 = t0 + tIn, t2 = t1 + (c.hold ?? 2), t3 = t2 + tOut;
      const k = `min(1,max(0,(T-${t0})/${tIn}))-min(1,max(0,(T-${t2})/${tOut}))`;
      e = `if(between(T,${t0},${t3}), ${z(c)}(${k}), ${e})`;
    }
    return e.replace(/T/g, '(on/25)');
  };

  const zOf = c => W / c.to[2];
  const z = ramp('1', c => `1+${(zOf(c) - 1).toFixed(4)}*`);
  // The crop window's top-left, in the blown-up frame, clamped so the zoom never
  // runs off the edge of the picture. Base 0: outside a cue there is no offset.
  const pos = (axis, size) => ramp('0', c => {
    const centre = axis === 'x' ? c.to[0] : c.to[1];
    return `(min(${(size * zOf(c) - size).toFixed(1)},max(0,${(centre * zOf(c) - size / 2).toFixed(1)})))*`;
  });

  execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', src, '-vf',
    `zoompan=z='${z}':x='${pos('x', W)}':y='${pos('y', H)}':d=1:s=${W}x${H}:fps=25`,
    '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', '-pix_fmt', 'yuv420p', out],
    { stdio: 'inherit' });
}

/// Lay the prompter over the bottom of the frame. The strip is one tall image
/// per line and the crop window walks down it, so the text physically scrolls
/// rather than cutting between captions.
function layPrompter(src, out, geom) {
  if (!lines.length) { fs.copyFileSync(src, out); return; }
  const total = DUR + splices.reduce((s, b) => s + b.hold, 0);
  const bandY = H - BAND_H;

  // A dark gradient behind the text, so it reads over a bright feed.
  const scrim = path.join(work, 'scrim.png');
  execFileSync('ffmpeg', ['-y', '-v', 'error', '-f', 'lavfi', '-i',
    `color=c=black:s=${W}x${BAND_H},format=rgba,` +
    // Nearly opaque, with a short feather at the very top where it meets the
    // picture. Two earlier versions were too weak and too gradual: the app's own
    // caption sits near the TOP of the band on the scanner screen, where a ramp
    // spread over the band's height was still only half opaque, and white text
    // read through and tangled with the prompter line. Reach full cover in forty
    // pixels, not three hundred.
    `geq=r=0:g=0:b=0:a='255*min(1,Y/40+0.12)'`,
    '-frames:v', '1', scrim]);

  const inputs = ['-loop', '1', '-t', String(total), '-i', scrim];
  lines.forEach((_, i) => inputs.push('-loop', '1', '-t', String(total),
    '-i', path.join(work, `strip${i}.png`)));

  // The window walks down the strip by moving the strip UP behind a transparent
  // band the size of the window. crop can't do this -- its expressions are
  // evaluated once, at init -- but overlay's are evaluated per frame, and a
  // canvas the size of the band clips whatever hangs off it.
  const chain = [`[1:v]format=rgba[scrim]`,
                 `[0:v][scrim]overlay=0:${bandY}[base]`,
                 `color=c=black@0.0:s=${W}x${BAND_H}:d=${total}:r=25,format=rgba,` +
                 `split=${lines.length}${lines.map((_, i) => `[bb${i}]`).join('')}`];
  let prev = 'base';
  lines.forEach((l, i) => {
    const t = shift(l.t);
    const next = i + 1 < lines.length ? shift(lines[i + 1].t) : total + 1;
    const off = j => Math.max(0, Math.min(geom[i].h - BAND_H,
      geom[i].centres[j] - BAND_H / 2));
    const to = off(i), fromOff = i === 0 ? to : off(i - 1);
    const y = `-(${fromOff}+(${to - fromOff})*min(1,max(0,(t-${t})/${SCROLL})))`;
    chain.push(`[${i + 2}:v]format=rgba[s${i}]`);
    chain.push(`[bb${i}][s${i}]overlay=x=0:y='${y}'[l${i}]`);
    const outPad = i === lines.length - 1 ? '[v]' : `[o${i}]`;
    chain.push(`[${prev}][l${i}]overlay=0:${bandY}:enable='between(t,${t},${next})'${outPad}`);
    prev = `o${i}`;
  });

  execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', src, ...inputs,
    '-filter_complex', chain.join(';'), '-map', '[v]',
    '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', '-pix_fmt', 'yuv420p', out],
    { stdio: 'inherit' });
}
