# QR codes are for identity apps, not the phone camera

Status: decided 2026-10-11. Supersedes the plan in [camera_scanning.md](camera_scanning.md).
That doc's association-file audit still applies to the https links we share as text.

## The decision, in Yotam's words

> I considered having the QR codes be scannable by the generic phone camera rather than
> only by the ONE-OF-US.NET identity app.
> The QR codes are used to vouch for others (or in more rare cases block, claim old
> delegate or identity keys) and to sign in to the services HabloTengo and the Nerdster.
> I've decided against that because this paradigm is meant to specifically be "not my
> network, not the ONE-OF-US.NET network". People can host their keys on services, too.
> Competitors should be able to create apps just like the ONE-OF-US.NET identity app and
> use those to sign in to the Nerdster, claim keys, etc...
>
> I'd like to briefly explain this using a popup or something where QR keys are shown,
> specifically explain that the QR needs to be scanned with "an" identity app (eg.
> ONE-OF-US.NET phone app) and can't be scanned by a camera because that would include a
> URL to ONE-OF-US.NET specifically. The explanation should be supplemental (like clicking
> on "?" or "i" or something similar) so that it does not take up space.

## Why the camera can't do it

A phone camera only acts on a URL, and an https URL names one domain. A
`https://one-of-us.net/vouch#…` QR would make one-of-us.net the front door to every
identity, which is what the paradigm rules out. A `keymeid://` QR is neutral, but with no
app installed the camera has nothing to show (see camera_scanning.md, "Decision").

So the QR keeps holding the data itself: the key and where it is hosted, or the
sign-in request. Any identity app can read that.

## The "?" explanation

A small `?` (`Icons.help_outline`) next to the QR's title opens a short dialog.

The text, as in `QrHelpButton` (`packages/oneofus_common/lib/ui/qr_help.dart`), with
*what*, *holds* and an optional *extra* paragraph filled in by each screen:

> **Scan with an identity app**
>
> *What* holds *holds*. It doesn't open a web page, so a phone's camera can't do
> anything with it. Scan it with the Scan button in an identity app, such as the
> ONE-OF-US.NET app.
>
> Our decentralized identity paradigm avoids referencing any specific company or
> service. Any app that supports that paradigm can scan it. A camera-friendly code
> would have to point at a specific service.
>
> *extra*

| Where | *what* | *holds* | *extra* |
|---|---|---|---|
| Sign-in (nerdster, hablotengo) | This sign-in code | sign in parameters | — |
| Card (oneofus app, share menu → "Why can't a camera scan my card?") | The QR code on your card | your identity key and where your statements are hosted | If the person scanning doesn't have an identity app yet, choose "Help someone get the app" from the share menu. Their camera can open that QR code. |

"Help someone get the app" (formerly "Show Home link QR Code") shows a QR of
`https://one-of-us.net`, which a camera can open.

Store links belong on one-of-us.net, not in this dialog. One link to
`https://one-of-us.net` is enough.

## People who scan with the camera anyway

Users have pointed the phone's camera at our QR codes. Yotam would like to tell those
users they're doing it wrong, but can't think of any way to do it. The camera reads the
code, finds no URL, and shows the raw text or nothing at all. None of our code runs, and
no page of ours loads.

The `?` dialog helps only the person *showing* the code, and only if they open it.

An idea, untested: phone cameras show the first part of a text QR as a preview (iOS shows
a banner, Google Lens shows the text). If the JSON's first field were a sentence, that is
what the user would see:

```json
{"_":"Scan this with an identity app, not the camera","key":{…},"url":"…"}
```

Costs:
- `FedKey.fromPayload` ([keys.dart:63](../packages/oneofus_common/lib/keys.dart#L63))
  treats every field except `key` as the endpoint, so `_` would end up in the endpoint.
  The parser would need to drop it, and apps already installed would not, so readers
  have to be updated first, the same way camera_scanning.md's rollout does it.
- The sign-in payload has the same problem in its own parser.
- Nobody has checked what each camera actually shows. JSON escaping, truncation and
  "Search the web" buttons may make it useless.

## Where QRs are shown

| QR | Code | Gets the `?` |
|---|---|---|
| Sign-in (nerdster, hablotengo) | `QrSignInDialog`, nerdster `packages/nerdster_common/lib/ui/sign_in_dialog.dart:603` | yes. Also change its title from "Scan with the ONE-OF-US.NET app" to "Scan with your identity app" |
| Block / clear identity (nerdster) | nerdster `lib/ui/dialogs/node_details.dart:1224` | yes. Already says "your identity app" |
| Identity hover popup (nerdster) | nerdster `lib/ui/dialogs/node_details.dart:335` | no: it's a hover with no room. `KeyInfoView` (tap) gets it |
| Key info (nerdster) | nerdster `lib/ui/key_info_view.dart:39` | yes |
| Key QR on a contact card (hablotengo, Show Crypto) | hablotengo `lib/export_keys_button.dart:49` | no: it only shows the key |
| Identity card (oneofus app) | [identity_card_surface.dart:139](../lib/ui/identity_card_surface.dart#L139) | yes: "Why not the camera?" in the share menu ([app_shell.dart](../lib/ui/app_shell.dart)) |
| Home link QR (oneofus app) | [share_service.dart:43](../lib/core/share_service.dart#L43) | no: it is a URL and the camera handles it |
| Crypto shield token QR (nerdster) | nerdster `lib/ui/crypto_shield_button.dart:76` | no: it's a debugging view |

The button and dialog go in `packages/oneofus_common` so all three repos get the same
copy.

## Open tension

The QR rule and our text links disagree. The app still shares
`https://one-of-us.net/vouch.html#…` ([share_service.dart:18](../lib/core/share_service.dart#L18)),
the sign-in buttons open `https://one-of-us.net/sign-in?parameters=…`, and the manifest
still has `autoVerify` https filters for one-of-us.net. That contradicts
[paradigm_decisions.md](paradigm_decisions.md), which says those filters were removed.
Either the links get the same `keymeid://`-first treatment, or this doc should say why a
link sent by text is allowed to name one-of-us.net when a QR is not.
