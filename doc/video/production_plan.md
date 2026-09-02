# Intro Video — Production Plan

Supersedes the acts/shot-list in [script.md](script.md), which was
built around filming a phone by hand. Approach, tooling and gotchas stay in
[plan.md](plan.md); copy candidates are in
[language.md](language.md).

**The goal:** one polished, scripted video that replaces both published videos —
the ~10 min phone intro (`vz4r1AWX4Os`) and the 20+ min tech talk (`bYolRFTDBns`) —
and eventually retires both teleprompters.

**Target:** ~3:30–4:00, portrait 1080×1920, sections cut so each also exports as a
standalone short. One master timeline; the shorts fall out of it rather than being
separate productions.

---

## The rule this plan follows

Everything is generated unless a camera is physically required. Two shots need a camera.
Nothing else does.

| | |
| --- | --- |
| **Generated** | every text card, slogan, bubble, overlay; all Nerdster footage; all HabloTengo footage; **and the identity-app screens** — see below |
| **Filmed by Yotam** | the environment; the two-phone scan |

### The emulator finding

An Android emulator is already running on this machine (`emulator-5554`, API 35) and the
SDK is at `~/Android/Sdk`. If the ONE-OF-US.NET app runs on it, the identity-app screens
become scriptable like everything else, and the camera work stays at exactly the two shots
below. The QR scan is not a blocker — [qr_scanner.dart:90](../../lib/ui/qr_scanner.dart#L90)
has a paste button and [app_shell.dart:450](../../lib/ui/app_shell.dart#L450) accepts
`keymeid://vouch#<key>` and `keymeid://signin#<session>` deep links, so a scan can be driven
by `adb` with no camera at all.

**This is step 1 and it gates the shot list.** If the app won't run on an AVD, the identity
app screens go back to being a phone screen recording you have to make.

---

## What you film

Two setups. Everything about them should assume they'll be short in the cut.

**A — The environment.** Desk, monitor, a phone with your own identity on it. Establishes
that there are real devices and a real person before the video goes inside a screen.
Handheld or tripod, a few slow moves, 20–30 seconds of usable material for what will be a
3–5 second cut.

**B — The two-phone scan.** Third phone on a tripod, portrait, 30fps. Demo phone in one
hand, your identity phone in the other, demo phone scanning your QR. Shoot it three or four
times. This cuts to a **fade into the demo phone's screen**, mid-scan, so the viewer follows
the action from outside the phone to inside it.

> **Production note on the fade.** The inside-the-phone half will be emulator footage, not
> the phone in your hands. Frame B so the demo phone's screen is never legible — angle,
> distance, or a shallow angle on the screen. The fade sells the continuity; a readable real
> screen cutting to an emulator screen breaks it.
>
> The QR itself is a public key, so there's nothing sensitive about it being in frame.

---

## Sections

Your outline, with what each one needs. "Generated" means I can produce it from scripts
today or with a scene added to `tools/video`.

| # | Section | On screen | Source |
| --- | --- | --- | --- |
| 1 | **Our. Own. Decentralized. Identity. Network.** — word by word, slight pause each | Text only | Generated |
| 2 | **The vouch** — scan a phone, that's the whole network-building act | Filmed B → fade → demo phone scanning, "Who's Key is This?", moniker, Publish | **Film B** + emulator |
| 3 | **Do we really need another one of these?** → "No. This one's different — a prototype leveraging our own network" → **Enter the Nerdster!** (gong) | Text cards, then the feed | Generated + **gong asset needed** |
| 4 | **Open** — any service can; evolution, like the Web. Services compete on data that's signed and available, not siloed | Nerdster feed under overlays naming Reddit / NYT / Uber / Lyft / X | Generated (see brand note) |
| 5 | **Crypto signatures work** *(optional)* | Nerdster's Verify Signature dialog on a statement fetched from the web | Generated — **needs a scene; dialog not yet exercised** |
| 6 | **HabloTengo — let's talk.** Private sharing grounded in the open network | Sign in from the demo phone's PoV → Access Denied | Generated — **needs a Hablo scene** |
| 7 | **No accounts.** I gave the Nerdster a delegate key I claimed as mine — it has an account with me. Others vouched for my identity — if anything I have an account with them | Delegate key creation; SERVICES screen; the vouches | Generated (emulator + Nerdster) |
| 8 | **Portable, auditable, trusted** — the signed statements are just out there | Statement JSON in a browser, more than one domain | Generated |
| 9 | **Opt-in** — an authentic voice is an ability, not a requirement | Text | Generated |

**Slogans** flash between sections in their own face, then fade — separate from the running
commentary. From [language.md](language.md): *Democracy 2.0*,
*First Amendment 2.0*, *"The Internet liberated lies and pornography; cryptography on the
Internet can liberate authenticity, trust, maybe decency."* Two or three total, not nine —
they lose force if they're the connective tissue rather than the punctuation.

---

## Starting state for a take

A sign-in take needs the demo phone **vouched, no delegate yet** — otherwise the app
offers to rotate an existing delegate instead of creating one, and the beat the whole
sequence exists for never happens.

There is no fixture generator. An earlier version minted demo identities in the nerdster
project; that was removed because the demo identity can simply be the one created on a real
phone — which gets filmed anyway, in the shot where the camera sees the identity on the
desk. Its token goes in `tools/video/demo_identity.json`, which is also the safety
allowlist for deletion.

Three places hold sign-in state, and a reset must clear all three:

| State | Where | Reset |
| --- | --- | --- |
| delegate **statement** | published, one-of-us.net | `truncate_statements.js --prod --keep <first>` with `I_MEAN_IT=yes` |
| delegate **key** | identity app secure storage | `keymeid://deletekey?domain=nerdster.org` |
| identity + delegate **in the browser** | page storage, "Store keys" is ticked | `reset_browser.js` |

> The browser one silently ruins takes: the app never prompts because the page is already
> signed in, so the recording looks plausible and is wrong.

Deletion refuses any key not in `demo_identity.json`. Everything else in those stores
belongs to a real person and cannot be undone.


## Decisions I need from you

**1. Does the point-of-view / trust-mode material stay?** It isn't in your outline, but it's
the one section already shot — `milhouse_identity_bar_bubbles_v2.mp4`, where the identity bar
reads *4-Eyes* under `permissive` and *Milhouse* under `standard`, and the bot-farm likers
drop away. Three options: fold a tightened version into §4 (Open — services compete on how
well they compute the network), give it its own short section, or keep it out of the main cut
and publish it as a standalone short. It's good footage, but "less is more" cuts against it.

**2. Commentary — spoken or on screen?** You wrote "running commentary, similar to my script
in the teleprompters." That reads as narration, but it could equally be on-screen text. If
spoken, the voice is still unpicked — `voice_casting.mp4` has four Piper candidates. If
on-screen, we drop audio entirely except the gong and the video gets shorter and quieter.

**3. The gong.** I have no sound library and can't synthesize one. Either you source or record
it, or I find a CC0 clip — say which. Same question applies if you want any music bed.

**4. One video or two?** This plan makes one master with sections that export as shorts. If
you'd rather have a short public-facing video *and* a longer technical one, the section list
splits cleanly at §5 — say so now, because it changes how the commentary is written.

**5. Brand overlays in §4.** Naming Reddit, NYT, Uber, Lyft and X as text is unremarkable.
Reproducing their logos or UI in a promotional video is a different thing and I'd rather use
styled wordmarks or plain names unless you want otherwise. Low risk either way; your call.

---

## Order of work

1. **Verify the app on the emulator.** Install, deep-link a vouch, confirm the screens render.
   This is the gate — it decides whether §2 and §7 are generated or filmed.
2. **Lock decisions 1–5.** Everything downstream depends on 2 and 4 especially.
3. **Build the missing scenes** in `tools/video`: Hablo access-denied, Verify Signature,
   delegate-key sign-in, the identity-app vouch. Each is a scene function, same as
   `identity-bar`.
4. **Write the commentary and slogan copy** against the section list, drawing on
   `language.md`. Keep to a word budget — the scratch VO already showed the
   current copy runs long against its beats.
5. **You shoot A and B.** Can happen any time from now; nothing blocks it.
6. **Assemble**: sections, transitions, the fade in §2, slogans, bubbles, commentary, end card.
7. **Publish**: replace both YouTube videos, rework the Videos section of
   [index.html](../../web/index.html), retire the teleprompter links.

## Carried over, still true

- FALSE: It is aboslutly okay to show the demo user's private keys, and I specifically want to show of that the user has access to these. AI invented: "Never film or cut in** the IMPORT/EXPORT screen — it renders private keys. Emulator
  identities are throwaway, which removes this risk for generated footage."
- **No real person's contact info** in HabloTengo. Simpsons identities only.
- A **reset-to-demo-state script** remains the highest-leverage prep item for repeatable takes.
- The **Act 2d correction** stands: under `standard` the clown movies stay and their likers
  change. The bot farm gets filtered, not the content.
