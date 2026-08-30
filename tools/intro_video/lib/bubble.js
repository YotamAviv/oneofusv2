// A speech bubble that points at something on the frame.
//
// Drawn in a browser rather than by ffmpeg's subtitle renderer: ASS can't draw a
// tail that reaches a particular pixel, and CSS can. Each cue names an `anchor`
// -- the point on the frame the bubble is about -- and the tail is built to it.
//
// Exported as CSS/HTML/JS fragments rather than a whole page so a caller can put
// a bubble on top of whatever else it is drawing (see annotate.js, which puts
// one over a dimmed freeze-frame).

const fs = require('fs');
const path = require('path');

const STYLES = {
  narrator: {
    font: "'Inter', system-ui, sans-serif",
    size: 44, weight: 600, lineHeight: 1.34,
    fill: 'rgba(17,23,31,.94)',
    text: '#f4f7fb',
    border: 'rgba(255,255,255,.16)',
    pointer: 'rgba(255,255,255,.92)',  // over a dimmed frame, the leader is light
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
    pointer: '#fffdf4',
    accent: null,
    radius: 34,
    maxWidth: 720,
  },
};

function fontFaces(fontsDir) {
  const b64 = f => 'data:font/ttf;base64,' +
    fs.readFileSync(path.join(fontsDir, f)).toString('base64');
  return `
    @font-face { font-family:'Comic Neue'; src:url('${b64('ComicNeue-Bold.ttf')}') format('truetype'); font-weight:700; }
    @font-face { font-family:'Inter'; src:url('${b64('Inter-SemiBold.ttf')}') format('truetype'); font-weight:600; }`;
}

const CSS = `
  #tail { position:absolute; inset:0; width:100%; height:100%; overflow:visible; }
  #b {
    position:absolute; box-sizing:border-box;
    padding:24px 32px 26px; text-align:center; white-space:pre-wrap;
    filter: drop-shadow(0 10px 26px rgba(0,0,0,.5));
  }
  #b .rule { height:3px; border-radius:2px; margin:0 auto 14px; width:64px; }`;

const HTML = `<svg id="tail"></svg><div id="b"></div>`;

/// `W` is the frame width, used to centre a bubble that gives no x.
const JS = W => `
window.renderBubble = (cue, st) => {
  const b = document.getElementById('b');
  b.style.font = st.weight + ' ' + st.size + 'px/' + st.lineHeight + ' ' + st.font;
  b.style.background = st.fill;
  b.style.color = st.text;
  b.style.border = '2.5px solid ' + st.border;
  b.style.borderRadius = st.radius + 'px';
  b.style.maxWidth = st.maxWidth + 'px';
  b.innerHTML = (st.accent ? '<div class="rule" style="background:' + st.accent + '"></div>' : '')
              + cue.text.replace(/&/g,'&amp;').replace(/</g,'&lt;');

  b.style.left = '0px'; b.style.top = '0px';
  const w = b.getBoundingClientRect().width, h = b.getBoundingClientRect().height;
  const x = cue.x != null ? cue.x : Math.round((${W} - w) / 2);
  const y = cue.y;
  b.style.left = x + 'px'; b.style.top = y + 'px';

  // Near anchors get a real speech-bubble tail; far ones get a thin leader line
  // ending in a ring. A tail stretched across half the frame reads as a spike
  // laid over the UI, not as a bubble.
  const TAIL_MAX = 240;
  const [ax, ay] = cue.anchor;
  const above = ay < y + h / 2;
  const edgeY = above ? y : y + h;
  const half = Math.min(46, w / 5);
  const bx = Math.max(x + st.radius + half, Math.min(x + w - st.radius - half, ax));
  const dx = ax - bx, dy = ay - edgeY;
  const dist = Math.hypot(dx, dy) || 1;
  const ux = dx / dist, uy = dy / dist;
  const shadow = 'filter:drop-shadow(0 6px 14px rgba(0,0,0,.45))';
  const svg = document.getElementById('tail');

  if (dist <= TAIL_MAX) {
    const tipX = ax - ux * 8, tipY = ay - uy * 8;
    const c = 0.58;
    const cax = bx - half * 0.30 + dx * c, cay = edgeY + dy * c;
    const cbx = bx + half * 0.30 + dx * c, cby = edgeY + dy * c;
    svg.innerHTML =
      '<path d="M ' + (bx - half) + ' ' + edgeY +
      ' Q ' + cax + ' ' + cay + ' ' + tipX + ' ' + tipY +
      ' Q ' + cbx + ' ' + cby + ' ' + (bx + half) + ' ' + edgeY + ' Z"' +
      ' fill="' + st.fill + '" stroke="' + st.border + '" stroke-width="2.5"' +
      ' stroke-linejoin="round" style="' + shadow + '"/>';
  } else {
    const ex = ax - ux * 17, ey = ay - uy * 17;
    svg.innerHTML =
      '<line x1="' + bx + '" y1="' + edgeY + '" x2="' + ex + '" y2="' + ey + '"' +
      ' stroke="rgba(0,0,0,.55)" stroke-width="8" stroke-linecap="round"/>' +
      '<line x1="' + bx + '" y1="' + edgeY + '" x2="' + ex + '" y2="' + ey + '"' +
      ' stroke="' + st.pointer + '" stroke-width="4" stroke-linecap="round" style="' + shadow + '"/>' +
      '<circle cx="' + ax + '" cy="' + ay + '" r="17" fill="none"' +
      ' stroke="rgba(0,0,0,.55)" stroke-width="8"/>' +
      '<circle cx="' + ax + '" cy="' + ay + '" r="17" fill="none"' +
      ' stroke="' + st.pointer + '" stroke-width="4" style="' + shadow + '"/>';
  }
  return { w, h, x, y, tail: dist <= TAIL_MAX ? 'tail' : 'leader' };
};`;

module.exports = { STYLES, fontFaces, CSS, HTML, JS };
