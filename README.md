# ONE-OF-US.NET (V2)

The reference mobile implementation for the **ONE-OF-US.NET** decentralized identity paradigm.

## Overview

ONE-OF-US.NET is a system for establishing human identity and trust without central authorities. It turns your phone into a secure vault for your digital identity, allowing you to participate in a global Web of Trust via signed cryptographic statements.

The primary functions of this app are:
1.  **Vouching**: Scan other users' Identity Cards to assert they are "human, capable, and acting in good faith."
2.  **Delegation**: Securely sign in to third-party services (like [Nerdster](https://nerdster.org)) by creating verifiably linked delegate keys.
3.  **Governance**: Manage your trust network by blocking bad actors or revoking/clearing previous statements.
4.  **Recovery**: Support for identity key replacement while maintaining network continuity.

## Core Concepts

- **Identity Key**: Your primary long-term cryptographic key, kept encrypted on your device.
- **Statement**: A signed JSON object representing a trust relationship (Trust, Block, Replace, Delegate, or Clear).
- **Web of Trust**: A decentralized graph where "humans vouch for humans," enabling sybil-resistant services.

## Architecture

- **Framework**: Flutter (cross-platform Android/iOS).
- **Security**: Local keys stored in secure hardware; P2P key exchange via QR and deep links.
- **Data Layer**: Statements are published to a public Cloud Functions/Firestore registry.
- **Parity**: Matches the behavior of the legacy [nerdster12](../nerdster12) implementation but with a modern UX.

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio / Xcode

### Installation
1.  Clone this repository.
2.  Run `flutter pub get`.
3.  Run `flutter run`.

## Documentation

For deep technical details, see the `docs/` folder:
- [Core Specification](docs/core_specification.md): The underlying paradigm and state machine.
- [Technical Design](docs/technical_design.md): Implementation details of the V2 app.
- [V2 UX Specification](docs/v2_ux_specification.md): Design philosophy and user flow.
- [Seamless Sign-in](docs/seamless_signin_implementation.md): How delegation and deep-linking work.

---
*Human, capable, acting in good faith.*
