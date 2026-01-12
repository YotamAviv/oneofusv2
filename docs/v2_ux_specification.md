# UX Specification: ONE-OF-US.NET (V2)

This document defines the interface for the V2 phone app, built on the physical metaphor of a high-end Notary Business Card.

## 1. Design Philosophy: "The Physical Utility"

- **Cross-Device Sharpness**: The layout is mathematically derived from the background image dimensions to ensure the "card" remains perfectly framed regardless of the device's aspect ratio.
- **Physical Metaphor**: Centered on a "Luxury Linen" Identity Card. This creates a sense of permanence and human trust.
- **Zero Clutter (Main)**: The primary screen is for encounters only. In landscape mode, all UI chrome is hidden except for the card and a private alert dot.
- **Privacy by Default**: Maintenance alerts are subtle pulsing dots that do not reveal details to bystanders.

## 2. Main Surface (The Identity Card)

The app displays a centered Identity Card (from `card_background.png`).
- **Geometry**:
    - The card itself is always fully visible with a configurable margin (default 2% top/bottom).
    - The background pattern around the card may spill off the screen edges to accommodate different aspect ratios.
- **Overlays (On the Card)**:
    - **QR Code**: A square, transparent QR of the public key, positioned on the left with 4% padding.
    - **"Me" Label**: Text positioned top-right, top-aligned with the QR code, with similar padding from the right edge of the card.

## 3. Navigation & Orientation

- **Landscape Mode**: "Clean Mode". Displays only the Card and the pulsing alert dot.
- **Portrait Mode**: "Dashboard Mode". Displays:
    - **Top Left**: Logo + ONE-OF-US.NET.
    - **Top Right**: Private pulsing alert dot.
    - **Bottom Center**: Elevated Encounter (Scan) button.
    - **Bottom Left**: Share button (QR, Email, Link).
    - **Bottom Right**: Management Hub (Drawer shortcut).
- **Gestures**: Horizontal swiping navigates between:
    - **Me** (Identity Card)
    - **People** (Trusted Identities)
    - **Services** (Authorized Delegates)
    - **Info** (Help, Advanced, Links)

## 4. Maintenance & Stewardship

- **Pulsing Indicator**: A red dot (top-right) pulses if the ledger needs attention. Tapping it navigates to the relevant maintenance view.
- **Snoozable Alerts**: High-integrity requirements (like backups) appear in the Management Hub or sub-pages and can be snoozed but not dismissed until resolved.
