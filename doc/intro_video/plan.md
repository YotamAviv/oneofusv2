# Intro Video — Approach and Notes

Notes for making intro/demo videos covering ONE-0F-US.NET, Nerdster, and Hablotengo.

*** MY HUMAN UPDATES ***

Tech:
We're still at the prototype stage. Before first commit:
- Address: "Every tap is a hardcoded pixel, every wait a tuned sleep, and a failed take still produces a valid-looking file. Flutter's accessibility tree in the filming build would fix all three at once."
- Add a bubble
- I, the person, need to understand the code and where/what the script is.

Less is more:
keep it brief and polished

The self filmed videos were simple enough to set up but hard on my to execute and lacked the ability to show bullets and text on the recorded phone screen. Make it polished, computer scripted and generated instead and use these:
- bubbles
- overlays (for example for delegates, scroll through Reddit, NYT comments, Uber, Lift, Twitters, etc...)
- running commentary, similar to my script in the teleprompters (eliminate those eventually)
- Buzz ? slogans
These can flash in a special font and then fade away. They're different from the running commentary: Democracy 2.0, First Amendment 2.0, The Internet liberated lies and pornography; cryptography on the Internet can liberate authenticity, trust, maybe decency.

Sections:
Each section opens with text, then uses demo

- Our. Own. Decentralized. Identity. Network. (Each word appears with slight pause)
  - Demonstrate vouching in action.
  - That's it! That's all we need to do to build our own, decentralized, identity network.
This sequence needs a shot from me using a 3rd phone showing the demo phone scanning the phone with my identity (demo phone screen not legible).

- Do we really need another one of these?
  - No. This one's different
    - a prototype leveraging our own network
  - Enter the Nerdster! (Gong sound like Enter the Dragon)
  - Show nerdster features briefly including changing PoV. Unlike the demo that was wider than a phone, try and sweep side 2 side between the 2 views, then maybe even show Lisa, Bart, Milhouse using both permissive and standard settings (defer that for now)

- Open
  - any service can leverage and contribute to our own, decentralized...
  - evolution (like the Web. Services compete using data that's signed, trusted, and available, not siloed in a monopoly)
  - Look for more text from other assets (ie. the Internet isn't Google's...)

- (optional) Crypto signatures work
  - demonstrate that a statement fetched from the web is signed correctly by using the Nerdster's built in Verify Signature dialog

- HabloTengo, Let's talk
  Private information sharing grounded by our public open network.
  Enough to demo that the demo phone we're using can't access folks' contact info

- People, Not accounts
  I don't have a Nerdster account or a ONE-OF-US.NET account.
  - I gave the Nerdster a delegate key to use which I claimed is mine (the Nerdster has an account with me)
  - Other people vouched for my identity (If anything, I have an account with them.)
  - Our network already exists
    - this effort is just so we can use it online
    - let's get on the same page, whether you drive Uber, comment on news, like movies or products, you're human, a person, ONE OF US.
  - (Maybe: That man is tall, has a rude dog, fancy car, I always seem him at the park. That woman works at the coffee shop, has 3 kiddos. Online we're just accounts. Same page...)

Demo shows that these signed statements are available, PORTABLE, auditable, trusted..

- Opt-in
  - just because you can use your authentic voice doesn't mean you have to.

  

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

### Scripted capture — [tools/intro_video/](../../tools/intro_video/)

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
and every finished file is in `tools/intro_video/out/` (gitignored, stamped, and
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

### TODO — app changes, deferred

Both need a build pushed to a real phone, so they wait. Then re-shoot the vouch
scene and the footage that goes in it.

1. **Pause on capture.** The scanner switches to *Who's Key is This?* the instant
   it decodes, so the moment of recognition is invisible. Freeze the decoded
   frame for about a second first — a shutter feel — then show the dialog. Good
   feedback in its own right, and it would replace the freeze-frame hack
   `composite_scan.sh` uses to hold the phone in view until the app reacts.

2. **"Trusted: Success" fires too early.** The snackbar appears while the spinner
   is still spinning and *Who's Key is This?* is still up. Confirmed in the raw
   take, so it is the app and not the video. Left in the footage on purpose
   rather than edited around — fix the app, then re-shoot.

Possibly related, worth a look while in there: a `keymeid://vouch#` deep link
arriving while the scanner is open leaves the scanner underneath, where a real
scan pops it. The shoot script presses Back first to match real behaviour.

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
