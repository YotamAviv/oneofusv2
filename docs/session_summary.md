# Session Summary

## Human plan for sooner rather than later:
- Get going on play store tracks or whatever so that I can validate, be less nervous
  - document Play Store tracks or whatever
  - read / write same secure storage, access my current private key
  - "magic" (what do you call that thing?) progress, get nerdster.org webapp to carry out a back and forth
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

## Architectural Direction

-   **UI Rewrite:** Ultra-minimalist "Identity Card" interface. Swiping navigation (Me → People → Services → Info). Orientation-aware (Landscape is clean; Portrait shows Dashboard chrome).
-   **Data Layer:** Centered around `oneofus_common` for shared crypto/models and a new V2 data layer (`StatementSource`, `DirectFirestoreSource`).
-   **Code Sharing:** `oneofus_common` package is created and linked as a path dependency.
-   **App Links:** Configured via `AndroidManifest.xml` and verified by `https://one-of-us.net/.well-known/assetlinks.json`.

## Current Status

-   **Visual Foundation:** Implemented the "Luxury Linen" business card metaphor.
-   **Precision Geometry:** The card is mathematically framed to maintain a 2% safety margin on any device ratio. QR and "Me" label are accurately positioned.
-   **Navigation:** `PageView` implemented for swiping between dashboard sections.
-   **Privacy Alerts:** Pulsing red dot alert (top-right) implemented for private maintenance notifications.
-   **Shared Package:** `oneofus_common` is set up with `Jsonish`, `Statement`, and `Crypto` logic.

## Next Steps

1.  **Identity Manager:** Implement `IdentityManager` to generate, persist (secure storage), and manage the notary chain.
2.  **V2 Data Layer:** Complete `DirectFirestoreSource` to fetch real network health data (reciprocity, stale keys).
3.  **Encounter Logic:** Implement the QR scanner and the "Vouch" / "Sign-in" workflows.
4.  **Guided Wizards:** Build the "Lost Phone" recovery wizard and the "Compromised Key" replacement wizard.
5.  **Remote Vouching:** Implement the option to vouch for someone without a physical encounter.

## Session Notes
- Branding centered in top-left (Logo + Serif text).
- "Me" label top-right on the card, top-aligned with the QR code.
- Landscape mode is a dedicated "Show this to others" mode with zero clutter.
- Swiping is the primary navigation between network views.
