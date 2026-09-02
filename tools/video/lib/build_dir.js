// Where a take and everything made from it lives.
//
// One directory per build, stamped once:
//
//   out/<name>/<stamp>/vouch.mp4
//                      vouch.marks.json
//                      vouch_taps.mp4
//                      vouch_taps_annotated.mp4
//                      vouch_taps_annotated.work/    <- scratch, beside its output
//
// THE STAMP IS ON THE DIRECTORY, NOT ON EVERY FILE. Derived files inherit the
// take's name, so one lineage carries one stamp and names stay readable --
// `vouch_taps_composited_annotated.mp4` rather than that with two dates in it.
// Nothing is ever overwritten, because nothing is ever written twice to the
// same path.
//
// sections.py sets BUILD_DIR so a section's takes, intermediates and finished
// video land together; a script run by hand names its own directory the same
// way. Either way the path is stamped, which is what keeps a good take safe.
const fs = require('fs');
const path = require('path');

/// YYYYMMDD-HHMMSS, the stamp every take has used since the beginning.
function stamp(d = new Date()) {
  const p2 = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p2(d.getMonth() + 1)}${p2(d.getDate())}-` +
         `${p2(d.getHours())}${p2(d.getMinutes())}${p2(d.getSeconds())}`;
}

/// The build directory for a take, created.
function buildDir(name) {
  const dir = process.env.BUILD_DIR ||
              path.join(__dirname, '..', 'out', name, stamp());
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

module.exports = { buildDir, stamp };
