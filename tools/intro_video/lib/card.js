// A full screen of text.
//
// Shared, because a card is made in two places: card.js renders one as a clip of
// its own, and annotate.js splices one into a take at a mark. They have to look
// identical, so the page lives here rather than in either of them.
//
// The first line is the statement and the rest explain it -- rendered large and
// small respectively. That is the only structure a card has.

const bubble = require('./bubble');

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

/// The HTML for one card, sized to the frame.
function page(lines, { W, H, fontsDir }) {
  return `<!doctype html><meta charset="utf-8"><style>
  ${bubble.fontFaces(fontsDir)}
  html,body { margin:0; width:${W}px; height:${H}px; background:#12181f; }
  #c {
    width:${W}px; height:${H}px; box-sizing:border-box; padding:0 110px;
    display:flex; flex-direction:column; align-items:center; justify-content:center;
    font-family:'Inter', system-ui, sans-serif; text-align:center;
  }
  h1 { font-size:92px; line-height:1.12; font-weight:600; color:#f4f7fb; margin:0 0 34px; }
  p  { font-size:60px; line-height:1.3;  font-weight:600; color:rgba(244,247,251,.62); margin:0 0 18px; }
  #rule { width:120px; height:5px; border-radius:3px; background:rgba(120,190,255,.85); margin-top:52px; }
</style>
<div id="c">
  <h1>${esc(lines[0])}</h1>
  ${lines.slice(1).map(l => `<p>${esc(l)}</p>`).join('')}
  <div id="rule"></div>
</div>`;
}

module.exports = { page };
