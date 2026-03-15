# Key Federation

## Overview

The ONE-OF-US.NET network currently hardcodes `export.one-of-us.net` as the source for all
trust statements. Key Federation is a design extension that allows identity keys to be
**homed** at other organizations — meaning their trust statements are published to and
fetched from a different endpoint.

The ONE-OF-US.NET phone app itself will always home to `export.one-of-us.net`. The goal of
this work is to define a protocol that allows third-party organizations to build their own
compatible apps and infrastructure, so that ONE-OF-US.NET account holders can vouch for and
be vouched for by people whose keys are homed elsewhere.

---

## Terminology

- **Home**: the identifier of the organization whose infrastructure stores a key's statements.
  Today this is always `export.one-of-us.net`. Other organizations may use a different
  identifier format — details TBD (possibly a URI, a domain, or a structured descriptor).
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
default to `export.one-of-us.net`. No migration needed.

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

### Each organization operates its own infrastructure

The ONE-OF-US.NET phone app publishes to `export.one-of-us.net`. Third-party organizations
build and operate their own apps and backends. There is no requirement that third parties
use our API design — the protocol for how a home stores and serves statements is up to each
organization. See [export_api.yaml](export_api.yaml) for documentation of our own implementation.

---

## Backward Compatibility

### QR code format

The current QR code contains just the raw public key JSON (`{"crv":...,"kty":...,"x":...}`).
Changing it to a wrapped object `{"key":..., "home":...}` is a **breaking format change**:
an old app scanning a new-format QR will fail to parse it as a key.

The rollout must be two-phased:
- **Phase 1:** Ship a new app version that can *read* both old (bare key) and new (wrapped)
  formats, but still *writes* the old bare-key format. No user impact.
- **Phase 2:** Ship a follow-up version that *writes* the new wrapped format.

Phase 2 can only be safe once virtually all users are on Phase 1 or later. The question
is: **how do you know when that is?**

### The version adoption problem

There is no perfect answer — users who install the app and never update are invisible.
The practical options:

**App Store / Play Store version distribution**
Both platforms provide a version breakdown of your active install base in the developer
console. Monitor the percentage of installs still on pre-Phase-1 versions. When that
number is negligible (e.g., <1–2%), it is reasonably safe to ship Phase 2.

**Server-side version logging**
Record the app version on each sign-in (or any server call). This gives you a live view
of which versions are actively being used, not just installed. Users who never open the
app aren't a real concern — they won't be scanning QR codes.

**Firebase Remote Config (feature flag)**
Gate the Phase 2 QR write format behind a remote flag. Leave it off at launch and only
enable it after version distribution data confirms sufficient adoption. This decouples
the code change from the rollout decision.

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

## Work: Full Federation Support *(probably not implementing)*

These changes allow the trust pipeline to actually fetch from non-`export.one-of-us.net`
homes and interoperate with third-party organizations.

- [ ] **Trust pipeline fetches from `home`**: use the per-key home to determine the fetch
  endpoint instead of hardcoding `export.one-of-us.net`.

- [ ] **Sign-in with foreign-homed key**: accept sign-in from keys not homed at
  `export.one-of-us.net`. Requires knowing how to read delegate statements from a foreign
  home.

- [ ] **Document the ONE-OF-US.NET export API** as a reference that third parties may
  optionally follow. This does not make our API a prescribed standard — other organizations
  may design their own interfaces. See [export_api.md](export_api.md). *(Deferred.)*
