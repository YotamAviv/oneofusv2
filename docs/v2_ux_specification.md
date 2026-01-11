# UX Specification: ONE-OF-US.NET Phone App (V2)

This document outlines the user experience and interface strategy for the V2 phone app, focusing on simplicity for new users while providing clear paths for advanced management.

## 1. Guiding Principles

- **Simplicity First**: The primary flow for new users should be frictionless: Vouch for friends, Sign into services (Nerdster).
- **Progressive Disclosure**: Advanced features (blocking, key replacement, complex revocations) are tucked away in an "Advanced" or "Manage" section.
- **Guided Workflows**: Complicated processes are handled by "Wizards" that explain the consequences of actions.
- **Active Stewardship**: The app encourages being a good participant by highlighting areas that need attention.

## 2. Information Architecture

The app uses a `BottomNavigationBar` with three main sections:

1.  **Home / Network**: Focuses on your immediate circle and the "health" of your vouching.
2.  **Scan / Action**: The central FAB (Floating Action Button) for scanning QR codes (Vouching or Signing-in).
3.  **My Identity**: Managing your own keys, sharing your identity, and viewing your own statement history.

## 3. Core Workflows

### 3.1. The "First Vouch" (Simple)
- User taps Scan.
- Scans a friend's QR code.
- Screen shows: "Vouch for [Moniker]?" with a simple "Yes/No".
- Advanced options (domain, comment) are hidden under a "More Options" toggle.

### 3.2. Signing into Nerdster (Simple)
- User taps Scan.
- Scans Nerdster sign-in QR.
- Screen shows: "Sign into Nerdster?"
- App handles key generation and delegation automatically in the background.

### 3.3. Key Replacement (Guided/Advanced)
- Located in "My Identity" -> "Advanced".
- **Step 1: Warning**: Explain that this is for when a key is lost or compromised.
- **Step 2: Selection**: "What happened?" (Lost phone vs. Compromised key).
- **Step 3: Revocation Point**:
    - Recommend "Revoke everything" (`<since always>`) if the key was compromised.
    - Offer to "State everything it had" by fetching old statements and re-issuing them with the new key (Careful: only if they still trust those people).
- **Step 4: Confirmation**: High-friction confirmation (e.g., typing "REPLACE") to prevent accidents.

## 4. Stewardship & Health Check

The "Home" screen isn't just a list; it's a dashboard for your network health.

### 4.1. Attention Items (Prioritized)
- **Reciprocity**: "You vouched for Alice, but she hasn't vouched for you yet."
- **Stale Vouches**: "You vouched for Bob, but he has replaced his key. You should update your vouch to his new key."
- **Security Alerts**: "Charlie (who you vouched for) has been blocked by 3 people you trust." (Social discovery of bad actors).
- **Blocks**: "Dave has blocked you." (Visible only to the user, prompts reflection or action).

### 4.2. Backups
- Persistent but non-intrusive reminder: "Your keys are only on this phone. [Back them up now]."

## 5. Visual Language

- **Trust (Green)**: Vouching, active identities.
- **Attention (Yellow/Orange)**: Stale vouches, missing reciprocity, unbacked-up keys.
- **Danger (Red)**: Blocks, compromised keys, high-friction actions.
- **Advanced (Gray/Outline)**: Technical details, raw JSON, tokens.
