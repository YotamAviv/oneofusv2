


Claim (replace) my old key

Describe the process to the user:

### Concise Summary: Identity Recovery Steps

1.  **Generate Identity Key**: Create a new key to serve as your new primary identity.
2.  **Re-sign Content**: Use your new key to re-publish all active trusts, blocks, and delegate assignments issued by the old key.
    - *In case your old key was compromised*: you'll be able to re-publish only what's valid.
3.  **Replace & Revoke**: Use your new key Publish a **Replace** and **Revoke** statement referencing your old key.
4.  **Web-of-Trust Verification**: At this point, your new key is unknown, and so you'll have to ask those who've vouched for you in the past to vouch for you again, this time referencing your new key.
5.  **Equivalence**: The network should now recognize this new key as you. Your old key will be recognized as an equivalent and will be visible in your **Equivalent Keys** section of the **Advanced Screen*.

### Implementation Plan: Identity Recovery Flow

**Phase 1: Navigation & Entry Points**
*   **Welcome Screen Update**: Replace the "Coming Soon" snackbar with navigation to the `ReplaceFlow`.
*   **Identification logic**: Scan QR code (similar to starting a new trust) to identify the old identity. 
*   **Advanced Screen Update**: Update the "ROTATE IDENTITY KEY" button to launch the same `ReplaceFlow`, with the "Old Identity" pre-filled from the current active key.

**Phase 2: User Interface Design (The Flow)**
A dedicated `ReplaceFlow` widget (or series of screens):

*   **Screen 1: The Description (The Intro)**
    *   **Purpose**: Educate the user on the recovery process using the text above.
    *   **Action**: Button "I UNDERSTAND, PROCEED".
*   **Screen 2: Identify Old Identity (Welcome Flow Only)**
    *   **Purpose**: Identify the identity being claimed.
    *   **Action**: Scan QR code of the old identity.
    *   **Verification**: Trigger a background check of Firestore to ensure the identity exists.
*   **Screen 3: History & Compromise Review**
    *   **Purpose**: Implement "Compromise Protection."
    *   **UI**: A scrollable list of **all** statements issued by the old identity (not reduced to distinct/latest).
    *   **Interaction**: User clicks on their **last valid statement**.
    *   **Visual Indicators**:
        - Statements newer than the selected "last valid" are light gray (invalid).
        - Statements older than the selected one that are not "distinct" (overridden by subsequent valid ones) are darker gray.
    *   **Action**: "START RECOVERY".
*   **Screen 4: Processing (The Work)**
    *   **UI**: Progress indicator with status updates.
    *   **Logic (Sequential)**:
        1. Generate a new `OouKeyPair` for the identity.
        2. For every valid statement (up to the selected last valid): Re-issue with the new key.
           - Preserve everything: same verb, subject, moniker, comment, delegates, and `revokeAt`, but **not** `time` (use the current time).
           - Do not re-sign and publish overriden (not distinct) statements.
           - Make sure to issue the statements preserving order. State them from oldest (oldest but distict) to newest.
        3. Issue a final `Replace` + `Revoke` statement referencing the old key.
        4. Switch the app's internal state to the new key.
*   **Screen 5: Success & Mobilization**
    *   **Purpose**: Final confirmation.
    *   **Content**: "Your new key is active. Now, contact your network to get new vouches."
    *   **Action**: "GO TO HOME".

**Phase 3: Technical Implementation Details**
*   **Directory**: `lib/features/replace/`.
*   **Keys logic**: Current `Keys` class functionality should suffice without major modifications.
*   **Data retrieval**: Utilize `StatementSource` / `DirectStatementSource` with non-distinct fetching to retrieve the full audit log of the old key.
*   **Transactionality**: Ensure the formal `Replace` statement is only published after the full history restatement is confirmed.
