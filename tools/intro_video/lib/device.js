// Driving the phone itself, for takes that aren't in a browser.
//
// The identity app is native Flutter and exposes no accessibility tree, so
// nothing here can tap by name the way lib/semantics.js does. Taps are
// coordinates and waits are "has the screen stopped changing" -- which is a
// real condition, unlike a sleep, and covers the case that actually bites: the
// app is foreground but still painting, and a tap lands on nothing.

const { execFileSync } = require('child_process');

const sleep = ms => new Promise(r => setTimeout(r, ms));

function device(serial = process.env.AVD || 'emulator-5554') {
  const E = (...a) => execFileSync('adb', ['-s', serial, ...a], { stdio: 'ignore' });
  const Eout = (...a) => execFileSync('adb', ['-s', serial, ...a]).toString();

  /// Wait until the screen stops changing. Grabs frames and compares them --
  /// the closest thing to a condition when there is nothing to query.
  ///
  /// The status bar is cropped off before comparing. It is never still: the
  /// clock ticks, and while a take is recording there is a recording chip up
  /// there too, so hashing the whole screen means "still" never happens and
  /// every wait runs to its timeout. That turned a 25-second take into 90
  /// seconds of mostly nothing.
  const waitForStillScreen = async (timeout = 20000, quietMs = 900) => {
    const grab = () => execFileSync('bash', ['-c',
      `adb -s ${serial} exec-out screencap -p | ` +
      `ffmpeg -v error -i - -vf crop=in_w:in_h-220:0:120 -f rawvideo - | md5sum | cut -d' ' -f1`],
      { encoding: 'utf8' }).trim();
    const t0 = Date.now();
    let last = '', since = Date.now();
    while (Date.now() - t0 < timeout) {
      const now = grab();
      if (now === last) { if (Date.now() - since >= quietMs) return true; }
      else { last = now; since = Date.now(); }
      await sleep(250);
    }
    return false;
  };

  const foregroundApp = () => {
    const m = Eout('shell', 'dumpsys', 'activity', 'activities')
      .match(/topResumedActivity=ActivityRecord\{\S+ \S+ (\S+?)\//);
    return m ? m[1] : '';
  };

  const waitForApp = async (pkg, timeout = 20000) => {
    const t0 = Date.now();
    while (Date.now() - t0 < timeout) {
      if (foregroundApp() === pkg) return true;
      await sleep(250);
    }
    throw new Error(`timeout waiting for ${pkg}`);
  };

  /// Mean brightness of the screen, 0-255. Cheap: the frame is scaled to 8x8
  /// grey before it is read.
  const brightness = () => {
    const buf = execFileSync('bash', ['-c',
      `adb -s ${serial} exec-out screencap -p | ` +
      `ffmpeg -v error -i - -vf scale=8:8,format=gray -f rawvideo -`],
      { encoding: 'buffer', maxBuffer: 1 << 20 });
    let sum = 0;
    for (const b of buf) sum += b;
    return buf.length ? sum / buf.length : 0;
  };

  /// Wait for the screen to go bright, and report WHEN -- the midpoint between
  /// the last dark reading and the first bright one.
  ///
  /// This is how the sync flash gets its instant on a native take. Zeroing the
  /// clock at some fixed sleep after asking for the flash is not good enough:
  /// whatever paints it takes an unknown moment to do so, find_flash.js locks
  /// onto the first bright FRAME, and the gap between the two lands every touch
  /// indicator early by exactly that much.
  const waitForBright = async (threshold = 200, timeout = 15000) => {
    const t0 = Date.now();
    let last = Date.now();
    while (Date.now() - t0 < timeout) {
      const b = brightness();
      if (b >= threshold) return (last + Date.now()) / 2;
      last = Date.now();
    }
    throw new Error('screen never went bright — no sync flash');
  };

  /// The same, for a dark flash. A white flash is invisible to find_flash.js on
  /// a take that is mostly white -- a browser, say -- because it barely beats the
  /// median. Black stands out there instead.
  const waitForDark = async (threshold = 60, timeout = 15000) => {
    const t0 = Date.now();
    let last = Date.now();
    while (Date.now() - t0 < timeout) {
      const b = brightness();
      if (b <= threshold) return (last + Date.now()) / 2;
      last = Date.now();
    }
    throw new Error('screen never went dark — no sync flash');
  };

  /// Re-point the devtools forward at Chrome's socket.
  ///
  /// Must happen AFTER Chrome is (re)started. The socket is new each time, and a
  /// forward set up against the old one still looks fine until something
  /// connects to it, at which point it is a "socket hang up" several steps away
  /// from the cause.
  const forwardDevtools = async (port = 9222) => {
    try { E('forward', '--remove-all'); } catch { /* nothing forwarded yet */ }
    E('forward', `tcp:${port}`, 'localabstract:chrome_devtools_remote');
    for (let i = 0; i < 40; i++) {
      try { if ((await fetch(`http://localhost:${port}/json/version`)).ok) return; } catch {}
      await sleep(500);
    }
    throw new Error(`Chrome devtools never came up on localhost:${port}`);
  };

  /// Stop a screenrecord running on the device, and wait until its file has
  /// stopped growing.
  ///
  /// Killing the local `adb shell screenrecord` process does not reliably stop
  /// the remote one, and a fixed sleep afterwards is a guess. On a long take the
  /// guess was wrong: five seconds of the signature-chain take were never in the
  /// pulled file, which surfaced two steps later as annotate.js trying to grab a
  /// frame past the end. Signal the process on the device, then watch the size.
  const stopRecording = async (remotePath, timeout = 30000) => {
    try { E('shell', 'pkill', '-INT', 'screenrecord'); } catch { /* already gone */ }
    const size = () => {
      try { return +Eout('shell', 'stat', '-c', '%s', remotePath).trim() || 0; }
      catch { return 0; }
    };
    const t0 = Date.now();
    let last = -1, stable = 0;
    while (Date.now() - t0 < timeout) {
      await sleep(700);
      const now = size();
      if (now > 0 && now === last) { if (++stable >= 3) return now; }
      else stable = 0;
      last = now;
    }
    return last;
  };

  return {
    E, Eout, sleep, waitForStillScreen, foregroundApp, waitForApp, forwardDevtools,
    stopRecording,
    brightness, waitForBright, waitForDark,
    tap: (x, y) => E('shell', 'input', 'tap', String(Math.round(x)), String(Math.round(y))),
    type: text => E('shell', 'input', 'text', text.replace(/ /g, '%s')),
    /// One character at a time, so it reads as typing rather than a paste.
    typeSlow: async (text, perCharMs = 180) => {
      for (const ch of text) {
        E('shell', 'input', 'text', ch === ' ' ? '%s' : ch);
        await sleep(perCharMs);
      }
    },
    launch: pkg => E('shell', 'monkey', '-p', pkg, '-c', 'android.intent.category.LAUNCHER', '1'),
    clear: pkg => Eout('shell', 'pm', 'clear', pkg).trim(),
    open: uri => E('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', uri),
    screencap: path => execFileSync('bash',
      ['-c', `adb -s ${serial} exec-out screencap -p > ${path}`]),
  };
}

module.exports = { device, sleep };
