# Paradigm Decisions

## Rejection of App Links (https)
We have decided to fully reject **Android App Links** (the `https://one-of-us.net` mechanism).
- **Reasoning**: App Links are tied to a single domain owner. This hard-wired dependency contradicts the **heterogeneous paradigm** of ONE-OF-US.NET, where no single domain should act as a gatekeeper or mandatory provider.
- **Action**: All `https` intent-filters have been removed from the application manifest.

## Custom URI Schemes
To facilitate decentralized discovery and provider-neutral handshakes, we will use **Custom URI Schemes**.
- **Current Status**: Experimental support for `oneofus://` is in place to verify basic communication.
- **Search for Generic Name**: We are seeking a "hip" and brand-neutral scheme name that represents the **Identify and Delegate** action.
- **Candidates**:
  - `vouch://` (Current lead)
  - `notary://`
  - `attest://`
  - `key://`

## Deep Linking Lessons (Emulator)
We discovered that the Android emulator's intent registry can become stale. Decisive verification requires:
1. `Wipe Data` on the emulator.
2. Explicit `package` attributes in the manifest.
3. Separate `intent-filter` blocks for each scheme.
4. Testing via `adb shell am start` to bypass browser security policies.
