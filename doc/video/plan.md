# Intro Video — Approach and Notes

Notes for making intro/demo videos covering ONE-0F-US.NET, Nerdster, and Hablotengo.

*** MY HUMAN UPDATES ***

TODO:
- Crypto works can reference the box on the one-of-us.net home page
- Not my network, not the ONE-OF-US.NET network can reference the Simpsons Bot Farm where Marge and Luanne (Millhouse's mom) use a different host for their identity statements.

Less is more:
keep it brief and polished

The self filmed videos were simple enough to set up but hard on my to execute and lacked the ability to show bullets and text on the recorded phone screen. Make it polished, computer scripted and generated instead and use these:
- bubbles
- overlays (for example for delegates, scroll through Reddit, NYT comments, Uber, Lift, Twitters, etc...)
- running commentary, similar to my script in the teleprompters (eliminate those eventually)
- Buzz ? slogans
These can flash in a special font and then fade away. They're different from the running commentary: Democracy 2.0, First Amendment 2.0, The Internet liberated lies and pornography; cryptography on the Internet can liberate authenticity, trust, maybe decency.

The prototypes worked.
Next is
- scripts and text we'll keep and iterate on.
  - enables me to think of an improvement either to the app, the fonts, the text, whatever and not shoot the whole thing from scratch.
- the option to support shorter and longer videos with components that are good.

Tactics:
- Entire screen text
- Bubbles that point to buttons
- Pause the video (show "||" and show important text regarding what happened)
- Flash buzzwords (eg. "Democracy 2.0", "All your likes are belong to us"). These should be shiny, pop-up brightly, and then fade.

Sections (probably a script and filename for each; all files will be assembled for the final, published video intro):

- Our. Own. Decentralized. Identity. Network. (Each word appears with slight pause)
  - Demonstrate vouching in action.
  - That's it! That's all we need to do to build our own, decentralized, identity network.
This sequence needs a shot from me using a 3rd phone showing the demo phone scanning the phone with my identity (demo phone screen not legible).

- You have to be trusted, too (this demo user will not be trusted)
  - In case you're remote, share a link which includes your public identity key.
  - Demo that but don't actually email it or text it.

- Enter the Nerdster! (Gong sound like Enter the Dragon)
  - Show nerdster features briefly including
  - Defer:
    - PoV switch, Unlike the demo that was wider than a phone, try and sweep side 2 side between the 2 views, then maybe even show Lisa, Bart, Milhouse using both permissive and standard settings (defer that for now)
    - follow/block Nerdster context
    - block Identity (reprehensible)

- Do we really need another one of these?
  - No. But this is different
    - a proof of concept of the paradigm leveraging our own, open, decentralized identity network.
  - Open
    - any service can leverage and contribute to our own, decentralized...

- How? Turn on the crypto (The Nerdster is specifically designed to highlight how this paradigm works)
  - Turn on Crypto
  - Show the interpreted and un-interpreted view of a like (not the demo's).
  - Navigate to that person's NodeDetails, show the delegate keys, follow a delegate key's published signed statements, pretty print, 
    - Try: Copy paste a statement and validate. Modify it (change a comment) and see that it doesn't
    - Announce: This is is how all 3 apps work. They're not connected.
      - Ground a service to a trusted point of view (like your own)
      - Collect published, signed content (from anywhere; the statements are signed and portable)
      - Verify the signatures
      - Aggregate and present
  Announce So:
    - Evolution enabled (like the Web. Services compete using data that's signed, trusted, and available, not siloed in a monopoly)
    - TODO: Look for more text from other assets (ie. the Internet isn't Google's...)

- HabloTengo, Let's talk
  - Navigate to Hillel's NodeDetails
  - Expand Hillel's delegate keys
  - Note that he has a hablotengo.com delegate key
  - Use the "Handy Dandy" link to his privately published contact info.
  - See "Access Denied"
  Announce: Private information sharing grounded by our own open decentralized network.

- People, Not accounts
  I don't have a Nerdster account or a ONE-OF-US.NET account.
  - I gave the Nerdster a delegate key to use which I claimed is mine (the Nerdster has an account with me)
  - Other people vouched for my identity (If anything, I have an account with them.)
  - Our network already exists
    - this effort is just so we can use it online
    - let's get on the same page, whether you drive Uber, comment on news, like movies or products, you're human, a person, ONE OF US.

- Let's get on the same page
  - We build the identity network and **let** them use it.
  - (We can't let them build it. One silo (eg. Twitter) will never agree to relying on another's (eg Facebook) identities.)

- The Internet liberated lies and pornography, and we got confused, depressed, divided, and angry.
- Crypto on the Internet can liberate authenticiy and trust, maybe sanity, truth, and decency...
- Decentralized
  Must be if it's yours and you don't own your own silo
  Flash: "Democracy 2.0"
- Opt-in
  - just because you can use your authentic voice doesn't mean you have to.
  Flash: "First Amendment 2.0"
  

## The core problem

Filming narration live over live phone capture means doing three hard things at once:
performing the app, narrating, and hoping the take is clean. Any one flub kills all three.

Separate the axes:

1. **Capture silent.** Screen-record the phone doing the thing, no talking. Re-take freely —
   it's cheap when there's no narration riding on it.
2. **Narrate separately**, against the cut footage. Or use captions instead of talking.
3. **Fix pacing in post.** Typing, QR scans, and network waits get sped up 4–8×; the moment
   of payoff gets slowed and zoomed.

This also fixes the thing that makes live takes feel bad: real app latency is boring, but
you can't pause mid-sentence to wait for it.

## Tooling available on this machine

- `ffmpeg` / `ffprobe` 6.1.1 (`/usr/bin`)
- Shotcut (`/snap/bin/shotcut`) for GUI work
- Playwright + Chromium, for scripted web-app capture — see below
- `adb` and six Android AVDs (the `emulator` binary is not on PATH; SDK location
  not yet found)

Claude can drive ffmpeg directly, and can extract frames and view them to check
framing/timing rather than editing blind.

### Scripted capture — [tools/video/](../../tools/video/)

**The web apps don't need a phone or an emulator.** Nerdster and HabloTengo run
in Chromium at a phone-sized viewport, driven by a script, recorded at
1080×1920. Re-runnable: change a line, re-run, get a new take. Working today for
Nerdster; the same approach should carry to HabloTengo.

This changes the shoot plan. Acts 2, 3, and 4 are web-app footage, so they can
be generated rather than filmed — which also **solves Act 3's legibility
problem** (font size and DPI are set at capture time, no post-zoom into mush).
What still needs a real camera is the physical, outside-the-phone material: shot
1a, and the identity app itself.

Capabilities proven on the Nerdster:

- **PoV from the URL** — `nerdster.org/app?pov=<public key JSON>`, the mechanism
  behind nerdster.org's own "Milhouse's view" button. No sign-in, no private key.
- **Real touch input** via CDP, so Flutter applies its own fling physics; the
  scroll accelerates and settles like a phone rather than a mouse wheel.
- **Visible finger touches** — an injected overlay draws the contact blob and a
  release ripple, driven by the page's real touch events.
- **Burned ASS captions** in two registers (neutral narrator slab, Comic Neue
  in-character bubble using the same face as the site's comic bands).

Gotchas that cost takes are written up in the tool's README — read it before
changing the recorder.

### What Claude can't do here

No speech synthesis in this environment — voice-over has to be recorded by you.
(And a Milhouse *voice* is off the table regardless: that's Fox's character and
Pamela Hayden's performance. Text bubbles in his register are fine.)

### What ffmpeg covers

- **Speech bubbles / callouts** — author an ASS subtitle file and burn it in. Timed,
  positioned, styled with rounded backgrounds, fade in/out. Editing a caption later is a
  text edit, not a re-render decision.
- **Zoom punch-ins** on taps (`zoompan`), so a thumb press on a 6" screen reads on a laptop.
- **Side-by-side phones** — `hstack` with a divider and per-side labels. This is the key
  shot for both the Hablo privacy point and the PoV point: two captures on one timeline, so
  the viewer *sees* that Hillel's contact info is present on one side and absent on the other.
- **Speed ramps, trims, stitching, crossfades, end card.**

## Structural suggestions

- **Three short videos, not one.** Vouching (~45s), Nerdster PoV (~60s), Hablo privacy
  (~45s). One idea each, linkable individually. A single 3-minute video that has to land all
  three is why this keeps failing.
- **Lead with the payoff.** Open the PoV clip on the network *changing*, then back up and
  show how. Nobody watches 40s of setup to find out why they should care.
- **Make the demo state deterministic.** See [simpsons_demo_setup.md](../../../hablotengo/doc/simpsons_demo_setup.md).
  If a reset script gets to an identical start state every time, re-shooting a single clip
  stops being a whole-afternoon thing. Highest-leverage prep item.
- **The PoV change is the hardest to convey.** Consider a static before/after split of the
  same graph rather than a live toggle — the animation is over before a first-time viewer
  understands what changed.

## The three clips

| Clip | Point to land |
| --- | --- |
| Vouching | Vouch for each other to build the network |
| Nerdster PoV | Use that network; it's decentralized (change PoV, results change) |
| Hablo privacy | Hillel's contact info is not visible from the demo phone's PoV |

## Script

See [script.md](script.md) — acts, shot list, bubbles, VO, timings.

## Assets and current state

Enough here to resume cold in a new session.

**Source footage.** The Aug 11 take lives on the phone, not on disk:
`/sdcard/Movies/screen-20260811-131222-1786478483523.mp4` — 11 min, 1080×2400 @ 60fps,
mono audio, 658 MB. Pull with `adb pull <path> raw.mp4` (~17s over USB). Findings from it
are recorded in [script.md](script.md); the two that matter most are
the clipped audio and the private keys visible on the IMPORT/EXPORT screen at 10:15.

**Cut demos** in `~/Videos/intro_video_demos/`:

| File | What it is |
| --- | --- |
| `demo1_pov_bubbles.mp4` | 26s from 6:16, zoom punch-in + burned ASS captions |
| `demo2_split_pov.mp4` | 6s side-by-side, same post under two PoVs — **usable in the real cut** |
| `demo3_speedramp.mp4` | 45s of vouching at 5× |
| `pov.ass` | Caption source for demo1 — edit the text, re-burn |
| `sheet.png` | 30-frame contact sheet of the whole take |

**Working command shapes** (verified on this footage):

```bash
# Contact sheet, to find what's where
ffmpeg -i raw.mp4 -vf "fps=1/22,scale=200:-1,tile=10x3" -frames:v 1 sheet.png

# Burn captions + zoom punch-in
ffmpeg -ss 376 -t 26 -i raw.mp4 -an -vf \
  "fps=30,scale=540:1200,zoompan=z='if(lt(on,90),1,if(lt(on,150),1+0.6*(on-90)/60,1.6))':\
   x='(iw-iw/zoom)/2':y='(ih-ih/zoom)*0.10':d=1:s=540x1200:fps=30,subtitles=pov.ass" \
  -c:v libx264 -crf 22 -pix_fmt yuv420p out.mp4

# Side-by-side, two moments from one capture
ffmpeg -ss 378.5 -t 6 -i raw.mp4 -ss 392 -t 6 -i raw.mp4 -an -filter_complex \
  "[0:v]fps=30,scale=440:-1,pad=iw+8:ih:0:0:0x111111[a];[1:v]fps=30,scale=440:-1[b];[a][b]hstack=inputs=2" \
  -c:v libx264 -crf 22 -pix_fmt yuv420p out.mp4
```

## Where things stand — 30 Aug 2026

Picking up from here: everything below is committed on `intro-video-tooling`,
and every finished file is in `tools/video/out/` (gitignored, stamped, and
nothing is overwritten).

**Three scenes shoot end to end, from one command each.**

| | | |
| --- | --- | --- |
| sign-in | `./shoot.sh` | ~9s |
| Nerdster feed basics | `./shoot_nerdster.sh` | ~16s |
| signature chain | `./shoot_crypto.sh` | ~25s |
| opening vouch | `node shoot_vouch.js` + 2 steps | ~37s |

The vouch scene is three commands rather than one, because the composite step
needs a take to exist first:

    node shoot_vouch.js
    node overlay_taps.js out/vouch_<stamp>.mp4
    ./composite_scan.sh out/vouch_<stamp>_taps.mp4 \
        out/salvage/vouch_scan_long.mp4 scanWindow out/scene1_vouch_<stamp>.mp4

Latest: `out/scene1_vouch_20260830-215144.mp4`.

**Post-production works**: `annotate.js` does the scrolling prompter, the
pause-and-spotlight beats with pointing bubbles, and zoom punch-ins, all from a
cue file whose times name moments the take recorded (`"at": "tap_publish"`), so
they survive a reshoot. `assemble.sh` joins scenes with a music bed and encodes
for YouTube. The two-scene review cut is `out/upload.mp4`.

**The demo phone's identity is fresh.** `shoot_vouch.js` runs `pm clear`, which
destroys the old identity private key — that was the one `demo_identity.json`
names, so **`shoot.sh` and `shoot_nerdster.sh` will not work until** the new
identity vouches for Tom and `demo_identity.json` is pointed at its token. The
vouch scene itself publishes that vouch, so the material for it exists; the token
just needs reading back and writing down.

### App changes — both done, 31 Aug, on `main`

Commit `4ffe97b`, merged here.

1. **Pause on capture.** The scanner marks the capture, holds 850ms and then
   leaves: the frame flashes bright and the reticle turns green and closes on
   what it found. **Not exercised yet** — the emulator's camera renders a room
   with no QR in it, so nothing can be decoded there. Wants a look on a real
   phone, and the 850ms is a guess worth tuning by eye.

2. **"Trusted: Success" fired too early.** Both dialogs await their `onSubmit`
   and only close once it returns, so a snackbar raised inside the push landed
   underneath the dialog reporting on it. The push now reloads first and takes an
   `announce` flag; each dialog says so itself once closed. Verified on the
   emulator: spinner with no snackbar, then the dialog closes, then the
   confirmation.

The write was never optimistic — this app doesn't pass the
`optimisticConcurrencyFailed` callback that gates that path in
`DirectFirestoreWriter`, so success has always meant committed. The fix was about
what the screen said, not what was true.

**Re-shoot the vouch scene** once the capture pause has been eyeballed; the
footage composited into it may want re-cutting to match the new timing.

**The emulator now runs a `main` build**, which has no `Config.filmTools`, so
`keymeid://deletekey` is gone and `shoot.sh` cannot reset the delegate key until
a branch build is installed again:

    flutter build apk --debug --target-platform android-x64
    adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk

(`/data` on that AVD runs ~90% full; the all-ABI debug APK is 127MB and will not
fit, hence `--target-platform`.)

### In flight — 1 Sep 2026, mid-change

**Goal: the V1 Intro.** No statement verification in it -- that moves to a later
"How it works" video. The Nerdster is where the effort goes; the identity phone
app gets simple takes or hand-tweaked scripts.

**Decisions just made, not all implemented yet:**

- **Cards use the same timing vocabulary as everything else** -- `at: <mark>`,
  `after:`, `hold:` -- so a card can land anywhere in a section, not only at its
  ends. "At the start" is `t: 0`; "at the end" is a late mark.
- **A card at a mark is the same mechanism as a beat.** annotate.js already
  freezes the timeline at a mark, splices a still in for `hold` seconds, and
  shifts every later cue. A card is that splice with a rendered card instead of
  a dimmed frame. `lib/card.js` was extracted so card.js and annotate.js render
  identical cards.
- **Flash is the other kind** -- drawn OVER the running video, bright then faded,
  not stopping it. Also wanted at any mark. NOT BUILT.
- **HabloTengo section**: Hillel's NodeDetails, Handy Dandy link, Access Denied,
  back to the Nerdster.
- **The crypto material splits in two**: up to Hillel's NodeDetails and the
  delegate keys for the Intro; published statements and verification for "How it
  works".

**The vouch section is the one in progress.** Its build path never annotates, so
its four prompter lines have never reached the screen. The fix is an annotate
step, and the order matters:

    shoot_vouch -> overlay_taps -> annotate(cues/vouch.json) -> composite_scan -> trim

annotate must run BEFORE the composite, because it finds a take's marks by
filename convention (stripping `_taps` / `_annotated`) and the composite's output
is named differently.

**A trap to fix properly later:** annotate splices pauses, which shift the
timeline; composite_scan then resolves `scanWindow` against the UNSHIFTED marks.
Vouch's cues are prompter-only today so nothing shifts. The day a beat or card
lands before the scan window, the composite goes to the wrong place, silently.

**Uncommitted at this point:** `find_flash.js` (variable-rate fix -- screenrecord
emits few frames for a still screen, so a frame-count median is weighted by
motion; now samples at fps=10), `build_preamble.sh` (new, extracted from
build_scene1.sh), `lib/card.js` (new, extracted), `sections.yaml` (preamble
section added), `sections.py` (--card), `build_scene1.sh`, `README.md`.

### Worth doing, not done

**A QR decoder (`zbar-tools`) would remove the demo-identity dance.** The vouch
take mints a fresh identity every run, which is in the right state but has a
token nothing can name — and `truncate_statements.js` refuses tokens that aren't
in its allowlist. Hence the stored key, and hence `restore_demo_identity.sh`
after every `build_scene1.sh`. With a decoder the take could read the token off
the app's own QR, write it down, and use it; the restore becomes optional and
production stops collecting orphan identities. The same decoder would let the
emulator's camera scan a real QR, which is the other half of the filming rig
nobody has built.

### Notes for whoever picks this up

- **The rendered room is the tell.** The emulator's camera shows a living room
  with a bookshelf and a cat. Any frame where the scanner is visible and the
  composite isn't covering it gives the whole thing away, which is why the
  composite is padded at both ends and why the script leaves the scanner before
  the dialog. Check the edges of the scan window on every reshoot.
- **Feeding the footage to the emulator's camera** (`v4l2loopback` + `-camera-back
  webcam0`) would remove that class of problem entirely — the app would really
  scan it. Deliberately not pursued; it needs one `sudo modprobe`.
- Coordinates in `shoot_vouch.js` are measured off screenshots and a layout
  change moves them silently. The take will look fine and do nothing.

## Next steps

- **Decide the caption register** — narrator-only vs. narrator + Milhouse. The
  sample cut has both; the question is whether in-character comedy fits next to
  Act 5's closing line, or belongs in the shorts series instead.
- **Rework Act 2d** around what the footage actually shows (the bot farm gets
  filtered, the clown movies stay) rather than "the clown movies vanish".
- Script the remaining web-app shots the same way: Act 2c PoV switch, Act 3
  Chrome/Pretty-print, Act 4 Hablo denial and allowed view.
- Find the Android SDK / get `emulator` on PATH, then test whether the identity
  app runs on an AVD — that decides whether Act 1 is emulator or real phone.
- Shoot 1a (three phones, physical) — the one shot nothing else can replace.
- Reset-to-demo-state script for repeatable takes
- Rotate the demo phone's keys before publishing anything from the Aug 11 take
- Decide Act 4c (Access-Denied-only vs. Simpsons allowed view)
- Cut: trim, speed-ramp, side-by-side, burned-in bubbles, VO mix
