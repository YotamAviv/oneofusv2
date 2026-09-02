# Filming the demo

## Start here — setting up a machine

The scripts drive a real Android emulator against production. Six things have to
be true, and two of them are device state that survives nothing: they were both
lost during a rebuild and cost an afternoon before anyone noticed.

**1. Tools.** `adb`, `ffmpeg`, `node`, `python3`, and the Android SDK emulator.

**2. Node packages.** `npm ci` in this directory (`package-lock.json` is pinned).

**3. An emulator, running.** `flutter emulators --launch Pixel_3a_API_35`. Every
coordinate in the app-blind scripts is measured against its 1080x2220 screen, so
a different device profile means remeasuring. Keep an eye on its disk: a fat
debug APK will not install with under a gigabyte free, and the failure is quiet.

**4. A filmTools build of the app, installed.**

    flutter build apk --debug --target-platform android-x64 --dart-define=filmTools=true
    adb install -r ../../build/app/outputs/flutter-apk/app-debug.apk

`--target-platform` matters: the all-ABI debug APK is 127MB and will not fit.
Without `filmTools` the `keymeid://deletekey` and `keymeid://importkey` links are
compiled out, and both `shoot_signin.sh` and `restore_demo_identity.sh` stop working --
silently, because a deep link nothing handles is not an error.

**5. one-of-us.net approved as a link handler.** *Resets on reinstall.*

    adb shell pm set-app-links-user-selection --user 0 \
      --package net.oneofus.app true one-of-us.net

Without it the sign-in take fails at "timeout waiting for net.oneofus.app to
come to the front": the universal link opens the browser instead of the app.
Check it with `adb shell pm get-app-links --user 0 net.oneofus.app` -- you want
`one-of-us.net` under `Selection state: Enabled`. (The `1024` verification state
above it is expected and fine: the AVD build is debug-signed, so automatic
verification cannot pass and this approval stands in for it.)

**6. The app icon on the home screen.** Drag it out of the app drawer once, by
hand. `shoot_home.js` taps a fixed coordinate and does not arrange it.

Then `./restore_demo_identity.sh` to put the demo phone's identity on the device,
and `./build_scene1.sh` to make a scene.


Two takes so far, both on one Android emulator against production, both driven
by the Flutter accessibility tree rather than by pixel coordinates:

| | |
| --- | --- |
| `./shoot_signin.sh` | [the sign-in sequence](#filming-the-sign-in-sequence) — ~9s |
| `./shoot_nerdster.sh` | [the Nerdster feed basics](#filming-the-nerdster-feed-basics) — ~16s |

**Order matters.** `build_scene1.sh` runs `pm clear` to get a phone with no keys
on it, which destroys whatever identity was there. So:

    ./build_scene1.sh              # preamble + vouch -- wipes the app
    ./restore_demo_identity.sh     # put the demo phone's identity back
    ./shoot_signin.sh                     # sign-in, which creates the delegate
    ./shoot_nerdster.sh            # the feed, which needs that delegate
    ./shoot_crypto.sh              # the signature chain

Nothing after the restore is hardcoded: the identity's token is computed from
the key, and the delegate and every statement are made by the app itself,
running against production, the same as a real phone would.

`node probe.js` dumps what is on screen — role, position and label of every
node. It is the tool to reach for before changing either script, since it
answers the only question that matters: what is this control actually called?
`--url <u>` navigates first, `--tap <regex>` taps and dumps again, so a menu can
be opened and read without writing anything.

# Filming the sign-in sequence

Records the ONE-OF-US.NET sign-in end to end — Nerdster home page, launch the web
app, hand off to the identity app, create a delegate key, land back signed in —
as one continuous take on one device, against production.

    ./shoot_signin.sh

Output: `out/signin_<stamp>_taps.mp4`, about nine seconds. That resets all three
pieces of sign-in state, records, and adds the touch indicators.

Run the steps separately if one of them fails:

    adb -s emulator-5554 forward tcp:9222 localabstract:chrome_devtools_remote
    node reset_browser.js
    node shoot_signin.js
    node overlay_taps.js out/signin_<stamp>.mp4

Full detail, including every gotcha with its symptom, is in
[../../doc/video/capture_manual.md](../../doc/video/capture_manual.md).

## Files

| | |
| --- | --- |
| `shoot_signin.sh` | the whole cycle: reset, record, taps, annotate, trim |
| `shoot_signin.js` | drives and records the take; writes `<stamp>.mp4` + `<stamp>.marks.json` |
| `shoot_nerdster.sh` | the same cycle for the feed take |
| `shoot_nerdster.js` | drives and records it, then checks what it published |
| `probe.js` | dumps the accessibility tree of whatever is on screen |
| `reset_browser.js` | clears the app's stored keys so the take starts signed out |
| `truncate_statements.js` | deletes a demo identity's statements past a point (see below) |
| `find_flash.js` | locates the sync flash, giving the offset between script clock and footage |
| `overlay_taps.js` | draws the touch indicators, taps and swipes, and trims the staging head |
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

# Filming the Nerdster feed basics

Filter the feed to books, order it by comments, swipe one card right to snooze
it, swipe the next left to be rid of it, then react to a third — a like and a
comment.

    ./shoot_nerdster.sh

Output: `out/nerdster_<stamp>_taps.mp4`, about sixteen seconds. Set `COMMENT=` to
change what gets typed.

## It publishes, and the reset is nerdster-only

Three statements land under the delegate key on nerdster.org: the snooze, the
dismissal, and the rating. Step 1 of the script deletes them so the next take
starts from the same feed.

That reset touches **nerdster.org only**. The vouch and the delegate statement
on one-of-us.net are left alone, which is the point: reshooting this take costs
one command and does not cost a reshoot of the sign-in take.

The delegate key is minted fresh every time sign-in is reshot, so nothing can
hardcode its token. `truncate_statements.js --delegate-of <identity> --domain
nerdster.org` names it by who delegated it instead, reading the identity's own
published statements. The allowlist still holds — the identity must be in
`demo_identity.json`, and only keys that identity delegated can be reached.

## The take checks what it published

The screen is not the record; the statements are. Every failed take so far
looked right and meant something else: a rating published with no thumbs-up on
it because the sheet was still sliding when the tap went in, a swipe read as a
scroll, a comment typed into nothing. So the take ends by reading its own three
statements back from nerdster.org and fails if any is missing or wrong.

Three things this cost, worth not rediscovering:

- **Type with `Input.insertText`, not key events.** Flutter web owns a hidden
  textarea and takes the value from that; synthesised `keyDown`/`keyUp` never
  reach it, and fail silently — the take runs to the end and publishes a rating
  with no comment.
- **A swipe is not a fling.** The stroke has to cross most of the width and be
  released in motion. Short, or paused before release, and the card springs back
  and nothing is published.
- **"Is that text still on screen" is not "is that card still there."** A title
  also appears inside other cards as a related-subject link, so the first
  version of the swipe check waited for something that never happened. Watch the
  top of the feed instead.

# Prototypes

Rough, and meant to be. They exist to show what the finished thing could look
like, so the ideas can be judged before anything is built properly.

## The signature chain — `./shoot_crypto.sh`

Somebody in the feed who is neither me nor the identity this phone vouched for →
their node in the graph → the delegate key their statements are signed with →
those statements, published on the web, in Chrome with Pretty-print on → their
like → the Nerdster's own Verify dialog → **✔ VERIFIED!**

About 25 seconds, and the script carries it through touch indicators and
annotation to a finished video. It publishes nothing, so there is no reset and
it can be re-run at will. Two things it does that are worth keeping: it pinch-zooms the
statements page, because a page of JSON at phone size is not readable at video
size, and it ends on the verdict with the signer's name interpreted back out of
the key.

## Annotation — `node annotate.js cues/<name>.json out/<take>_taps.mp4`

Both shoot scripts end with this step, so one command gets from nothing to the
finished video. Run it on its own to re-annotate a take that already exists,
which is what a change of copy or styling needs — no reshoot, a couple of
minutes.

Three treatments, from one cue file:

| | |
| --- | --- |
| **prompter** | a band along the bottom that scrolls as the take goes, current line lit, the one before it receding |
| **beats** | the video *stops* — freeze frame, pause bars, everything blurred and dimmed except one spotlit thing, and a bubble with a tail pointing at it |
| **zooms** | a punch-in and back out, for the moments made of small text |

A cue says *when* by naming a moment the take itself recorded — `"at":
"tap_publish"`, `"after": 0.3` — not by a number of seconds. Reshooting is the
normal cost of changing a word of copy and it moves every number in the file;
the names survive it. What a take names is in its `out/<stamp>.marks.json`, and
a cue naming something that isn't there fails with the list of what is. A plain
`"t"` still works where nothing suitable is named.

Coordinates are a different matter. `anchor` and `spotlight` are frame pixels
and they do **not** survive a reshoot that moves the layout — the app is more
stable than the timing, but not perfectly.

A beat that stops the video for three seconds pushes everything after it three
seconds later, and the tool does that arithmetic. `cues/nerdster.json` and
`cues/crypto.json` are worked examples.

Styling lives in two places: bubbles in `STYLES` in `lib/bubble.js`, prompter
font and band height in `stripPage()` and `BAND_H` in `annotate.js`. Only Inter
and Comic Neue are embedded, so a different typeface means adding the file too
(`fontFaces`).

Don't put a zoom over a beat — see the note at the top of `annotate.js`.

## The preamble — three pieces, ~16s

Its own scene, ending on the tap that opens the app. The vouch scene takes over
from there. Short scenes are the point: the vouch take wipes the app's keys to
run, and nothing else here does, so nothing else should have to.

| | | |
| --- | --- | --- |
| `node shoot_browser.js` | the page in a browser, and a tap on the Play badge | ~11s |
| `python3 sections.py --card preamble` | a text card | 2s |
| `node shoot_home.js` | the home screen, and a tap on the app icon | ~4s |

It opens on the page rather than typing an address in, and **the tap on the Play
badge is drawn but never dispatched** — `overlay_taps.js` draws from the marks,
not from the touch, so logging one without sending it puts the finger on the
badge and leaves the browser where it is. The store never opens. That keeps the
take inside the browser, so re-recording it costs no cleanup, and it avoids a
listing that says "Update" under a red internal-tester warning. What would have
happened next is the card's job to say.

The card's words are not in that command: they are in
[video/storyboard.yaml](../../video/storyboard.yaml), section
`preamble`, along with the rest of the video's copy. `sections.py` renders it.
That is the general rule — **what the video says lives in the sections doc**, and
the tools here read it. `sections.py --list` shows every section and its state.

`./build_scene1.sh` runs all of it — the three preamble takes, the vouch take,
the touch indicators, the scan composite, both joins and the assembly — and
writes `out/scene1_full_<stamp>.mp4`. It records every take fresh, so it is also
the check that this repository holds what the video needs. The one thing it
cannot regenerate is `footage/`, which is why that is tracked.

Every trim it makes comes from a take's own marks rather than a number that was
true once: the preamble starts at the browser take's `page`, the home segment at
`home_screen`, and the vouch scene at `welcome`, since the preamble has already
shown the app opening. Each take opens with a sync flash and `overlay_taps.js`
trims to it, but what is left is the flash page still sliding away — those marks
are where the picture becomes worth seeing.

**The app icon is on the home screen** because it was dragged there out of the
app drawer once, by hand (`input motionevent` DOWN / MOVE / UP). It stays put, so
no take has to arrange it.

## The vouch take — `node shoot_vouch.js`

A phone with no keys on it becomes a phone that has vouched for somebody:
CREATE NEW IDENTITY KEY → the congratulations → the scanner → Tom's phone → his
name. Then `composite_scan.sh` drops the real camera footage into the scanner
window; `scanWindow` in the marks file says roughly where it is, and the exact
number is found by eye (see below).

**It wipes the app.** `pm clear` is the only route back to "You have no keys on
this device", and it destroys the identity private key in secure storage — this
image has no root, so there is no backing it up first. Every take mints a NEW
identity, which has vouched for nobody and delegated nothing, so `shoot_signin.sh` and
`shoot_nerdster.sh` need their setup redone afterwards: a vouch for Tom, and
`demo_identity.json` pointed at the new token.

Two things are faked, both in the same place. The emulator's camera renders a
room with a bookshelf in it, so the scanner is held on screen doing nothing and
the footage is composited over that. And the scan is a `keymeid://vouch#` deep
link carrying Tom's public key — the same path a real scan takes once the QR is
decoded, so the dialog is the app's own, with the real key in it. What is faked
is the light hitting the lens, not the crypto.

**A flash is white or black, whichever the take is not.** `find_flash.js` locks
onto the frame furthest from the median, so a white flash is invisible on a take
made of white browser pages — it reported "no clear flash" and every touch
indicator was mistimed. Those takes flash black instead (`--dark`, recorded in
the marks as `syncFlash.kind` and passed through by `overlay_taps.js`). The vouch
take flashes black too, for a different reason: whatever the trim leaves shows
for a beat at the top of the scene, and a white browser page there reads as the
browser coming back rather than as a cut.

The flash works here too. It doesn't have to come from inside the app — it only
has to be a bright frame at a known instant, and it happens before the app is
launched, in the head that gets trimmed off anyway. So the take opens Chrome on
a blank page, zeroes its clock there, and launches the app over the top. That
gives the touch indicators (`overlay_taps.js`) and lets the composite find its
own start:

    node shoot_vouch.js
    node overlay_taps.js out/vouch_<stamp>.mp4
    ./composite_scan.sh out/vouch_<stamp>_taps.mp4 \
        footage/vouch_scan_2026-08-31.mp4 scanWindow out/scene1_vouch.mp4

`scanWindow` there is a mark name, not a number — `composite_scan.sh` resolves
it against the take's marks and shifts it onto the trimmed video's clock.

The clock is zeroed on the white ACTUALLY arriving — `waitForBright` in
`lib/device.js` polls the screen — not on a sleep long enough to assume it has.
Chrome takes its own time to paint, `find_flash.js` locks onto the first bright
frame, and a clock zeroed later than that frame puts every touch indicator early
by the difference. That is what drew the camera-permission tap over a screen
that hadn't got there yet.

It is a *marginal* flash: this app's UI is already light, so a white frame only
beats the median by about 23 luma against the 20 the detector needs. A
full-screen white with no browser chrome would have more room.

The marks are what narration cues hang off, by name (see `annotate.js`):
`welcome`, `tap_create_key`, `congratulations`, `tap_okay`, `main_screen`,
`tap_scan`, `tap_allow_camera`, `scanner`, `scan_hold_done`, `whos_key_is_this`,
`tap_moniker_field`, `typed_moniker`.

The waits, though, are sleeps: there is no accessibility tree, `screencap` is not
byte-stable on this emulator (the same static screen hashes differently every
grab), and the scanner has a live camera preview behind its dialogs, so "the
screen has stopped changing" is never true.

## Real camera footage inside the emulator — `./composite_scan.sh`

The one shot that can't be generated is the demo phone *seeing* another phone:
a camera, a table, somebody's identity on a screen. Everything around it can be.
So the camera picture comes from footage and the rest — status bar, app header,
alignment frame, hint — comes from the emulator, which means the app version,
the screen size and the styling match the takes either side of it.

The footage is salvaged out of the Aug 11 phone recording
(`~/Videos/intro_video_source/`), which has the whole opening in it once: the
Play Store listing at 0:22, CREATE NEW IDENTITY KEY at 0:37, the scan at 0:57,
the moniker at 1:12, "Trusted: Success" at 1:27. `out/salvage/` holds the older Aug 11 cuts; the one in use is `footage/`, tracked
pieces.

The trick is two numbers, where each screen's camera view starts — y=530 in the
old 1080x2400 recording, y=385 on the 1080x2220 emulator. Remeasure both after
a reshoot or after the app's header changes height. The alignment frame and
hint come from the footage rather than the emulator, since they are burned into
the camera region; they line up closely enough that the seam doesn't show, which
is luck and worth re-checking on a frame.

## Assembling a review copy — `./assemble.sh`

Joins the finished takes into one file with a music bed, crossfaded, encoded the
way YouTube wants it (H.264 High, yuv420p, AAC 48k stereo, faststart). With no
arguments it takes `out/music.m4a` and the newest annotated take of each kind.

The takes are 1080x2220 — the emulator's screen, taller than 9:16 — and are kept
that way. Fitting them to 9:16 means scaling down until there are pillars down
both sides, and small text is already this material's main problem.

**The music is the part to think about before anything is published.** Nothing
about the pipeline establishes that a track can be used; that is a question for
whoever uploads, and Content ID answers it in its own way. `out/` is gitignored,
so no audio file lands in the repo.

## What is in the repository, and what is not

Everything needed to build the video is tracked except two things, and both are
deliberate.

| | |
| --- | --- |
| `footage/` | the 2.5s of a real phone scanning a real identity card. Nothing here can regenerate it, so it is tracked. |
| `state/` | the demo phone's vouch for Tom, as published and signed. A record, not an input — nothing reads it. |
| `demo_identity.json` | public tokens — the deletion allowlist |
| `demo_identity_private.json` | the demo phone's key, deliberately (see below) |
| `soundtrack.json` | which track the prototypes used, and where it came from |
| `fonts/` | Inter and Comic Neue, both OFL. Pinned: no card renders without them. |
| `package-lock.json` | pinned, so Playwright doesn't float |

**The private key is here on purpose**, in `demo_identity_private.json`. This
repository is public, so anyone can sign as this identity — which is acceptable
*because nobody vouches for it*. It vouches for Tom; Tom does not vouch back and
neither does anyone else, so an identity nobody trusts has no trust to lend and
a stranger signing with it produces statements from a nobody. If someone writes
to the stream, truncate it back to that first vouch — `shoot_signin.sh` finds it by
fetching, and `state/` records what it should look like.

That reasoning is worth re-checking if it changes. **If a real identity ever
vouches for the demo phone**, the key becomes a way to sign from inside somebody's
network, and it should come out and be replaced.

**What the key is actually for.** Not its state — the vouch take mints a fresh
identity every run and that identity is in exactly the right state anyway (one
vouch for Tom, no delegate). What it lacks is a *name*: `truncate_statements.js`
refuses any token not in `demo_identity.json`, which is the safety mechanism that
stops a wrong token destroying a real person's history. So the reset steps need a
token known in advance, and the stored key is what makes one knowable.

The cost is that each `build_scene1.sh` leaves an orphan identity in production —
one vouch for Tom from a key nobody kept. Harmless, and it accumulates.

Removing that would take a QR decoder (`zbar-tools`): the vouch take could read
the token off the app's own QR, write it into `demo_identity.json`, and become
the demo identity for that build instead of a throwaway — at which point
`restore_demo_identity.sh` is a convenience rather than a required step. The same
decoder is what would let the emulator's camera scan a real QR. Not done.

**The soundtrack is not here**, and is optional. A stock licence covers using a
track in a project, not redistributing the file, and an mp3 in a public
repository is a download link. Drop one in as `soundtrack.mp3` (gitignored) and
`assemble.sh` uses it; leave it out and the video builds silent rather than not
building at all. `soundtrack.json` records which track the prototypes were cut
against.

## Requires

Node with `playwright` and `firebase-admin` (`npm install`), `adb`, `ffmpeg`, a
running Android emulator with Chrome and a `filmTools` build of the identity app,
and `pm set-app-links-user-selection` approving `one-of-us.net` so the universal
link opens the app.
