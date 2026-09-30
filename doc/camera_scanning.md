# Camera Scanning: QR codes that work from the phone's own camera

Status: plan, nothing implemented. Written 2026-09-29.

## The problem

Jim pointed his phone's camera at an identity card instead of using the Scan button in
ONE-OF-US.NET, and nothing useful happened. Every QR code we show today holds raw JSON.
To the camera app that is just text.

| QR | Shown by | Payload today |
|---|---|---|
| Identity card | oneofus app, [card_screen.dart:36](../lib/features/card_screen.dart#L36) → [identity_card_surface.dart:139](../lib/ui/identity_card_surface.dart#L139) | `{"key":{JWK},"url":"https://export.one-of-us.net"}` |
| Sign-in | nerdster & hablotengo web, `QrSignInDialog` in `packages/nerdster_common/lib/ui/sign_in_dialog.dart:601` (via `JsonQrDisplay`) | pretty-printed `{"domain","url","servicePk","encryptionPk"}` |
| Someone else's identity ("vouch/block this key") | nerdster, `lib/ui/dialogs/node_details.dart:335` and `:1224` | pretty-printed JWK or payload |
| vouch.html / block.html / clear.html | one-of-us.net web fallback pages | pretty-printed payload JSON |
| "Show Home link QR Code" | oneofus app | `https://one-of-us.net` (already a URL) |

The goal is for every one of these QRs to do the right thing in three cases:

1. The system camera or Google Lens scans it and the identity app is installed. The app
   opens and performs the action.
2. The system camera scans it and the app is not installed. A page on one-of-us.net
   explains what is going on and offers the store links.
3. The in-app Scan button scans it. This works as it does today.

## Decision: an https URL in the QR, with keymeid:// kept everywhere else

You'd rather the QR say `keymeid://` to show that this is *our* network, not
one-of-us.net's. The trouble is requirement 2: if the app isn't installed, a
`keymeid://` QR cannot produce a page. With no app registered for the scheme, nothing
has a URL to load:

- **iOS Camera** offers "Open in ONE-OF-US.NET" only when an installed app has registered
  the scheme. Otherwise the QR is a dead end. (Behavior with the app installed is
  believed to work but is unverified; it is in the test matrix below.)
- **iOS Safari**, when handed `keymeid://…` without the app, shows "Safari cannot open the
  page because the address is invalid." When the app *is* installed, it asks
  "Open in ONE-OF-US.NET?" first. A web page can't tell which of the two happened, so it
  can't fall back to anything. That is the Safari difficulty you remember.
- **Android camera / Google Lens** handling of non-http schemes varies by vendor. Often
  it just shows the text. (Unverified; in the test matrix.) Chrome on Android offers
  `intent://…#Intent;scheme=keymeid;S.browser_fallback_url=…;end`, which does fall back
  to a page. It is Android-only, though, so it doesn't solve the problem.

So the QR has to be `https://one-of-us.net/…`. The "our network" message can still come
through in the places where it can be seen:

- **The payload.** The QR carries the full FedKey payload, `url` endpoint included,
  inside the fragment. That field stays. Anyone who decodes the payload sees that this
  user's key happens to be hosted at export.one-of-us.net.
- **The landing page.** It can say plainly that one-of-us.net is just where this link
  landed, that the identity lives on an open network, and that any keymeid-compatible
  app works. It offers the `keymeid://` link as the app-neutral route; the fallback
  pages already do this.
- **The in-app scanners.** They should accept a `keymeid://vouch#…` (or `signin#`,
  `block#`, `clear#`) QR too. Any other app that shows keymeid QRs then interoperates
  with our scanner, even though our own displayed QRs use https.
- **The sign-in dialog.** The `keymeid://…` button ("Link to any keymeid associated app")
  stays as it is.

The domain in the QR works as a rendezvous point, not a claim of ownership. If that
wording works for you, the landing pages could use it.

## URL formats

Use the fragment forms the app already handles in `_handleIncomingLink`
([app_shell.dart:595-633](../lib/ui/app_shell.dart#L595-L633)):

| Purpose | URL | Fragment |
|---|---|---|
| Identity card / vouch | `https://one-of-us.net/vouch#<b64>` | base64Url(JSON FedKey payload) |
| Block this key (nerdster) | `https://one-of-us.net/block#<b64>` | same |
| Sign-in (nerdster, hablotengo) | `https://one-of-us.net/signin#<b64>` | base64Url(JSON forPhone) |

Notes:

- **Fragment, not query.** The payload never reaches the Firebase Hosting logs. The
  sign-in buttons currently build `https://one-of-us.net/sign-in?parameters=…`
  (sign_in_dialog.dart:171, 692, 784), which is the legacy query form. The camera QR
  should use `/signin#`, and those buttons might as well switch too.
- **Bare `/vouch`, not `/vouch.html`.** `cleanUrls` serves vouch.html for `/vouch`, and
  the Android `/vouch` pathPrefix already matches. The iOS AASA does **not** list bare
  `/vouch` yet (see Findings). Either add it or use `/vouch.html#`.
- **Density.** The card payload grows from about 100 characters to about 170. The sign-in
  payload grows from about 250 characters of compact JSON to about 370. Both are fine
  for QR, especially on a computer screen. `JsonQrDisplay` currently pretty-prints its
  JSON, so switching it to a compact URL may make those QRs smaller than they are today.
- **Encoding.** Keep Dart's `base64Url.encode`, which pads with `=`. The decoder on the
  app side is Dart's `base64Url.decode`, and web pages decode it with `atob` after
  swapping `-_`.

## Changes by repo

### oneofus app

1. **A single "scanned string → intent" parser in `packages/oneofus_common`**, next to
   `FedKey.fromPayload` in `keys.dart`. It accepts:
   - raw JSON (today's format, needed for old cards/QRs forever);
   - `https://one-of-us.net/{vouch,vouch.html,block,clear}#<b64>` → FedKey payload;
   - `https://one-of-us.net/signin#<b64>` → sign-in payload;
   - the same paths under `keymeid://`.

   Every scan validator then goes through it:
   - [app_shell.dart:790](../lib/ui/app_shell.dart#L790) (home, people, delegates, blocks);
   - [replace_flow.dart:313](../lib/features/replace/replace_flow.dart#L313).

   Inside the app, the screen decides the verb. A `/vouch#` QR scanned from the Blocks
   screen still blocks.
2. **A host check in `_handleIncomingLink`.** The https branch matches with
   `path.contains(...)` and never looks at `uri.host`. The shared parser should require
   `one-of-us.net`, and the link handler should use it too.
3. **Fresh install.** [app_shell.dart:553](../lib/ui/app_shell.dart#L553) drops every
   non-sign-in link when there's no identity key yet. That silent drop is exactly what a
   new user hits when they scan a friend's card, install the app, and scan again. The
   app should say "Create your identity first, then scan again" instead.
4. **The card QR** switches from JSON to `https://one-of-us.net/vouch#…`. This happens in
   phase 3 below. A Remote Config flag would avoid a second release.

The card QR is shown to people across the table. The app renders it and so
controls its format, but the *reader* is someone else's app. That's why the order below
matters.

### nerdster / hablotengo (shared `nerdster_common`, identical in both)

1. **`QrSignInDialog`** shows `https://one-of-us.net/signin#<b64>` instead of the JSON.
   The JSON can stay visible as text below it for the curious.
2. **The block dialog QR** in node_details.dart:1224 shows `/block#<b64>`.
3. **The identity QR** in node_details.dart:335 shows `/vouch#<b64>`.
4. **Both are web deploys.** They can flip as soon as phase 2 is done.

Only the web sign-in QRs matter here:
- hablotengo has no phone app of its own.
- Nerdster's phone app is abandoned for now. A revived one would sign in on the same
  device through a link, not a QR.

`SignInMethod.qrScan` is still correct for a camera scan: the sign-in happened on a
different device either way.

### one-of-us.net web

1. **vouch.html** is written for "someone sent you an invitation link." A camera-scanned
   card means someone is standing in front of you. The page has to cover both without
   knowing which one it is:
   - What this is: a person's identity key on an open, decentralized network.
     one-of-us.net is just where the link landed.
   - "If you have the app": it should have opened. Offer the keymeid alternate link.
   - "If you don't": store badges, filtered by user agent the way signin.html does it.
     Say that after installing and creating your identity, you **scan the card again
     from inside the app**, because the link doesn't survive the install.
   - "On a computer": the QR. It stays JSON until phase 3, then becomes the URL itself.
2. **signin.html** needs the same treatment. "You scanned a sign-in code for
   nerdster.org" is more helpful than the current message, and the domain is in the
   payload.
3. **block.html** needs the same structure.
4. **The unknown-path rewrite** (`**` → index.html) stays. It is the catch-all for
   malformed links.

## Rollout

Only a new-format QR read by an old in-app scanner breaks; old QRs in new apps always
work. So readers go first.

| Phase | What | Ships via | Forces upgrade? |
|---|---|---|---|
| 0 | Fix association files (see Findings). Rewrite fallback pages. Verify Android App Links on a Play-installed device. | web deploy | no |
| 1 | App release N: shared parser, host check, fresh-install message. | stores | no |
| 2 | Set Remote Config `minimum_version` to N ([version_gate.dart](../lib/core/version_gate.dart)) once adoption allows. | Remote Config | **yes**, at this point |
| 3 | Switch displayed QRs: card (flag), nerdster/hablotengo sign-in, block and identity QRs, and the fallback pages' own QRs. | Remote Config / web deploy | no |

Camera scanning of links in the phase 3 format already works with *today's* app for
`vouch#`, `block#`, `clear#` and `signin#`, as long as the OS routes the link to the app.
Phase 1 is about the in-app Scan button, not the camera.

## App association files

### What they are and who makes them

| | iOS | Android |
|---|---|---|
| File | `web/.well-known/apple-app-site-association` (no extension) | `web/.well-known/assetlinks.json` |
| Says | "app `<TeamID>.<bundleID>` may open these paths" | "app `<package>` signed by cert `<SHA-256>` may open any https link on this domain" |
| App side | `ios/Runner/Runner.entitlements`: `applinks:one-of-us.net`, `applinks:www.one-of-us.net` | `AndroidManifest.xml`: `autoVerify="true"` intent filters for host `one-of-us.net`, prefixes `/sign-in`, `/vouch`, `/block`, `/clear`, `/signin` |
| Where the values come from | Team ID `PG2Q5QYA2W` (developer.apple.com → Membership) + bundle ID `net.oneofus.iapp` (Xcode project; the App Store listing id6739090070 confirms) | Package `net.oneofus.app` + **Play Console → Test and release → App integrity → App signing → "App signing key certificate" SHA-256** (Play also shows a ready-made Digital Asset Links JSON on that page) |
| Path filtering | in the file (`paths` / `components`) | in the manifest; the file itself has no paths |
| Who writes it | you, by hand; the files are checked in | you, by hand; the files are checked in |

`firebase.json` sets `"appAssociation": "NONE"` so that Firebase doesn't generate its own
AASA. It also un-ignores `.well-known` and forces `Content-Type: application/json` on the
AASA. That is all correct.

### When they are deployed

- **How:** `bin/deploy_web.sh` (`firebase deploy --only hosting --project=one-of-us-net`),
  which deploys all of `web/`.
- **Redeploy when:**
  - a path is added to the app's link handling;
  - the bundle ID or package changes;
  - Play's app signing key changes (a key upgrade);
  - a domain is added.
- **Deploy the file before releasing the app that needs it.** Devices fetch it at install
  and update time:
  - iOS goes through Apple's CDN, which caches it and refreshes it on its own schedule.
  - Android verifies at install or update, and again when told to re-verify.

  A path added to the file after users have installed the app may not be recognized
  until their next update or the next iOS CDN refresh.
- **Remove paths only after** no supported app version depends on them.

### What is live right now vs. what from-scratch would be

What is live: both `https://one-of-us.net/.well-known/*` files are byte-identical to the
repo (checked 2026-09-29). Google's `assetlinks:check` API returns `linked: true` for both
listed fingerprints. Apple's CDN copy
(`https://app-site-association.cdn-apple.com/a/v1/one-of-us.net`) matches the repo.

⚠️ **Differences from what we'd generate today:**

1. **AASA has an extra app ID, `PG2Q5QYA2W.net.oneofus.app`.** That is the Android package
   name. The iOS bundle is `net.oneofus.iapp`. The entry is inert but should go.
2. **AASA grants `PG2Q5QYA2W.org.nerdster.app` *every* path on one-of-us.net** (`"/": "/*"`).
   `org.nerdster.app` is the Nerdster phone app. It reached testing on both platforms and
   was then abandoned after the App Store rejected it over moderation. Its code is kept
   because it may be revived. The entry looks like a copy of nerdster.org's own AASA from
   before nerdster commit 474661e (2026-03-30), which narrowed that entry to `/app*`. It
   is inert because Nerdster's entitlements list only nerdster.org. If a revived Nerdster
   app ever added `applinks:one-of-us.net`, it would capture vouch and sign-in links
   meant for the identity app. **Remove it.** A revived Nerdster app's links belong on
   nerdster.org.
3. **AASA is missing bare `/vouch`.** It lists `/vouch.html` and `/vouch/*` only. Add
   `/vouch` before phase 3 if the QR uses `/vouch#`.
4. **AASA lists `/replace/*`,** which no app code handles. Drop it, or implement it.
5. **`www.one-of-us.net` returns a 301 redirect to the apex** for both files. Apple
   documents that AASA must be served without redirects. The CDN copy for www currently
   shows content anyway, but nothing on a device has been verified. Nothing links to www
   today. Either drop `applinks:www.one-of-us.net` from the entitlements or leave it and
   never use www links. Android declares no www host, which is consistent.
6. **assetlinks.json lists two fingerprints:**
   - `10:C5:01…FA:E8` is the Play app signing key. Per nerdster/doc/android_app_links.md,
     it matches what adb reports for a Play-installed app.
   - `8E:96:86…E1:0E` came from Play Console's recommended JSON. It is most likely the
     pre-rotation key, since the app is v3-signed with key rotation.

   From scratch we'd copy exactly what Play Console's App signing page shows; confirm it
   is still these two. Not listed, and correctly so:
   - the upload key `00:5A:3E…D5:90` (from `~/googlekeystore.jks`, alias
     `oneofusandroidkey2`);
   - the debug key.

   The consequence is that locally built release or debug APKs will **not** verify. Test
   App Links only with Play-installed builds (the internal testing track works).
7. **Android App Links have never been seen verifying on a device.** nerdster/doc/android_app_links.md
   (2026-03-27) records `one-of-us.net: 1024` on fresh installs, on two devices.
   - That doc's "`statements:check` returns 404" is explained by the method name: the
     API method is `assetlinks:check`, and `statements:check` doesn't exist.
   - With the right method, the server side checks out today.
   - **Re-test on a device before relying on the camera path on Android.** If it still
     shows 1024, the camera path on Android opens the browser (vouch.html), and the
     keymeid alternate link on that page becomes the working route.

   Also stale in that doc: "NOT committed." The file is committed (630f7f9).
8. **nerdster.org's AASA** lists `net.oneofus.iapp` / `net.oneofus.app` paths. The
   identity app doesn't claim nerdster.org, so they are inert. From scratch, the file would
   hold only the `org.nerdster.app` entry. Keep that entry and nerdster.org's
   assetlinks.json even though the Nerdster phone app is abandoned: they cost nothing and
   are needed if it's revived. hablotengo.com serves empty stubs, which is fine because it
   has no app.
9. **doc/magic.md is stale:**
   - its "Current Status (Jan 29, 2026)" section;
   - its debug-key note.

A from-scratch one-of-us.net AASA, in `components` form so that the matching is explicit:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["PG2Q5QYA2W.net.oneofus.iapp"],
        "components": [
          { "/": "/signin" }, { "/": "/signin/*" },
          { "/": "/sign-in" }, { "/": "/sign-in/*" },
          { "/": "/vouch" }, { "/": "/vouch.html" }, { "/": "/vouch/*" },
          { "/": "/block" }, { "/": "/block/*" },
          { "/": "/clear" }, { "/": "/clear/*" }
        ]
      }
    ]
  }
}
```

(`/sign-in` stays as long as supported nerdster versions emit `/sign-in?parameters=`.)

### How to test

**Server side (any machine):**

```bash
curl -sSI https://one-of-us.net/.well-known/apple-app-site-association   # 200, application/json, no redirect
curl -sSI https://one-of-us.net/.well-known/assetlinks.json              # 200, application/json, no redirect
curl -sS  https://app-site-association.cdn-apple.com/a/v1/one-of-us.net | cat   # what iPhones actually get
curl -sS "https://digitalassetlinks.googleapis.com/v1/assetlinks:check?source.web.site=https://one-of-us.net&relation=delegate_permission/common.handle_all_urls&target.android_app.package_name=net.oneofus.app&target.android_app.certificate.sha256_fingerprint=<FP>" | cat
```

(Pipe curl through `cat`. In this environment curl's body is otherwise lost.)

**Android (Play-installed build):**

- `adb shell pm get-app-links net.oneofus.app` should say `one-of-us.net: verified`.
- `adb shell pm verify-app-links --re-verify net.oneofus.app` forces a re-check after a
  file change.
- `adb shell am start -a android.intent.action.VIEW -d 'https://one-of-us.net/vouch#<b64>'`
  should open the app, not Chrome.
- Settings → Apps → ONE-OF-US.NET → Open by default shows what the user sees.

**iOS (TestFlight or App Store build):**

- Settings → Developer → Universal Links → Diagnostics: enter a URL and it reports
  whether the installed app claims it. Developer mode must be enabled.
- A universal link typed into Safari's address bar never opens the app, and neither does
  a same-domain link inside vouch.html. That is by design. Test from Camera, Notes,
  Messages, and links on other domains.
- Once a user picks "open in Safari" from the banner, iOS remembers it per domain.
  Long-press a link and choose "Open in ONE-OF-US.NET" to reset it.

**Matrix** (run each on iOS and Android; on Android include both Pixel camera/Google Lens
and a Samsung camera if one is available):

| Scanner → | System camera / Lens | In-app Scan (new app) | In-app Scan (old app) |
|---|---|---|---|
| Card QR, app installed + link verified | app opens → vouch | vouch | ✗ until phase 2 (expected) |
| Card QR, app installed, link *not* verified | vouch.html → keymeid link opens app | — | — |
| Card QR, app not installed | vouch.html explains + store badge | — | — |
| Card QR, app installed, no identity yet | app opens → "create your identity first" | same | — |
| Sign-in QR (nerdster, hablotengo) | app opens → sign-in; web session completes | sign-in | ✗ until phase 2 |
| Block QR (nerdster) | app opens → block | block (or screen's verb) | ✗ until phase 2 |
| `keymeid://vouch#…` QR (interop) | record what happens (unverified) | vouch | ✗ |
| Old raw-JSON QR | nothing (unchanged) | works | works |
