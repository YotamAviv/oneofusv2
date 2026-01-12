# Session Summary

## Human plan for sooner rather than later:
- Get going on play store tracks or whatever so that I can validate, be less nervous
  - document Play Store tracks or whatever
  - read / write same secure storage, access my current private key
  - "magic" (Android App Links) progress, get nerdster.org webapp to carry out a back and forth
  - Play Protect.. read/write Firestore database
- Document "Stable State"
  - notification (pulsing dot) should be active unless we're in stable state
  - our directly trusted associates
    - none block or replace our key
  - our key is backed up (we claim)
  - our equivalent keys
    - all are fully claimed replaced and revoked <since always> by our active key 
  - our delegate keys
    - all are delegated (irregardless of revoked status) by our active key

## Goal

The primary goal is to rewrite the `oneofus` mobile app (V2) to improve its user interface and architecture, while maintaining compatibility with the existing data and "legacy" app versions. The new version should be more user-friendly, attractive, and easier to maintain.

## Key Documents

1.  **`docs/core_specification.md`**: Describes the `one-of-us.net` paradigm.
2.  **`docs/requirements.md`**: Outlines functional requirements.
3.  **`docs/v2_ux_specification.md`**: Codifies the "Physical Utility" philosophy and the "Luxury Linen" Identity Card aesthetic.
4.  **`lib/card_config.dart`**: Contains pixel-accurate geometry for the Identity Card background.
5.  **`docs/play_store_deployment.md`**: Guide for release signing and testing tracks.

## Architectural Direction

-   **UI Rewrite:** Ultra-minimalist "Identity Card" interface. Swiping navigation (Me → People → Services → Info → DEV). Orientation-aware.
-   **Data Layer:** Centered around `oneofus_common` for shared crypto/models and a new V2 data layer (`StatementSource`, `DirectFirestoreSource`).
-   **Code Sharing:** `oneofus_common` package is created and linked as a path dependency.
-   **App Links:** Configured via `AndroidManifest.xml` and verified by `https://one-of-us.net/.well-known/assetlinks.json`.

## Current Status

-   **Visual Foundation:** Implemented the "Luxury Linen" business card metaphor with precise geometry.
-   **Identity Manager:** Initialized to read V1 secure storage (`one-of-us.net` key).
-   **Developer Mode:** Enabled by 7-clicks on version; includes a DEV diagnostics page showing raw keys.
-   **Release Ready:** `build.gradle.kts` updated for production signing; version code incremented to 78.
-   **Build Environment:** Upgraded to Java 17 to resolve obsolete source warnings.

## Next Steps

1.  **Magic (App Links):** Add `app_links` dependency and implement the URL listener to handle Nerdster sign-ins.
2.  **Stable State Manager:** Implement logic to drive the pulsing dot based on network health and backup status.
3.  **V2 Data Layer:** Complete `DirectFirestoreSource` to fetch real statement chains.
4.  **Encounter Logic:** Implement the QR scanner and the "Vouch" workflow.
