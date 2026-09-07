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
const { TRIM_PAD, loadMarks, timeOf } = require('./lib/marks');

const FONTS = path.join(__dirname, 'fonts');
const [cueFile, inVideo] = process.argv.slice(2);
if (!inVideo) { console.error('usage: annotate.js <cues.json> <in.mp4>'); process.exit(1); }
const cues = JSON.parse(fs.readFileSync(cueFile, 'utf8'));

// THE PROMPTER IS A CAPTION, NOT A FIXTURE.
//
// It used to be a 300px band pinned to the bottom for the whole section: every
// line rendered at once, the current one lit, the strip scrolling between them.
// Being permanent and that tall, it sat on the bottom of the frame even with
// nothing to say -- which is where an app puts its bottom bar. It hid the Share
// button in `invite` (y=2061), two tapped controls in `vouch` (1930 and 1983),
// and the "Trusted: Success" snackbar the vouch section is *about*.
//
// Now one line shows at a time, sized to itself -- about 145px for a single
// line rather than 300 -- and it is on screen only while it is being said. The
// bottom of the picture is unobstructed by default instead of by exception.
const EDGE = cues.prompter_at || 'bottom';   // default; a line may override it
const sideOf = l => {
  const side = l.side || EDGE;
  if (!['top', 'bottom'].includes(side)) {
    throw new Error(`prompter side: ${side} -- expected 'top' or 'bottom'.`);
  }
  return side;
};

// How long a line stays up when it does not say. Roughly reading speed, with a
// floor so a three-word line does not blink. `hold` on the line overrides it.
const readingTime = text => Math.max(1.9, text.replace(/\s+/g, ' ').length / 13) + 0.5;

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
// A FLASH is one word thrown up over the take and taken away again, WITHOUT
// stopping it. That is the whole difference from a card or a beat: those splice
// a pause in and everything after them moves, so they are for when the viewer
// should stop and read. A flash is for a word that belongs ON the action --
// "Decentralized", over the moment the point is being made -- and the action
// keeps running underneath it.
//
// A flash may carry a `tail:` -- a sentence that arrives as the letters blow
// apart and STAYS, for `tail_hold` seconds. The word is the hit and cannot be
// read; the tail is the thing that can. It is one cue, not two, because the two
// are glued: the tail starts exactly where the word ends, and moving the flash
// has to move it.
const flashes = resolve(cues.flashes, 'flash').map(f => ({
  ...f, hold: f.hold ?? 0.9, tailHold: f.tail_hold ?? 3.5,
}));

// When each line comes DOWN. Three things can end it, whichever comes first:
//
//   - its own reading time (or an explicit `hold`),
//   - the next line, which replaces it,
//   - a beat or a card, which is a full stop with its own words on it. The band
//     used to draw over spliced stills too, and that is the reason the vouch
//     snackbar could not be rescued by a beat. Now it can.
lines.forEach((l, i) => {
  const next = i + 1 < lines.length ? lines[i + 1].t : Infinity;
  const splice = splices.find(b => b.t > l.t);
  const own = l.t + (l.hold != null ? l.hold : readingTime(l.text));
  l.end = Math.min(own, next, splice ? splice.t : Infinity);
});
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
                            ['flash', flashes], ['beat or card', splices]]) {
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

  // --- one caption per line, each carrying its own scrim and sized to itself ---
  const strip = await browser.newPage({ viewport: { width: W, height: 400 } });
  const geom = [];
  for (const [i, l] of lines.entries()) {
    await strip.setContent(linePage(l));
    await strip.evaluate(() => document.fonts.ready);
    const h = await strip.evaluate(() =>
      Math.ceil(document.getElementById('band').getBoundingClientRect().height));
    await strip.setViewportSize({ width: W, height: h });
    // omitBackground keeps the alpha, which is the whole point: the scrim is a
    // gradient baked into this image, feathered on the edge that meets the
    // picture, so laying the caption down is a single overlay.
    await strip.screenshot({ path: path.join(work, `strip${i}.png`), omitBackground: true });
    geom.push({ h, side: sideOf(l) });
    // A line the viewer cannot possibly read. It happens when the next line, or
    // a beat, arrives before this one has had its time -- the copy is written
    // against the marks, and the marks come from the take. Half a second of
    // four lines of text is not narration, it is a flicker.
    const up = l.end - l.t, want = readingTime(l.text);
    if (up < Math.min(want * 0.6, 2.5)) {
      console.error(`  WARNING: "${l.text.replace(/\n/g, ' ').slice(0, 44)}" is up for ` +
        `${up.toFixed(1)}s and needs about ${want.toFixed(1)}s to read.\n` +
        `    Shorten it, move it earlier, or move what cuts it off.`);
    }
    console.log(`  line @${l.t}s-${l.end === Infinity ? 'end' : l.end.toFixed(1) + 's'} ` +
                `${h}px ${geom[i].side}  "${l.text.replace(/\n/g, ' ').slice(0, 44)}"`);
  }
  // --- a frame sequence per flash: it SHATTERS, so it has to move ---
  for (const [i, f] of flashes.entries()) {
    if (!f.word) throw new Error(`flash at ${f.t}s has no \`word\`.`);
    const dir = path.join(work, `flash${i}`);
    fs.mkdirSync(dir, { recursive: true });
    await strip.setViewportSize({ width: W, height: H });
    const n = Math.max(2, Math.round(f.hold * FLASH_FPS));
    for (let k = 0; k < n; k++) {
      await strip.setContent(flashPage(f, k / (n - 1)));
      if (k === 0) await strip.evaluate(() => document.fonts.ready);
      await strip.screenshot({ path: path.join(dir, `f${String(k).padStart(3, '0')}.png`),
                               omitBackground: true });
    }
    f.frames = n;
    console.log(`  flash @${f.t}s  ${f.hold}s  ${n} frames  "${f.word}"`);
    if (!f.tail) continue;

    // The tail. Only the frames that MOVE are rendered -- the sweep on and the
    // fade off -- and the settled frame is copied for the seconds in between,
    // which is the whole point of a line that stays: nothing is happening in
    // the middle of it. Three seconds of hold costs no renders at all.
    const tdir = path.join(work, `tail${i}`);
    fs.mkdirSync(tdir, { recursive: true });
    const tn = Math.max(2, Math.round(f.tailHold * FLASH_FPS));
    const fadeAt = tn - Math.round(TAIL_FADE * FLASH_FPS);
    const name = k => path.join(tdir, `f${String(k).padStart(3, '0')}.png`);
    let settled = null;
    for (let k = 0; k < tn; k++) {
      const sweep = Math.min(1, k / (TAIL_SWEEP * FLASH_FPS));
      const alpha = k < fadeAt ? 1 : Math.max(0, (tn - 1 - k) / (tn - 1 - fadeAt));
      if (sweep === 1 && alpha === 1) {
        if (settled) { fs.copyFileSync(settled, name(k)); continue; }
        settled = name(k);
      }
      await strip.setContent(tailPage(f.tail, sweep, alpha));
      await strip.screenshot({ path: name(k), omitBackground: true });
    }
    f.tailFrames = tn;
    console.log(`  tail  @+${f.hold}s  ${f.tailHold}s  ${tn} frames  ` +
                `"${f.tail.replace(/\n/g, ' ').slice(0, 44)}"`);
  }
  await browser.close();
  warnBuriedTaps(geom);

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
  const prompted = flashes.length ? path.join(work, 'prompted.mp4') : out;
  layPrompter(zoomed, prompted, geom);
  if (flashes.length) layFlashes(prompted, out);
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

/// One caption: the line, on a scrim that fades out on the side facing the
/// picture. Self-contained, so laying it down is a single overlay and its
/// height is whatever the text needs rather than a fixed band.
function linePage(l) {
  const side = sideOf(l);
  // The feather goes on the edge that MEETS THE PICTURE -- the top edge for a
  // caption along the bottom. Near-opaque, and quickly: two earlier scrims were
  // weak and gradual, and the app's own white captions read straight through
  // them and tangled with the prompter line.
  const grad = side === 'bottom'
    ? 'to bottom, rgba(0,0,0,0) 0, rgba(0,0,0,.97) 44px, rgba(0,0,0,.97) 100%'
    : 'to top,    rgba(0,0,0,0) 0, rgba(0,0,0,.97) 44px, rgba(0,0,0,.97) 100%';
  const pad = side === 'bottom' ? '58px 56px 44px' : '44px 56px 58px';
  return `<!doctype html><meta charset="utf-8"><style>
    ${bubble.fontFaces(FONTS)}
    html,body { margin:0; width:${W}px; background:transparent; }
    #band {
      width:${W}px; box-sizing:border-box; padding:${pad};
      background: linear-gradient(${grad});
      font: 600 40px/1.3 'Inter', system-ui, sans-serif;
      color:#fff; text-align:left;
      text-shadow: 0 2px 10px rgba(0,0,0,.8);
    }
  </style><div id="band">${
    l.text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/\n/g, '<br>')
  }</div>`;
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

/// Lay each caption over the frame for exactly as long as it is being said.
///
/// One overlay per line, enabled between its start and its end, positioned at
/// whichever edge that line asked for. No scrolling strip and no persistent
/// band: between lines there is nothing over the picture at all.
function layPrompter(src, out, geom) {
  if (!lines.length) { fs.renameSync(src, out); return; }
  const total = DUR + splices.reduce((s, b) => s + b.hold, 0);

  const inputs = [];
  const chain = ['[0:v]null[p0]'];
  let prev = 'p0';
  lines.forEach((l, i) => {
    inputs.push('-loop', '1', '-t', String(total), '-i', path.join(work, `strip${i}.png`));
    // Through shift(), like every other cue: a splice before this line moves it
    // later in the finished video.
    const from = shift(l.t);
    const to = l.end === Infinity ? total : shift(l.end);
    const y = geom[i].side === 'top' ? 0 : H - geom[i].h;
    const next = `p${i + 1}`;
    chain.push(`[${i + 1}:v]format=rgba[c${i}]`);
    chain.push(`[${prev}][c${i}]overlay=0:${y}:` +
               `enable='between(t,${from.toFixed(3)},${to.toFixed(3)})'[${next}]`);
    prev = next;
  });
  chain.push(`[${prev}]format=yuv420p[v]`);

  execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', src, ...inputs,
    '-filter_complex', chain.join(';'), '-map', '[v]',
    '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', '-pix_fmt', 'yuv420p', out],
    { stdio: 'inherit' });
}

/// One frame of a flashed word that SHATTERS.
///
/// The word snaps together, holds for most of its length, and then every letter
/// leaves on its own vector, spinning and fading. A static word appearing and
/// disappearing read as a subtitle; the point of a flash is that it hits.
///
/// The vectors are DERIVED FROM THE LETTER'S INDEX, not random. Re-rendering
/// the same cue has to give the same frames, or a rebuild quietly produces a
/// different video from the one that was approved.
///
/// COLOUR AND PLACE ARE THE CUE'S. Amber over the middle is the default and was
/// once the only option, which is fine for one flash and wrong for four in a
/// row -- they land on top of each other and read as one word changing. `colour`
/// takes any CSS colour and the glow is derived from it; `x` and `y` are
/// fractions of the frame, naming where the word's centre goes; `size` is the
/// font in px, for a long word that would otherwise run off the edge.
const FLASH_FPS = 25;
const FLASH_DEFAULTS = { colour: '#FF9A12', x: 0.5, y: 0.38, size: 128 };
function flashPage(f, p) {
  const word = f.word;
  const { colour, x, y, size } = { ...FLASH_DEFAULTS,
    ...(f.color != null ? { colour: f.color } : {}),
    ...Object.fromEntries(Object.entries(f).filter(([k, v]) =>
      v != null && ['colour', 'x', 'y', 'size'].includes(k))) };
  const IN = 0.16, OUT = 0.55;          // assemble by 16%, start leaving at 55%
  const inP = Math.min(1, p / IN);
  const ease = 1 - Math.pow(1 - inP, 3);
  const out = p <= OUT ? 0 : (p - OUT) / (1 - OUT);
  const spans = [...word].map((ch, i) => {
    // A cheap deterministic hash of the index, spread over the circle.
    const a = (Math.sin(i * 12.9898) * 43758.5453) % 1;
    const b = (Math.sin(i * 78.233) * 12345.6789) % 1;
    // UP AND OUT. The angle is biased to the upper half and the drift is
    // negative, so the word blows apart rather than crumbling -- an earlier
    // version added gravity and the letters fell down the screen, which reads
    // as collapse and is the opposite of the point.
    const ang = -Math.PI * 0.15 - a * Math.PI * 0.7;     // upward fan
    const dist = (300 + Math.abs(b) * 460) * Math.pow(out, 1.6);
    const dx = Math.cos(ang) * dist * 1.25 + (out ? 0 : (1 - ease) * (a * 160 - 80));
    const dy = Math.sin(ang) * dist - 260 * Math.pow(out, 1.4)
             + (out ? 0 : (1 - ease) * (b * 200 - 100));
    const rot = out * (b * 200 - 100) + (out ? 0 : (1 - ease) * (a * 40 - 20));
    const sc = out ? 1 + out * 0.45 : 0.72 + 0.28 * ease;
    const op = out ? Math.max(0, 1 - out * 1.3) : ease;
    return `<span style="display:inline-block;
      transform:translate(${dx.toFixed(1)}px,${dy.toFixed(1)}px) rotate(${rot.toFixed(1)}deg)
        scale(${sc.toFixed(3)});opacity:${op.toFixed(3)}">${
      ch === ' ' ? '&nbsp;' : ch.replace(/&/g, '&amp;').replace(/</g, '&lt;')}</span>`;
  }).join('');
  return `<!doctype html><meta charset="utf-8"><style>
    ${bubble.fontFaces(FONTS)}
    html,body { margin:0; width:${W}px; height:${H}px; overflow:hidden; background:transparent; }
    #f {
      position:absolute; left:0; right:0; top:${(y * 100).toFixed(2)}%;
      transform: translateX(${((x - 0.5) * W).toFixed(0)}px);
      font: 800 ${size}px/1.05 'Inter', system-ui, sans-serif;
      text-align:center; letter-spacing:-2px; white-space:nowrap;
      /* Not white: white washed out against a light app screen. A gradient
         through the glyphs was tried first and came out INVISIBLE --
         background-clip:text paints nothing that survives a screenshot taken
         with omitBackground, and the flash silently rendered as empty frames.
         The dark inner edge and the black drop are what keep a light colour
         legible over a light frame; the outer glow is the colour itself. */
      color:${colour};
      text-shadow: 0 0 2px rgba(0,0,0,.85), 0 4px 16px rgba(0,0,0,.55),
                   0 0 40px ${colour};
    }
  </style><div id="f">${spans}</div>`;
}

/// One frame of the sentence that follows a flashed word.
///
/// The opposite act from the flash above it, and it should look like one. The
/// word hits and shatters; this is SWEPT ON, left to right, and then holds
/// still to be read. An amber rule draws under it as it arrives -- the flash's
/// colour, on a line that is otherwise white, which is what ties the two
/// together without a second shouting headline.
///
/// It sits at 34%, just above where the word was, because the word is gone by
/// the time this arrives and the space it left is the space to use. On the
/// vouch section that is empty app chrome above the beat's bubble. Remeasure
/// if a section puts something there.
const TAIL_SWEEP = 0.72;   // seconds to sweep on
const TAIL_FADE = 0.35;    // seconds to fade off at the end
function tailPage(text, sweep, alpha) {
  // Eased, so it arrives fast and settles rather than crossing at a constant
  // rate -- a linear wipe reads as a machine printing.
  const e = 1 - Math.pow(1 - sweep, 3);
  const pct = (e * 100).toFixed(1);
  return `<!doctype html><meta charset="utf-8"><style>
    ${bubble.fontFaces(FONTS)}
    html,body { margin:0; width:${W}px; height:${H}px; overflow:hidden; background:transparent; }
    #t {
      position:absolute; left:90px; right:90px; top:34%; text-align:center;
      font: 800 62px/1.32 'Inter', system-ui, sans-serif; letter-spacing:-1px;
      color:#fff; opacity:${alpha.toFixed(3)};
      text-shadow: 0 2px 10px rgba(0,0,0,.85), 0 0 30px rgba(0,0,0,.6);
    }
    /* The reveal is a MASK, not a growing box: the text is laid out once, at its
       final width, and uncovered. A box that widens reflows the words, and the
       line rewraps under itself as it arrives. */
    #t .mask {
      -webkit-mask-image: linear-gradient(90deg, #000 var(--p),
                                          rgba(0,0,0,.06) calc(var(--p) + 9%));
      -webkit-mask-size: 100% 100%;
    }
    #t .rule {
      height:5px; border-radius:3px; margin:20px auto 0; background:#FF9A12;
      box-shadow:0 0 24px rgba(255,154,18,.8);
    }
  </style><div id="t">
    <span class="mask" style="--p:${pct}%">${
      text.replace(/&/g, '&amp;').replace(/</g, '&lt;')}</span>
    <div class="rule" style="width:${(e * 62).toFixed(1)}%"></div>
  </div>`;
}

/// Lay the flashes over the finished frame, last, so nothing draws on top of
/// them. Hard on and hard off: it is a flash.
function layFlashes(src, out) {
  const total = DUR + splices.reduce((s, b) => s + b.hold, 0);

  // Both the word and its tail, in the order they appear, as one list of things
  // to overlay. A flash's span is measured on the FINISHED timeline and does not
  // re-enter shift(): the word runs for its own `hold` from the moment it
  // starts, whatever is spliced in underneath it, and the tail starts where the
  // word ends. Passing the tail's start back through shift() puts it on the far
  // side of any pause the flash overlaps -- on the vouch section that is a four
  // second beat, and the sentence arrived four seconds after the word it follows.
  const layers = [];
  flashes.forEach((f, i) => {
    // `into` PUTS THE FLASH ON THE CARD, which nothing else here can express. A
    // flash is placed at shift(t), and shift() adds the hold of every splice at
    // or before t -- so a flash sharing a card's anchor lands the far side of it,
    // and one a hair earlier lands just before it starts. Neither is over it. A
    // card's still occupies shift(t) - hold to shift(t), so `into` counts from
    // the start of that still, and the word plays while the slide holds.
    let at;
    if (f.into != null) {
      const sp = splices.find(b => Math.abs(b.t - f.t) < 0.001);
      if (!sp) throw new Error(
        `flash "${f.word}" has \`into: ${f.into}\`, which means "this far into the ` +
        `card or beat at the same moment" -- but nothing is spliced in at ${f.t}s.\n` +
        '  Give it the same `at` and `after` as the card it belongs on, or drop `into`.');
      if (f.into + f.hold > sp.hold + 0.001) throw new Error(
        `flash "${f.word}" runs to ${(f.into + f.hold).toFixed(2)}s into a ` +
        `${sp.hold}s ${sp.kind}, so it would carry on over the footage after it.\n` +
        '  Shorten `into` or `hold`, or hold the ' + sp.kind + ' longer.');
      at = shift(f.t) - sp.hold + f.into;
    } else {
      at = shift(f.t);
    }
    // A word cut short by the end of the take is a word; a SENTENCE cut short is
    // copy that goes missing from a build reporting success, which is the
    // failure this file exists to make loud. So the word still clamps and the
    // tail refuses. Beats and cards move everything after them, so this is not
    // something the yaml can be read to check.
    layers.push({ dir: `flash${i}`, from: at, to: Math.min(at + f.hold, total) });
    if (!f.tail) return;
    const from = at + f.hold, to = from + f.tailHold;
    if (to > total + 0.001) throw new Error(
      `The tail of flash "${f.word}" runs to ${to.toFixed(2)}s, past the end of ` +
      `the finished take (${total.toFixed(2)}s).\n` +
      '  Shorten `tail_hold`, move the flash earlier, or give the section more\n' +
      '  to run on. It would be drawn until the take stopped and no further.');
    layers.push({ dir: `tail${i}`, from, to });
  });

  const inputs = [];
  const chain = ['[0:v]null[f0]'];
  let prev = 'f0';
  layers.forEach((l, i) => {
    inputs.push('-framerate', String(FLASH_FPS), '-itsoffset', l.from.toFixed(3),
                '-i', path.join(work, l.dir, 'f%03d.png'));
    const next = `f${i + 1}`;
    chain.push(`[${i + 1}:v]format=rgba[w${i}]`);
    chain.push(`[${prev}][w${i}]overlay=0:0:` +
               `enable='between(t,${l.from.toFixed(3)},${l.to.toFixed(3)})'[${next}]`);
    prev = next;
  });
  chain.push(`[${prev}]format=yuv420p[v]`);
  execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', src, ...inputs,
    '-filter_complex', chain.join(';'), '-map', '[v]',
    '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', '-pix_fmt', 'yuv420p', out],
    { stdio: 'inherit' });
}

/// Warn where a caption is on screen, at the same moment, over a tap.
///
/// The old band was permanent and 300px tall, so this could only ask "is this
/// tap in the bottom 300px?" and it flagged everything down there whether a
/// line was up or not. Now a caption has a start, an end, an edge and a height,
/// so the question is the real one: was anything covering this button when it
/// was pressed?
///
/// Loud, not fatal. A missed sync flash stops the build because it silently
/// misplaces everything; this is a legibility call on output that is otherwise
/// correct, and refusing would block rebuilding a section over it.
function warnBuriedTaps(geom) {
  if (!lines.length) return;
  const hits = [];
  for (const t of (marks && marks.taps) || []) {
    const at = t.t - TRIM_PAD;                 // the tap, on the cue clock
    lines.forEach((l, i) => {
      if (at < l.t || at >= l.end) return;     // no caption up when it happened
      const covered = geom[i].side === 'bottom' ? t.y > H - geom[i].h : t.y < geom[i].h;
      if (covered) hits.push({ t, l, geom: geom[i] });
    });
  }
  if (!hits.length) return;
  console.error(`\n  WARNING: a caption covers ${hits.length > 1 ? 'taps' : 'the tap on'} ` +
    hits.map(h => `"${h.t.what}" at (${h.t.x},${h.t.y})`).join(', ') + '.');
  for (const h of hits) {
    console.error(`    "${h.l.text.replace(/\n/g, ' ').slice(0, 40)}" is ${h.geom.h}px ` +
      `along the ${h.geom.side} while that tap happens.`);
  }
  console.error('    On video the control reacts with nothing having been pressed.\n' +
    "    Give that line `side: " + (geom[0].side === 'bottom' ? 'top' : 'bottom') +
    "`, or shorten the line before it so this one has not started yet.\n");
}
