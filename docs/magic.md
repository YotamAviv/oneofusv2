# Deep Link Technologies: Magic vs. Universal

## Current Status (Jan 29, 2026)
Both apps have been pushed to production on the Google Play Store and Apple App Store.
Currently, Universal Links (iOS) and App Links (Android) are not working for either platform.
- **Android**: Only works if the user manually specifies the app to open the link. Custom URL Schemes seem to work consistently.
- **iOS**: Universal links fail in both Safari and Chrome.

The priority is to resolve the iPhone issues, although debugging is primarily done in a Linux/Android environment.

This document explores the two primary ways mobile applications are launched from web browsers and why the "Magic Sign-in" experience varies across platforms.

## 1. Custom URL Schemes (The "Magic" Link)
**Example:** `keymeid://signin?parameters=...`

This is the traditional method for deep linking. An app registers a unique "scheme" (like `keymeid`) within its operating system manifest. When the OS encounter a link with that scheme, it looks for an app that handles it.

### Advantages
- **Simplicity**: No server-side configuration required.
- **Openness**: Any developer can define a scheme without permission from a domain owner.
The ONE-OF-US.NET paradigm claims "heterogeneous", and so this is our preferred path.

### Disadvantages
- **Security (Hijacking)**: Any app can register any scheme. If two apps register `keymeid`, the OS doesn't know which is the "real" one, leading to potential data theft.
- **Privacy**: Used by trackers to probe which apps are installed on a device.
- **Fragility**: If the app isn't installed, the link simply fails or does nothing in the browser.
- **Platform Friction**: Apple (iOS/Safari) intentionally adds friction (e.g., the "Allow this site to open..." prompt) to discourage this method in favor of secure alternatives.

## 2. Universal Links (iOS) & App Links (Android)
**Example:** `https://one-of-us.net/sign-in?data=...`

This is the modern, secure standard. Instead of a custom scheme, the app uses standard HTTPS URLs.

### How it Works
1.  **Verification**: The platform (iOS or Android) verifies that the app is legally associated with the domain.
2.  **Hosting**: The domain owner must host a small JSON file (AASA for iOS, AssetLinks for Android) in a specific directory (`/.well-known/`).
3.  **Automatic Launch**: Because the association is cryptographically verified, the OS will launch the app **immediately** without a prompt if the app is installed.

### Advantages
- **Security**: Prevent app hijacking; only the verified app for `one-of-us.net` can receive the data.
- **Zero Friction**: No "Allow" prompts in Safari or Chrome.
- **Graceful Fallback**: If the app isn't installed, the link opens the project's website normally.
- **Professionalism**: Handled by the OS as a first-class citizen.

### Disadvantages
- **Complexity**: Requires hosting two small configuration files on the web server.

## 3. Hosting Setup for one-of-us.net

To enable Universal/App Links, you must host two files on your web server at the following paths.

### 3.1. Android (`assetlinks.json`)
**Path:** `https://one-of-us.net/.well-known/assetlinks.json`

(File contents are now maintained in source control).

*Note: The fingerprint above is for your **Debug** key. You must eventually add your **Production** SHA256 fingerprint (found in the Play Console under Setup > App Integrity).*

### 3.2. iOS (`apple-app-site-association`)
**Path:** `https://one-of-us.net/.well-known/apple-app-site-association`
**Important:** This file must be served with `Content-Type: application/json` and **no file extension** in the URL.

(File contents are now maintained in source control).

*How to find YOUR_TEAM_ID:*
1. Sign in to the [Apple Developer Portal](https://developer.apple.com/account).
2. Look under **Membership Details** for the "Team ID" (a 10-character alphanumeric code).

## 4. Linux Desktop & Android Emulator Development Setup

When developing on a Linux Desktop with a local Android Emulator, clicking a `keymeid://` Magic Link in the Desktop Browser (e.g., while testing the Flutter Web client) will fail because the Linux host doesn't know how to route that scheme to the Emulator.

To solve this, we implement a bridge that intercepts the URL on Linux and forwards it to the Emulator via ADB.

### 4.1. The Bridge Script
Create the script in your user binary directory at `~/.local/bin/oneofus-forward-link.sh`:

```bash
#!/bin/bash
# Receives a URL (keymeid://...) as $1 and forwards it to the Android Emulator via ADB

URL="$1"
# Verify ADB is available and an emulator is connected
if command -v adb &> /dev/null; then
    adb shell am start -a android.intent.action.VIEW -d "$URL"
fi
```

Make it executable: `chmod +x ~/.local/bin/oneofus-forward-link.sh`

### 4.2. Linux Desktop Entry
Register the custom scheme handler by creating `~/.local/share/applications/oneofus-link-handler.desktop`.
*Note: The `Exec` path must be absolute (no `~`). Replace `/home/YOUR_USER` with your actual home directory.*

```ini
[Desktop Entry]
Name=OneOfUs Link Handler
Exec=/home/YOUR_USER/.local/bin/oneofus-forward-link.sh %u
Type=Application
Terminal=false
MimeType=x-scheme-handler/keymeid;
```

Apply the changes:
```bash
update-desktop-database ~/.local/share/applications/
xdg-mime default oneofus-link-handler.desktop x-scheme-handler/keymeid
```

### 4.3. Networking & Encoding Adjustments
1.  **Emulator Networking**: The Flutter Web client (running on host) cannot contact `localhost` inside the Android app. The app must be configured to connect to `http://10.0.2.2:5001` (the emulator's alias for the host loopback interface) instead of `127.0.0.1`.
2.  **Encoding**: The `keymeid://` scheme requires parameters to be Base64Url encoded (Standard Base64 with URL-safe characters and no padding). Ensure the generating client sends:
    `keymeid://signin?parameters=<Base64UrlEncodedJson>`
