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

  return {
    E, Eout, sleep, waitForStillScreen, foregroundApp, waitForApp,
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
