# Google Play Store Deployment & Testing Tracks

This document outlines the process for deploying the ONE-OF-US.NET phone app to the Google Play Store and using testing tracks for validation.

## 1. Release Configuration

To deploy to the Play Store, we must transition from debug keys to a production signing key.

### 1.1. Signing Configuration
- Create a `key.properties` file (ignored by Git) containing:
    - `storePassword`
    - `keyPassword`
    - `keyAlias`
    - `storeFile` (path to your `.jks` file)
- Update `android/app/build.gradle.kts` to read these properties.

### 1.2. App Bundle (AAB)
- Use `flutter build appbundle` to generate the release artifact.

## 2. Play Store Tracks

Google Play Console provides several tracks to "validate and be less nervous."

### 2.1. Internal Testing Track
- **Purpose**: Quickest way to get the app on a few devices (up to 100 testers).
- **Validation**: No Play Store review is required for initial internal builds.
- **Usage**: Use this to verify "Magic" (App Links) and Firebase connectivity on real devices.

### 2.2. Closed Testing (Alpha)
- **Purpose**: Testing with a larger, specific group.
- **Validation**: Requires a full initial review by Google.

### 2.3. Open Testing (Beta)
- **Purpose**: Public testing before production.

## 3. Validation Checklist

To "be less nervous" during validation, we must verify:
- [ ] **App Links (The "Magic")**: Does tapping a `one-of-us.net` link on a real device open the app?
- [ ] **Secure Storage**: Can V2 read the Identity Key created by V1? (Requires using the same `sharedPreferencesName` or `groupId` if applicable).
- [ ] **Firestore**: Does the production build have the correct `google-services.json` and permissions to read/write statements?
- [ ] **Play Integrity API**: Ensure the app is running in a genuine environment (prevents bots/tampering).
