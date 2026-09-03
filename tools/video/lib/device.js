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
      // JITTER, not a fixed interval. A grab costs most of a second over adb, so
      // fixed sampling lands about a second apart -- and a spinner that turns
      // once a second then hashes the SAME every time, which reads as a still
      // screen. That is how the vouch take came to mark `published` with the
      // publish still spinning. An irregular interval cannot alias.
      await sleep(200 + Math.floor(Math.random() * 500));
    }
    return false;
  };

  /// Wait until a REGION of the screen starts changing again.
  ///
  /// The inverse of waitForStillScreen, and the right tool when what you are
  /// waiting for is a dialog to close. The scanner behind it is a LIVE CAMERA
  /// PREVIEW: it never hashes the same twice, so "wait for the screen to settle"
  /// can never succeed once the app is back on it -- six consecutive samples of
  /// that screen gave six different hashes. Waiting for stillness there times
  /// out and then reports a hang that never happened.
  ///
  /// Pass a crop that the dialog covers and the spinner does not. While the
  /// dialog is up that area is a static form; the moment it closes, the camera
  /// shows through and every sample differs.
  const waitForRegionMotion = async (crop, timeout = 45000, needed = 3) => {
    const grab = () => execFileSync('bash', ['-c',
      `adb -s ${serial} exec-out screencap -p | ` +
      `ffmpeg -v error -i - -vf ${crop} -f rawvideo - | md5sum | cut -d' ' -f1`],
      { encoding: 'utf8' }).trim();
    const t0 = Date.now();
    let last = grab(), run = 0;
    while (Date.now() - t0 < timeout) {
      await sleep(200 + Math.floor(Math.random() * 400));
      const now = grab();
      run = now === last ? 0 : run + 1;
      last = now;
      if (run >= needed) return true;
    }
    return false;
  };

  /// The mean colour of a region of the screen, as {r,g,b}.
  ///
  /// Scaled to a single pixel by ffmpeg, so this is one average rather than a
  /// hash: it answers "what colour is that part of the screen", where hashing
  /// only answers "did it change". For the identity app that difference is the
  /// whole game -- Flutter exposes no semantics to uiautomator (its node tree
  /// has no text at all) and the app logs nothing, so pixels are the only
  /// channel there is, and a saturated snackbar on a grey screen is the most
  /// separable thing in it.
  const regionRgb = (crop) => {
    const buf = execFileSync('bash', ['-c',
      `adb -s ${serial} exec-out screencap -p | ` +
      `ffmpeg -v error -i - -vf "${crop},scale=1:1" -pix_fmt rgb24 -f rawvideo -`],
      { maxBuffer: 1 << 20 });
    return { r: buf[0], g: buf[1], b: buf[2] };
  };

  /// Wait until a region satisfies a colour test.
  ///
  /// Logs every sample, because a colour threshold that never fires is useless
  /// without knowing what it saw -- and unlike a hash, what it saw is readable.
  const waitForRegionColour = async (crop, test, timeout = 45000, label = '') => {
    const t0 = Date.now();
    let seen = [];
    while (Date.now() - t0 < timeout) {
      const c = regionRgb(crop);
      seen.push(`${c.r},${c.g},${c.b}`);
      if (test(c)) {
        console.log(`  ${label || crop}: matched at rgb(${c.r},${c.g},${c.b})`);
        return true;
      }
      await sleep(250);
    }
    console.error(`  ${label || crop}: never matched. saw ` +
                  seen.slice(-12).map(x => `(${x})`).join(' '));
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
    // Let the encoder catch up before asking it to stop. screenrecord captures
    // ahead of what it has written, and on a loaded emulator it can be seconds
    // behind; signalling immediately loses those frames. The signature-chain
    // take came back four and a half seconds short that way, twice, and the
    // damage only surfaced later as annotate.js reaching past the end.
    //
    // A short settle only. Waiting longer was tried at 2.5s and 6s and changed
    // nothing: under a heavy take screenrecord stops producing at a ceiling of
    // its own -- see the note on that in shoot_crypto.js -- and when it is not
    // under load it does not lose anything worth waiting for.
    await sleep(1500);
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
    E, Eout, sleep, waitForStillScreen, waitForRegionMotion, regionRgb,
    waitForRegionColour, foregroundApp, waitForApp, forwardDevtools,
    stopRecording,
    brightness, waitForBright, waitForDark,
    tap: (x, y) => E('shell', 'input', 'tap', String(Math.round(x)), String(Math.round(y))),
    type: text => E('shell', 'input', 'text', text.replace(/ /g, '%s')),
    /// One character at a time, so it reads as typing rather than a paste.
    /// Put the soft keyboard away, and say whether it was there.
    ///
    /// A tap at a fixed coordinate assumes a layout, and the keyboard changes
    /// the layout: with it up, the identity app's dialog rides higher and the
    /// coordinate meant for PUBLISH lands on the keyboard instead. It hit `j`,
    /// which typed a j into the moniker and never pressed the button, and the
    /// take then waited out its timeout for a result that could not come.
    ///
    /// BACK only when the keyboard is actually shown -- Android sends BACK to
    /// the IME first, but with no keyboard up it goes to the app and closes the
    /// dialog. dumpsys says which, so this never has to guess.
    hideKeyboard: async (timeout = 4000) => {
      const shown = () => /mInputShown=true/.test(
        Eout('shell', 'dumpsys', 'input_method'));
      if (!shown()) return false;
      E('shell', 'input', 'keyevent', '4');
      const t0 = Date.now();
      while (Date.now() - t0 < timeout) {
        await sleep(250);
        if (!shown()) return true;
      }
      throw new Error('the soft keyboard would not go away; a tap meant for a '
        + 'button underneath it would land on a key instead');
    },

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

    /// Close every Chrome tab but one, and say how many went.
    ///
    /// Tabs accumulate across takes and are NOT free: sixty of them starved
    /// screenrecord's encoder badly enough that takes stopped recording at 26.5
    /// seconds, and two days went into looking for the cause somewhere else.
    ///
    /// attachToAvdChrome already does this for takes that drive Chrome. It is
    /// the takes that DON'T that leak: the sync flash is an `am start -a VIEW`
    /// of a data: URL, and Chrome opens a fresh tab for every VIEW intent it
    /// gets. `invite` is a native-app take that never attaches, so every run of
    /// it left another flash tab behind for good. Thirty had piled up.
    ///
    /// Called at the START of a take, not the end: it then also cleans up after
    /// a take that crashed, and it cannot itself be skipped by one that does.
    ///
    /// NOT `pm clear com.android.chrome`, which would take the sign-in state
    /// with it -- the delegate key that vouch, nerdster and crypto_teaser all
    /// run against, and which costs a reshoot of sign-in to get back.
    closeChromeTabs: async () => {
      // Chrome not running yet is a normal state, not a failure -- several
      // takes start on the native app and only reach Chrome later. It is also
      // the only forgiving branch here: anything else that goes wrong throws,
      // because a tab sweep that quietly does nothing is how they piled up.
      const running = execFileSync('adb', ['-s', serial, 'shell', 'pidof',
        'com.android.chrome'], { encoding: 'utf8' }).trim();
      if (!running) return 0;
      execFileSync('adb', ['-s', serial, 'forward', 'tcp:9222',
        'localabstract:chrome_devtools_remote'], { stdio: 'ignore' });
      const get = async path => {
        const r = await fetch(`http://localhost:9222${path}`);
        if (!r.ok) throw new Error(`CDP ${path} -> ${r.status}`);
        return r;
      };
      const tabs = (await (await get('/json/list')).json())
        .filter(t => t.type === 'page');
      // Leave one. Chrome with no tabs at all opens the new-tab page on its
      // next launch, which is one more thing on screen than the take expects.
      const doomed = tabs.slice(1);
      for (const t of doomed) await get(`/json/close/${t.id}`);
      if (doomed.length) console.log(`  closed ${doomed.length} stale Chrome tab(s)`);
      return doomed.length;
    },
  };
}

module.exports = { device, sleep };
