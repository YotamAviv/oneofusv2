# Paradigm Decisions

## Rejection of App Links (https)
We have decided to fully reject **Android App Links** (the `https://one-of-us.net` mechanism).
- **Reasoning**: App Links are tied to a single domain owner. This hard-wired dependency contradicts the **heterogeneous paradigm** of ONE-OF-US.NET, where no single domain should act as a gatekeeper or mandatory provider.
- **Action**: All `https` intent-filters have been removed from the application manifest.

## Custom URI Schemes
To facilitate decentralized discovery and provider-neutral handshakes, we will use **Custom URI Schemes**.
- **The Protocol**: **`keymeid://`** has been selected as the official paradigm scheme.
- **Vibe**: It combines "Key," "Me," and "ID" into a distinctive, personal compound word that avoids collision with generic apps.
- **Status**: Registered in the manifest and implemented in the handshake listener.

## Deep Linking Lessons (Emulator)
We discovered that the Android emulator's intent registry can become stale. Decisive verification requires:
1. `Wipe Data` on the emulator.
2. Explicit `package` attributes in the manifest.
3. Separate `intent-filter` blocks for each scheme.
4. Testing via `adb shell am start` to bypass browser security policies.
