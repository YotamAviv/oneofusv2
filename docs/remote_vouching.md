# Remote Vouching

## Problem Statement

Currently, people can vouch for each other in the following ways:

*   **In Person**: Use the phone app to scan each other's public key QR code.
*   **Remote (Computer + Phone)**: Email the QR code to each other, open that email on a computer monitor, and scan that with their phone.
*   **Remote (Phone Only)**: Email or text the JSON key to each other, copy (as in copy/paste) that, initiate phone scanning, and use the PASTE option instead of scanning.

## The Challenge

We want to make it easier for users to vouch for each other remotely, specifically addressing these pain points:

*   **Copy-Paste Errors**: It is difficult to completely copy the JSON key text without intentionally or accidentally omitting a brace or other character/portion.
*   **Device Friction**: A person shouldn't have to know if the other person will be opening a text or email on a phone or a computer.
*   **Platform Friction**: A person shouldn't have to know if the other person has an iPhone or Android.

## Current Infrastructure

The phone app currently supports:

*   `keymeid://` scheme (working on Android).
*   `https://one-of-us.net` links (working on iPhone, less reliable on Android).

## Goals

Define a unified workflow or mechanism that leverages existing deep linking capabilities (or improves them) to allow seamless remote vouching regardless of the user's context.

## Proposals for Remote Vouching Improvements

### 1. Unified "Share Identity" Action

Instead of separate "Share as QR Image" and "Share as JSON Text" actions, provide a single smart "Share Identity" action (or "Vouch for Me") that sends a package designed to work in multiple contexts.

**Mechanism:**
*   Use `Share.shareXFiles` to send *both* the QR code image AND a text caption.
*   The text caption should include:
    *   A message: "Here is my ONE-OF-US.NET identity key."
    *   Raw (text) JSON key.
    *   QR code of JSON key.
    *   A Universal Link / App Link: `https://one-of-us.net/vouch?key=...` or a deep link `keymeid://vouch?key=...`.

**Pros:**
*   **One-stop shop:** The sender doesn't need to guess if the receiver is on desktop or mobile.
*   **Redundancy:** If the link fails, the QR code is attached. If the QR code is hard to scan (e.g., on the same phone), the link or JSON text works.

**Cons:**
*   **Platform variability:** Some receiving apps (e.g., SMS apps or email clients) might drop the text caption when an image is attached, or vice versa.
TODO: verify `share_plus` behavior on target platforms.

### 2. Deep Linking with "Magic Links"

Leverage the `https://one-of-us.net` domain to create a universal entry point.

**Concept:**
*   **Full Key** `https://one-of-us.net/vouch#<base64_url_encoded_json>`
    *   *Why Base64?* While stripped JSON (`{"x":"..."}`) is compact, characters like `{`, `}`, and `"` are not URL-safe. They are often percent-encoded (`%7B`, `%22`), making the link longer and "uglier" than Base64. More importantly, many SMS and chat apps break hyperlinks if they contain these characters. Base64 guarantees the link remains clickable.

**User Flow:**
*   **On Android (App Installed):** The intent filter intercepts this URL and opens the app directly to the "Vouch" screen, pre-filling the key.
*   **On iOS (App Installed):** Universal Links open the app similarly.
*   **On No App (Web Fallback):** The web page loads. Since deep linking reliability varies by platform, the page should present all available entry methods in an order optimized for the user's likely device:
    1.  **Launch App (Universal/App Link):** A button attempting the standard HTTPS link again.
    2.  **Launch App (Scheme):** A `keymeid://` button to trigger the custom scheme directly.
    3.  **Scan QR Code:** A prominent QR code for scanning (useful if opened on desktop).
    4.  **Copy Key:** A text box or copy button for the raw JSON, allowing the user to manually paste it into the app.

**Addressing the "Copying JSON" Difficulty:**
*   **Links are better:** The Magic Link creates a clickable artifact. Users are used to clicking links. This eliminates the selection/copy-paste friction entirely.
*   **If Text is required:** To make copying the JSON text easier in a text message, the app should format the share text so the JSON appears **last**, or effectively isolated, so "Copy Message" captures it cleanly without selecting the user's conversational text. However, "Select All" on a phone often grabs the whole message bubble. **This is why the Link approach is superior.**

### 3. Implementation Details for `ShareService`

Currently, `ShareService` has distinct methods. We can merge or augment them:

```dart
static Future<void> shareIdentityPackage() async {
  // 1. Generate QR Image
  final imageFile = await _generateQrFile(...);
  
  // 2. Generate Link/Text
  final String deepLink = "https://one-of-us.net/vouch#${base64_key}"; 
  final String jsonText = ...;
  final String message = "Vouch for me on ONE-OF-US.NET!\n\nLink: $deepLink\n\nKey:\n$jsonText";

  // 3. Share both
  await Share.shareXFiles([XFile(imageFile.path)], text: message);
}
```

### Recommendation

Prioritize **Proposal 2 (Magic Links)** as the primary sharing mechanism. It solves the device and platform friction seamlessly by behaving like a standard web link that "upgrades" to a native experience.

### 4. Image-Based Vouching (Scan from Gallery/Paste)

Users often receive QR codes on the *same* device they need to use for scanning (e.g., via email or chat). They cannot scan their own screen with the camera.

**Proposal:** Add functionality to interpret QR codes from static images.

1.  **"Select from Gallery" (Recommended):**
    *   **Workflow:** User saves the QR image to their photo gallery -> Opens Scanner -> Taps "Select Image" -> Picks file -> App analyzes image.
    *   **Feasibility:** High. The `mobile_scanner` library supports analyzing local files (`analyzeImage(path)`).
    *   **Pros:** Standard mobile workflow, reliable.

2.  **"Paste Image" (Clipboard):**
    *   **Workflow:** User copies image in email app -> Opens Scanner -> Taps "Paste" -> App analyzes clipboard image.
    *   **Feasibility:** Medium/Low. Standard Flutter `Clipboard` API primarily handles text. Accessing image data usually requires additional packages (like `pasteboard` or `super_clipboard`) and handling generic permissions.
    *   **Recommendation:** Stick to "Select from Gallery" initially, or rely on "Paste **Text**" (from the JSON or Link) which is already supported.

