NOTE: This is duplicated in the other project

# Key Visualization Specification

The `oneofus` application follows the visual language established by `nerdster` for representing cryptographic keys. This ensures users can intuitively understand the state and possession of keys at a glance.

## Core Visualization States

The visualization of a key (iconography and style) depends on two factors:
1.  **Possession**: Do we hold the private key locally?
2.  **Status**: Is the key valid (active/trusted) or void (revoked/blocked/replaced)?

### 1. Possession (Solid vs. Outlined)

*   **Solid (Filled) Icon**: Indicates **POSSESSION**. The private key for this identity or delegate is stored securely on the local device.
    *   *Example*: My Identity Key, My Active Delegate Key.
*   **Outlined Icon**: Indicates **NO POSSESSION**. The app knows about this public key (e.g., from a statement) but does not hold the corresponding private key.
    *   *Example*: A friend's identity key, A delegate key I created on another device, A delegate key I have deleted/lost.

### 2. Status (Icon Shape)

*   **Standard Key (`Icons.key`)**: Indicates **VALID/ACTIVE** status.
    *   Used for: Active Delegates, Trusted Identities.
*   **Voided Key (`Icons.key_off`)**: Indicates **VOID/INVALID** status.
    *   Used for: Revoked Delegates, Blocked Identities, Replaced (Superseded) Identities.

## Matrix

| Status | Possession (Has Private Key) | No Possession (No Private Key) |
| :--- | :--- | :--- |
| **Active / Trusted** | **Solid Key** (`Icons.key`) | **Outlined Key** (`Icons.key_outlined`) |
| **Revoked / Blocked** | **Solid Void Key** (`Icons.key_off`) | **Outlined Void Key** (`Icons.key_off_outlined`) |

## Color Coding

Colors are determined by the relationship (Verb) context:

*   **Trust (Identity)**: Teal/Green (`0xFF00897B`)
*   **Delegate**: Blue (`Colors.blue.shade700`)
*   **Block**: Red (`Colors.red.shade700`)
*   **Replace**: Teal/Green (Identity context) or Orange (Action context)

## Tooltips

Hovering or long-pressing the key icon should reveal a tooltip explaining the state (e.g., "Revoked: This delegate key is no longer authorized" or "Delegate: A key authorized to act on your behalf").
