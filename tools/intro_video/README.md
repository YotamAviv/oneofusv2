# Filming the sign-in sequence

Records the ONE-OF-US.NET sign-in end to end — Nerdster home page, launch the web
app, hand off to the identity app, create a delegate key, land back signed in —
as one continuous take on one device, against production.

    ./shoot.sh

Output: `out/signin_<stamp>_taps.mp4`, about nine seconds. That resets all three
pieces of sign-in state, records, and adds the touch indicators.

Run the steps separately if one of them fails:

    adb -s emulator-5554 forward tcp:9222 localabstract:chrome_devtools_remote
    node reset_browser.js
    node shoot_signin.js
    node overlay_taps.js out/signin_<stamp>.mp4

Full detail, including every gotcha with its symptom, is in
[../../doc/intro_video/capture_manual.md](../../doc/intro_video/capture_manual.md).

## Files

| | |
| --- | --- |
| `shoot.sh` | the whole cycle: reset, record, add taps |
| `shoot_signin.js` | drives and records the take; writes `<stamp>.mp4` + `<stamp>.marks.json` |
| `reset_browser.js` | clears the app's stored keys so the take starts signed out |
| `truncate_statements.js` | deletes a demo identity's statements past a point (see below) |
| `find_flash.js` | locates the sync flash, giving the offset between script clock and footage |
| `overlay_taps.js` | draws the touch indicators and trims the staging head |
| `tapframes.js` | regenerates `tapfx/`, the touch-indicator frames |
| `lib/semantics.js` | tap by name, wait on state, assert — via Flutter's accessibility tree |
| `demo_identity.json` | the ONLY keys truncation may touch |

## Why it can see what it's doing

Flutter draws to a canvas, so there is nothing to query: taps become hardcoded
pixels, waits become tuned sleeps, and a take that hits the wrong dialog still
records a perfectly valid file of the wrong thing. All three happened.

Flutter also keeps an accessibility tree. `lib/semantics.js` switches it on and
uses it, so the script taps *"https://one-of-us.net/…"* rather than a coordinate,
waits until a dialog exists rather than sleeping, and asserts the expected screen
before continuing. A bad take now stops with a message naming what was actually
on screen.

## Never add a sleep to "let it settle"

A six-second sleep after the launch tap was most of a thirty-second take, and it
sat immediately before a `waitFor` that already did the job. If something needs
waiting on, wait on the condition.

## Resetting between takes

The take needs the phone *vouched, no delegate yet*, or the app offers to rotate
an existing delegate instead of creating one. Three places hold that state:

| State | Where | Reset |
| --- | --- | --- |
| delegate statement | published, one-of-us.net | `node truncate_statements.js --token <t> --project oneofus --prod --keep <first>` with `I_MEAN_IT=yes` |
| delegate key | identity app secure storage | `adb shell am start -a android.intent.action.VIEW -d "keymeid://deletekey?domain=nerdster.org"` |
| identity + delegate in the browser | page storage, because "Store keys" is ticked | `node reset_browser.js` |

The third is the one that silently ruins takes: the app never prompts because the
browser is already signed in. Doing it through the UI takes two steps whose
positions move between them, which is why `reset_browser.js` clears
`FlutterSecureStorage*` from localStorage instead and then verifies.

Truncation refuses any key not in `demo_identity.json`, and `--prod` additionally
requires `I_MEAN_IT=yes`. Everything else in those stores belongs to a real
person and deletion cannot be undone.

## Requires

Node with `playwright` and `firebase-admin` (`npm install`), `adb`, `ffmpeg`, a
running Android emulator with Chrome and a `filmTools` build of the identity app,
and `pm set-app-links-user-selection` approving `one-of-us.net` so the universal
link opens the app.
