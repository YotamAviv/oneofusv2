// Renders the same contact blob + release ripple the web overlay draws, as a
// transparent PNG sequence, so taps composited onto Android footage match.
const { chromium } = require('playwright');
const fs = require('fs');
const R = 40, N = 16, W = 280, H = 280;
const frame = i => {
  const t = i / (N - 1);
  const down = t < 0.35;
  const blobOp = down ? 1 : Math.max(0, 1 - (t - 0.35) / 0.25);
  const blobSc = down ? 1 : 1 + (t - 0.35) * 0.5;
  const rs = Math.max(0, (t - 0.3) / 0.7);
  const ringSc = 0.55 + rs * 1.75, ringOp = rs > 0 ? Math.max(0, 0.95 - rs) : 0;
  return `<div class="w">
    <div class="ring" style="transform:translate(-50%,-50%) scale(${ringSc});opacity:${ringOp}"></div>
    <div class="blob" style="transform:translate(-50%,-50%) scale(${blobSc});opacity:${blobOp}"></div>
  </div>`;
};
const CSS = `<style>html,body{margin:0;width:${W}px;height:${H}px;background:transparent}
 .w{position:relative;width:${W}px;height:${H}px}
 .blob,.ring{position:absolute;left:50%;top:50%;width:${R*2}px;height:${R*2}px;border-radius:50%}
 /* Colour so a tap reads instantly over both light UI and dark posters:
    warm amber core, white halo for contrast, dark hairline to hold an edge. */
 .blob{background:radial-gradient(circle at 34% 28%,rgba(255,236,196,.98),rgba(255,183,77,.92) 45%,rgba(255,138,0,.78));
   border:2.5px solid rgba(60,30,0,.65);
   box-shadow:0 0 0 3px rgba(255,255,255,.95),0 0 26px rgba(255,168,38,.85),0 4px 18px rgba(0,0,0,.5)}
 .ring{border:5px solid rgba(255,170,40,.95);
   box-shadow:0 0 0 2.5px rgba(255,255,255,.9),0 0 22px rgba(255,150,20,.7)}
</style>`;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: W, height: H } });
  fs.rmSync('tapfx', { recursive: true, force: true }); fs.mkdirSync('tapfx');
  for (let i = 0; i < N; i++) {
    await p.setContent(CSS + frame(i));
    await p.screenshot({ path: `tapfx/t${String(i).padStart(2,'0')}.png`, omitBackground: true });
  }
  await b.close();
  console.log(`${N} frames -> tapfx/`);
})();
