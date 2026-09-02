# Intro Video — Shooting Script

Companion to [plan.md](plan.md) (approach, tooling, editing capabilities).

**Target:** ~2:55, portrait 1080×1920, viewable on a phone. Acts 1–4 also export as
standalone 40–50s clips from the same timeline. Act timings below are indicative — they get
locked in the edit, once there's real footage to measure.

**If the tech talk is dropped, don't let this absorb it.** The better fit for the material
is a series of ~60s portrait shorts, one mechanism each — trust modes, delegates, PoV,
equivalence — sharing this video's grammar and tooling. This stays the hook.

**Relationship to [phone_talk.html](../../web/phone_talk.html):** that's the long
talk — it teaches. This video's job is to make someone want the talk. Show, don't explain.

---

## ⚠️ Never film / never cut in

- **IMPORT / EXPORT screen.** It renders the key JSON including `"d"` — the Ed25519 private
  scalar — for every key on the device. The Aug 11 take has this at 10:15 for both
  `one-of-us.net` and `hablotengo.com`. A single freeze-frame hands over the identity.
  Those keys should be rotated before anything from that take ships.
- **Any real person's contact info** in HabloTengo. Use Simpsons demo identities.
- **The share sheet's recipient list** when demoing remote invitations.

## Rules for this shoot

- **Capture silent.** No narration while performing the app. Re-take freely.
- **Record voice separately.** The Aug 11 take clipped (peaks at 0.0 dB, 616 clipped
  samples, constant room noise); a separate VO pass fixes it.
- **30fps, portrait.** 60fps buys nothing on screen content.
- **Zoom at capture time, not in post.** Any shot where JSON must be readable: raise Chrome's
  font size, or pinch-zoom, *before* recording, so the text is already large in the source
  pixels. Post-zoom into a small text region on a 1080-wide capture turns to mush. My zoom
  punch-ins should be emphasis, not rescue.
- **Deterministic start state** before each take. See [simpsons_demo_setup.md](../../../hablotengo/doc/simpsons_demo_setup.md).
- **VO budget: ~280 words total.** Bubbles carry the assertions; the voice carries only
  what a bubble can't.

---

## ACT 0 — Hook (0:00–0:14)

Text cards over black or a slow product shot. No app footage yet.

| Card | Text |
| --- | --- |
| 1 | When you like a post, that's your **account** doing it. |
| 2 | It only counts on Facebook. |
| 3 | When you rate an Airbnb host, you're not saying something about a person. |
| 4 | Your account is rating their account. |

**VO:** "Everything you've ever vouched for online, you said as an account — and it only
means anything on the service that owns it. What if you could say something about a person,
and have it mean the same thing everywhere?"

---

## ACT 1 — Build the network, and watch the statement get made (0:14–1:04)

| # | Shot | Capture |
| --- | --- | --- |
| 1a | Establishing: one phone scanning another's QR, filmed from outside | Third phone on tripod — see below |
| 1b | **Turn FYI on** (ADVANCED screen — careful, EXPORT is on that screen too) | Screen recording |
| 1c | Scan → "Who's Key is This?" → moniker "Tom" → Publish | Screen recording |
| 1d | **FYI shows the statement being signed and published, as it happens** | Screen recording, zoom punch-in |
| 1e | Interpreted view → toggle → raw view (`{}` icon) | Screen recording, zoom punch-in |
| 1f | Share sheet — send an invitation by text or email | Screen recording |

**Bubbles:** "Scan a phone. That's it." → "This is the statement, as it's signed." → "What
it means." → "What it actually is." → "Published where anyone can find it." → "Not in the
same room? Send an invitation."

**VO:** "I scan Tom's phone and vouch for him — human, capable, acting in good faith. Watch
what that actually produces. Here's what it means: I trust this key, I call him Tom, and
here's where his statements live. And here's what it really is — signed with my private key.
It isn't trusted because of who served it. It's trusted because of who signed it."

> **This is the spine of the video.** Its power is causal and live: the viewer watches the
> vouch happen, then watches the artifact come into existence, then sees what it means, then
> sees the crypto underneath. Nothing has to be taken on faith.
>
> **Order matters: interpreted first, raw second.** Interpreted is comprehensible, raw is
> proof. Leading with raw loses everyone who isn't already a nerd.
>
> **1d and 1e are unshot.** FYI never gets turned on in the Aug 11 take — the toggle appears
> once at 10:25, unchecked, and no statement JSON is displayed anywhere in the 11 minutes.

---

## ACT 2 — Nerdster: public as the moon (1:04–1:50)

| # | Shot | Capture |
| --- | --- | --- |
| 2a | Sign in at nerdster.org/app via identity app; create delegate key | Screen recording |
| 2b | Browse feed — Tom appears; open content by Hillel | Screen recording |
| 2c | **PoV switch**: dropdown → different identity → feed changes | Screen recording; cut as split-screen |
| 2d | **Trust modes**: PoV Milhouse, `permissive` → `strict`. His own name goes from "4-Eyes" back to "Milhouse" | Screen recording ×2, cut as split-screen |

**Bubbles:** "No account. No password." → "Your account is with everyone who vouched for
you." → "Nerdster never gets my identity key." → "I know that's Tom. I scanned his phone."
→ "I know that's Hillel. Tom vouched for him." → "Same post. Different network. Different
replies." → "Trust from your point of view." → "Anyone can mint a thousand keys." →
"So who gets believed?"

**VO:** "I don't have an account here. I told Nerdster who I am, and it went and verified
the statements itself. It holds a delegate key — never my identity key. And when I look
through someone else's point of view, the network is theirs, not mine. You are who my
network says you are. I am who your network says I am. — But vouches alone are gameable.
Anyone can mint a thousand keys and have them all vouch for each other. Working out who's
really who from a pile of untrustworthy vouches is a genuinely hard problem. So past a hop
or two, Nerdster wants more than one independent path to you before it believes a name.
Watch what that costs the bot farm."

> 2c already has usable footage: Aug 11 at 6:20–6:40, cut as
> `~/Videos/intro_video_demos/demo2_split_pov.mp4`.
>
> **2d — show the consequence, say the mechanism.** The graph view is the explanation, but
> nine nodes with crossing edges is a hairball at portrait phone size and it asks the viewer
> to know what a "path" is. The demo data has a better shot: per
> [simpsons_demo.dart](../../../nerdster/lib/demotest/cases/simpsons_demo.dart), Sideshow
> trusts Milhouse with the moniker "4-Eyes", so from Milhouse's own PoV under `permissive`
> he is labelled **4-Eyes**. Tighten to `strict` and he's **Milhouse** again. One word moving
> — legible at any size, no graph literacy needed, and it's personal: a bad actor renamed
> *you*, and one setting undid it.
>
> Runner-up shot, same idea at feed scale: the clown movies' bogus likers (Seymore Butts,
> Amanda Hugginkiss) vanish between modes. Use whichever reads better once shot.
>
> **2d is now shot** — `tools/video`, scene `identity-bar`, PROD data. Both beats land
> in one take, and the footage corrected an assumption: the clown movies do **not** vanish
> under `strict`/`standard`. They stay; their *likers* change from Seymore Butts and Amanda
> Hugginkiss to Mel@nerdster.org. That's a better argument than disappearance — the mechanism
> is visibly discriminating between who vouched, not deleting content — but the bubble copy
> above needs rewriting to match. Also confirmed in the same take: Little Women moves 2→3
> likes and its tags change, so the change isn't only a name in the corner.
>
> Modes are `permissive` / `standard` / `strict` ([feed_menu.dart:120](../../../nerdster/lib/ui/feed_menu.dart#L120));
> the setting is `identityPathsReq`, default `permissive`.
>
> **Don't put a hop/path number in a bubble** until the threshold is confirmed — the
> `pathsReq` map isn't in the Flutter source, so the numbers may be server-side.
>
> **Replaces the block-Eyal beat.** Both say "bad actors leave your network", but manual
> versus automatic; the automatic one is more surprising and skips the "Blocking is Harsh!"
> detour. Restore Eyal only if 2d doesn't shoot well.

---

## ACT 3 — No back doors (1:50–2:14)

All real artifacts, in Chrome on the phone. Brief — this is a proof, not a lesson.

| # | Shot | Capture |
| --- | --- | --- |
| 3a | In Nerdster, a statement's **"Signed, Published Statements"** link | Screen recording |
| 3b | It opens Chrome on `export.<somewhere>` — **tick Pretty-print** | Screen recording |
| 3c | Zoom: the URL bar. Then the delegate key in the JSON | Screen recording, pre-zoomed |
| 3d | Second tab, a different domain — same key, signing the Nerdster statements | Screen recording |

**Bubbles:** "Not another network." → "The same statements, in a different app." → "Three
domains. None of them owned by the others." → "Nerdster only ever sees the delegate key."

**VO:** "None of these apps are connected to each other. No back doors, no special access.
They go and find statements signed by our own keys, wherever those happen to live — and
check the signatures themselves."

> **Use real identities with real spread here** (Marge's work well: identity statements on
> `export.karennet.net`, Nerdster statements on `export.nerdster.org`, and her vouch of Homer
> carrying `endpoint: https://export.one-of-us.net`). The domain diversity *is* the argument,
> and it's visible in the URL bar. Marge is the right choice for this act specifically
> because the demo phone's own statements don't span domains the same way.
>
> **Legibility is the whole risk in this act.** Pre-zoom Chrome before recording. If it still
> doesn't read at phone size, the fallback is a tighter crop of the real capture — not a
> recreated graphic.

---

## ACT 4 — HabloTengo: same network, opposite policy (2:14–2:38)

| # | Shot | Capture |
| --- | --- | --- |
| 4a | From Nerdster, notice Hillel is on HabloTengo; tap through | Screen recording |
| 4b | Sign in from the demo phone → **Access Denied** | Screen recording |
| 4c | *(decision below)* A point of view that IS allowed | Screen recording |

**Bubbles:** "Hillel never vouched for this phone." → "Open, closed, or private — same
network underneath."

**VO:** "Hablo reads those same signed statements to work out who Hillel would let see his
contact info. This phone isn't in his network, so it sees nothing. Same identities, same
statements, opposite privacy policy — because the network doesn't belong to either app."

> **Decision still open on 4c.** Denial alone shows the lock working but never shows the door
> opening, and a skeptical viewer can't tell refusal from breakage. Running 4c against the
> Simpsons demo identities gets both halves with no real contact info on screen. Your call —
> the script works unchanged if you ship denial-only.

---

## ACT 5 — Close (2:38–2:55)

| Card | Text |
| --- | --- |
| 1 | ONE-OF-US.NET, Nerdster, and HabloTengo aren't connected to each other. |
| 2 | Each one finds, verifies, and aggregates statements signed by our own keys. |
| 3 | Open, closed, private, or public as the moon — the network underneath is the same. |
| 4 | And it's ours. |
| 5 | The Internet liberated lies and pornography. Crypto on the Internet can liberate authenticity and trust — and maybe truth, sanity, and decency. |

End card: ONE-0F-US.NET wordmark + App Store / Google Play badges.

> Card 5 is the most memorable line you have, and the one most likely to decide whether a
> given viewer passes the video on or quietly doesn't. Worth a tamer alternate cut of just
> that card if this goes anywhere broad.

---

## Shot inventory

Screen recordings, silent, one clean take each:

1. Turn FYI on — **unshot**
2. Scan + vouch, with FYI showing the statement being signed and published — **unshot**
3. Interpreted → raw toggle on that statement — **unshot**
4. Share-invitation flow
5. Nerdster sign-in + delegate key creation
6. Nerdster browse: Tom, then Hillel
7. PoV switch — *usable footage exists*
8. Trust modes: PoV Milhouse under `permissive`, then under `strict` — two takes of the
   same screen, identical scroll position, so they cut as a clean split — **unshot**
9. "Signed, Published Statements" → Chrome, Pretty-print, two domains — **unshot**
10. Hablo from Nerdster → Access Denied
11. Hablo allowed view, Simpsons identities — pending decision

### Shot 1a — the one physical shot (three phones)

Every other shot is recorded from inside the demo phone. This one is filmed from outside,
which takes a third device, because neither phone in the frame can film itself.

- **Camera:** third phone on a tripod, shooting **portrait**, 30fps. Frame it at roughly
  table height, close enough that both phones fill most of the frame.
- **In frame:** Tom's phone lying on the table or held, showing his QR code; the demo phone
  held above it, scanning. The demo phone's screen should be angled so its viewfinder is at
  least partly visible — that's what ties this shot to the screen recording that follows.
- **Action:** bring the demo phone into position, hold until the scan registers, lower it.
  Shoot it two or three times; it's a 3–4 second cut in the finished video.
- **Purpose:** establish that vouching is a physical act between two people in a room,
  before the video moves inside the phone for everything else.
- **Lighting:** avoid overhead glare on either screen — that's the usual reason this shot
  needs a second attempt.

The QR code itself is a public key, so there's nothing sensitive about it being legible.

Audio: one VO pass, ~280 words, quiet room, phone held close or USB mic.

## Post

Burned ASS caption bubbles, zoom punch-ins on the FYI statement and the Chrome JSON,
split-screen for the PoV switch, speed ramps over typing and network waits, text cards,
end card, VO mix.
