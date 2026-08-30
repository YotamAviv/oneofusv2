# Filming the demo

Two takes so far, both on one Android emulator against production, both driven
by the Flutter accessibility tree rather than by pixel coordinates:

| | |
| --- | --- |
| `./shoot.sh` | [the sign-in sequence](#filming-the-sign-in-sequence) — ~9s |
| `./shoot_nerdster.sh` | [the Nerdster feed basics](#filming-the-nerdster-feed-basics) — ~16s |

They run in that order the first time: the Nerdster take needs the delegate key
that sign-in creates. After that either can be reshot on its own.

`node probe.js` dumps what is on screen — role, position and label of every
node. It is the tool to reach for before changing either script, since it
answers the only question that matters: what is this control actually called?
`--url <u>` navigates first, `--tap <regex>` taps and dumps again, so a menu can
be opened and read without writing anything.

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

## Requires

Node with `playwright` and `firebase-admin` (`npm install`), `adb`, `ffmpeg`, a
running Android emulator with Chrome and a `filmTools` build of the identity app,
and `pm set-app-links-user-selection` approving `one-of-us.net` so the universal
link opens the app.
