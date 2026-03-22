# Key Federation

## Overview

The ONE-OF-US.NET network currently hardcodes `export.one-of-us.net` as the source for all
trust statements. Key Federation is a design extension that allows identity keys to be
**homed** at other organizations — meaning their trust statements are published to and
fetched from a different endpoint.

The ONE-OF-US.NET phone app itself will always home to `export.one-of-us.net`. The goal of
this work is to define a protocol that allows third-party organizations to build their own
compatible apps and infrastructure, so that ONE-OF-US.NET account holders can
- vouch for people whose keys are homed elsewhere
- be vouched for by people whose keys are homed elsewhere
- replace their key with a key homed elsewhere

---

## Terminology

- **Home**: the identifier of the organization whose infrastructure stores a key's statements.
  Today this is always `export.one-of-us.net`.
- **Homed key**: an identity key paired with a home identifier.
- **Native key**: a key homed at `export.one-of-us.net` (the only kind today).

---

## Protocol Design

### Vouch statements carry the home

The `home` field is added to the `with` clause of trust (vouch) statements.

Vouch statement `with` clause fields:

| Field      | Required | Description |
|------------|----------|-------------|
| `moniker`  | Yes      | Human-readable name for the vouched key |
| `home`     | No       | Home identifier for the vouched key. For `net.one-of-us` statements, absence defaults to `export.one-of-us.net`. Existing signed statements without `home` are treated as native. |
| `comment`  | No       | Free-text note about why this person is being vouched for |
| `revokeAt` | No       | ISO timestamp after which this vouch expires |

Example:

```json
{
  "trust": <their public key>,
  "with": {
    "moniker": "Alice",
    "home": "export.one-of-us.net",
    "comment": "Met at RustConf 2024",
    "revokeAt": "2027-01-01T00:00:00Z"
  }
}
```

**Backward compatibility:** Existing `net.one-of-us` statements without a `home` field
default to `export.one-of-us.net`. Migration is both unnecessary and impossible:
existing statements are signed by private keys we don't hold.

### QR codes and invitation links carry the home

When a key owner displays their QR code or generates an invitation link, the payload
includes their home alongside the public key:

```json
{
  "key": <public key>,
  "home": "export.one-of-us.net"
}
```

**Backward compatibility:** Existing QR codes and invitation links without `home` are treated
as `export.one-of-us.net`. The ONE-OF-US.NET phone app assumes the default home when scanning
a legacy payload that omits `home`.

Examples:
- old invitation links in people's emails
- old QR codes distributed in a variety of ways

### Each organization operates its own infrastructure

The ONE-OF-US.NET phone app publishes to `export.one-of-us.net`. Third-party organizations
build and operate their own apps and backends. There is no requirement that third parties
use our API design — the protocol for how a home stores and serves statements is up to each
organization. Our own implementation is documented in
[`openapi.yaml`](../../nerdster14/functions/openapi.yaml), served live at
[`export.one-of-us.net/openapi.yaml`](https://export.one-of-us.net/openapi.yaml).

### Key replacement across homes

Key replacement uses the existing `replace` statement: the **new key** signs a statement
claiming the old key. Depending on implementation, this may also include revoking the old
key and/or re-signing statements made by the old key. How this is carried out is up to
the identity service and/or the person. How a `replace` statement is interpreted is up to
each service. See [`trust_statement_semantics.md`](../../nerdster14/docs/trust_statement_semantics.md)
for how the Nerdster and ONE-OF-US.NET define these semantics.

Under Key Federation, the two keys may have different homes. No new protocol is needed
— the `replace` statement is unchanged. The only requirement is that the trust pipeline
can fetch statements from the old key's foreign home, which is part of Full Federation Support.

---

## Backward Compatibility

### QR code format

The current QR code contains just the raw public key JSON (`{"crv":...,"kty":...,"x":...}`).
Changing it to a wrapped object `{"key":..., "home":...}` is a **breaking format change**:
an old app scanning a new-format QR will fail to parse it as a key. The same applies to
invitation links.

The breaking change only occurs when the app **shows** a QR code or **sends** an invitation
in the new format. Scanning/parsing the new format is always safe to ship first.

Rollout plan:
- **Phase 1:** Ship a new app version that can scan both old and new formats, but still
  shows the old bare-key format. No user impact. A checkbox on the Advanced screen
  (default off) enables showing the new wrapped format.
- **Phase 2:** Ship a follow-up version that always shows the new wrapped format. Only
  safe once virtually all users are on Phase 1 or later.

### The version adoption problem

There is no perfect answer — users who install the app and never update are invisible.

**App Store / Play Store version distribution** — the primary approach. Both platforms
provide a version breakdown of the active install base. When pre-Phase-1 installs drop to
negligible (e.g., <1–2%), it is reasonably safe to ship Phase 2.

UNLIKELY:
**Server-side version logging**
Record the app version on each sign-in (or any server call). This gives you a live view
of which versions are actively being used, not just installed. Users who never open the
app aren't a real concern — they won't be scanning QR codes.

QUESTIONABLE: probably not worth the hassle.
**Firebase Remote Config (feature flag)**
Gate the Phase 2 QR write format behind a remote flag. Leave it off at launch and only
enable it after version distribution data confirms sufficient adoption. This decouples
the code change from the rollout decision.

DONE: But too late. Versions exist in the wild without this enhancement.
**Minimum version enforcement**
Optionally configure a minimum supported app version in Firebase Remote Config. Old
clients are shown "please update to continue." This is heavy-handed but gives a hard
guarantee. Could be targeted to only users who attempt to scan a QR code.

**Vouch statements are unaffected.** Adding `home` to vouch `with` clauses is purely
additive — existing signed statements default to `export.one-of-us.net` and remain valid
indefinitely. No version adoption concern there.

---

## Work: Protocol Changes *(likely to implement)*

These changes update the protocol to carry home information. If a non-`export.one-of-us.net`
home is encountered at runtime, a graceful **"Unsupported: Key Federation not yet
implemented"** error is shown. Implementation details are deferred.

- [ ] **Vouch statement schema**: add optional `home` to the `with` clause. `net.one-of-us`
  statements without `home` default to `export.one-of-us.net`. Existing signed statements
  are unaffected.

- [ ] **QR code / invitation link format**: extend the payload to include `home`. Existing
  QR codes and links without `home` are treated as `export.one-of-us.net` (backwards
  compatible).

- [ ] **ONE-OF-US.NET phone app**: include `home` in vouches, QR codes, and invitation
  links. Assume `export.one-of-us.net` when parsing legacy payloads that omit `home`.
  *(Phone app changes are a prerequisite for the Nerdster changes below.)*

- [ ] **Nerdster sign-in**: accept an optional `home` field in the sign-in payload.
  If absent, default to `export.one-of-us.net`. If present and `home != export.one-of-us.net`,
  fail with: *"Unsupported: Key Federation not yet implemented."* Details deferred.

---

## Export API Documentation *(done)*

- [x] **Document the ONE-OF-US.NET export API** as a reference that third parties may
  optionally follow. This does not make our API a prescribed standard — other organizations
  may design their own interfaces. [`openapi.yaml`](../../nerdster14/functions/openapi.yaml)
  (OpenAPI 3.1) is served live at
  [`export.nerdster.org/openapi.yaml`](https://export.nerdster.org/openapi.yaml) and
  [`export.one-of-us.net/openapi.yaml`](https://export.one-of-us.net/openapi.yaml)
  via a path check in the `export` Cloud Function.

---

## Work: Full Federation Support *(UNLIKELY ANYTIME SOON)*

These changes allow the trust pipeline to actually fetch from non-`export.one-of-us.net`
homes and interoperate with third-party organizations.

- [ ] **Trust pipeline fetches from `home`**: use the per-key home to determine the fetch
  endpoint instead of hardcoding `export.one-of-us.net`.

- [ ] **Sign-in with foreign-homed key**: accept sign-in from keys not homed at
  `export.one-of-us.net`. Requires knowing how to read delegate statements from a foreign
  home.

  *Note: cross-home key replacement also falls out of this — once the trust pipeline can
  fetch from any home, `replace` statements work across homes without any protocol change.*

---

## Demo / Marketing: Display-Injected `home` *(not pursuing)*

> This approach — injecting `home` into display-only text as a cosmetic hack — was
> abandoned in favor of implementing the real protocol (Phase 1 QR/vouch changes with a
> demo checkbox). The details below are kept for reference only.

**Goal:** Make demos and marketing materials look like the Key Federation protocol is
already live — showing a heterogeneous, decentralized network not owned by one-of-us.net
— without changing any transmitted data or breaking any old app versions.

**Rule:** Wherever a key or vouch statement is *displayed as text* to the user (not
transmitted, signed, or scanned), inject `home: "export.one-of-us.net"` into the
rendered output when the field is absent. Signed data on Firestore is never touched.

**Scope boundary:** QR code content, invitation link payloads, Firestore statement bytes
are all unchanged. Only on-screen text display is affected.

### Surfaces to change

| Surface | File | Change |
|---------|------|--------|
| **vouch.html key textarea** | `nerdster14/web/vouch.html` | Show `{"key": <bareKey>, "home": "export.one-of-us.net"}` in the textarea. QR `text:` is unaffected (built separately). |
| **Phone app key JSON popup** | `oneofusv22/…/statement_card.dart` `_showJson(context, statement.subject)` | Wrap key JSON to `{"key":…, "home":"export.one-of-us.net"}` before displaying. |
| **Phone app statement JSON popup** | `oneofusv22/…/statement_card.dart` `_showJson(context, statement.jsonish.json)` | Inject `"home": "export.one-of-us.net"` into the display copy of the `with` sub-map if absent. |
| **Phone app vouch edit dialog** | `oneofusv22/…/edit_statement_dialog.dart` | Add a read-only HOME row below the other fields for `TrustVerb.trust`. |
| **Nerdster vouch tiles** | `nerdster14/…/node_details.dart` `_buildStatementTile` | Show home in small text next to moniker, defaulting to `export.one-of-us.net` if absent. |

### Implementation notes

- A small display helper `displayKeyWithHome(Map pubKey)` →
  `{"key": pubKey, "home": "export.one-of-us.net"}` can be added to `util.dart` for
  use in display-only contexts.
- `statement.jsonish['home']` is the field on the statement's `with` clause.  Default
  to `"export.one-of-us.net"` when null, for display only.
- No changes to `TrustStatement.make()`, signing, or any transmission path.
