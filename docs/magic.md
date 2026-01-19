# Deep Link Technologies: Magic vs. Universal

This document explores the two primary ways mobile applications are launched from web browsers and why the "Magic Sign-in" experience varies across platforms.

## 1. Custom URL Schemes (The "Magic" Link)
**Example:** `keymeid://signin?parameters=...`

This is the traditional method for deep linking. An app registers a unique "scheme" (like `keymeid`) within its operating system manifest. When the OS encounter a link with that scheme, it looks for an app that handles it.

### Advantages
- **Simplicity**: No server-side configuration required.
- **Openness**: Any developer can define a scheme without permission from a domain owner.

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

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "net.oneofus.app",
      "sha256_cert_fingerprints": [
        "DB:81:58:06:A3:DE:7A:D5:5E:7C:27:18:97:B1:B6:D1:82:3C:EC:D7:8A:3A:D1:2F:65:C9:E0:6B:03:82:1D:1E"
      ]
    }
  }
]
```
*Note: The fingerprint above is for your **Debug** key. You must eventually add your **Production** SHA256 fingerprint (found in the Play Console under Setup > App Integrity).*

### 3.2. iOS (`apple-app-site-association`)
**Path:** `https://one-of-us.net/.well-known/apple-app-site-association`
**Important:** This file must be served with `Content-Type: application/json` and **no file extension** in the URL.

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YOUR_TEAM_ID.net.oneofus.app",
        "paths": [ "/sign-in", "/sign-in/*", "/replace/*" ]
      }
    ]
  }
}
```
*How to find YOUR_TEAM_ID:*
1. Sign in to the [Apple Developer Portal](https://developer.apple.com/account).
2. Look under **Membership Details** for the "Team ID" (a 10-character alphanumeric code).
