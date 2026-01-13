# Session Summary

## Human plan for sooner rather than later:
- Get going on play store tracks or whatever so that I can validate, be less nervous
  - [DONE] document Play Store tracks or whatever
  - [DONE] read / write same secure storage, access my current private key
  - [IN PROGRESS] "magic" (Deep Linking) progress, get nerdster.org webapp to carry out a back and forth
  - [TODO] Play Protect.. read/write Firestore database
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
The primary goal is to rewrite the `oneofus` mobile app (V2) to improve its user interface and architecture, while maintaining compatibility with the existing data and "legacy" app versions.

## Current Status
- **Identity Restoration**: Successfully proven that V2 reads the V1 private identity key from secure storage.
- **Visual Foundation**: "Luxury Linen" card aesthetics locked and componentized into `IdentityCardSurface`.
- **Deep Linking**: Removed `https` App Links to favor heterogeneous Custom Schemes. `oneofus://` is the current placeholder.
- **Release Ready**: Build upgraded to Java 17 and 16 KB page support; production signing configured; version 80.

## Next Steps
1. **Stable State Manager**: Implement logic to drive the pulsing dot based on network health and backup status.
2. **V2 Data Layer**: Complete `DirectFirestoreSource` to fetch real statement chains.
3. **Encounter Logic**: Implement the QR scanner and the "Vouch" workflow.
