# Apple App Store Deployment (iOS)

Process and gotchas for building/shipping the ONE-OF-US.NET iOS app to the
Apple App Store. Companion to [play_store_deployment.md](play_store_deployment.md)
(Android) and [flutter_dev_setup.md](flutter_dev_setup.md) (toolchain/upgrade notes).

The iOS build happens on the **Mac**, a different machine than the Linux dev/
Android-build box. Notes here assume you've just been building/releasing on
Linux and are switching over.

## 0. First time using Claude/AI in the Mac environment

Claude has **not** been used in the Mac VSCode workspace before (as of
2026-07-13). There is no machine-specific setup captured for it there. When you
start: have it read this file and `flutter_dev_setup.md` first, then paste
`flutter doctor -v` so it can confirm versions before you spend a build.

## 1. Toolchain parity — do this first

The Android release you validated was built on **Flutter 3.44.6 / Dart 3.12.2**.
Build the iOS store binary on the **same** Flutter version so you ship what you
tested.

- **Update Flutter on the Mac to 3.44.6.** macOS has a real `curl`, so the
  snap-curl problem from the Linux box does NOT apply here — it's a normal
  `flutter upgrade` (or `git checkout 3.44.6` for a git install).
  - This is required, not just advisable — and nothing to edit. `pubspec.yaml`
    is one shared file (same for iOS/Android/web); it already declares
    `sdk: ^3.8.1`, and the committed `pubspec.lock` was resolved under Dart
    3.12.2. That constraint is what *forces* the Flutter update: an older Mac
    Flutter (Dart < 3.8.1) will fail `flutter pub get` or silently re-resolve
    and drift. The fix is entirely on the Mac's Flutter, not the file.
- **Check Xcode** via `flutter doctor` — Flutter 3.44 (mid-2026) wants a recent
  Xcode. If it's been a while, an outdated Xcode is the *most likely* blocker,
  more than Flutter itself. Update it before building.
- After updating: `flutter pub get`, then `cd ios && pod install` (add
  `--repo-update` if a pod fails to resolve).

## 2. Build & release

Script: `bin/build_ipa.sh` (analog of `bin/build_release.sh`). It:
- derives the **build number from git commit count** (`git rev-list --count HEAD`)
  — never bump it by hand;
- reads the **version name** from `pubspec.yaml` line 5 (`version: 2.0.xx+0`) —
  bump this yourself only when you want a new user-facing version; Play/App Store
  build-number spaces are independent;
- **aborts unless** `FireChoice.prod` in `lib/core/config.dart`;
- **aborts if** `builds/<build>/` already exists;
- runs `flutter build ipa --build-number=<build>`, saves the `.ipa` to
  `builds/<build>/`, then tags and pushes `v<version>+<build>`.

### GOTCHA: the `builds/<N>` guard collides across platforms

Because the build number is the shared commit count, building **Android and iOS
at the same commit collides**: `build_release.sh` already created `builds/324/`
and tag `v2.0.43+324` for the Android release. Running `build_ipa.sh` at that
same commit will hit `ERROR: builds/324 already exists` and abort.

**Fix:** make one new commit before building iOS (any real change, e.g. a version
bump). That advances the count (→ 325+) and `build_ipa.sh` produces `…+325`.
Different build numbers per platform are expected and fine.

## 3. Signing / provisioning

Apple certificates and provisioning profiles **expire**. If it's been a while,
expect Xcode/`build ipa` to complain and be ready to refresh them (Apple Developer
account → Certificates, Identifiers & Profiles). This is unrelated to the Flutter
upgrade but is the classic reason an iOS build "doesn't just work."

## 4. Why the upgrade should be low-risk on iOS

For the 3.44.6 upgrade specifically, the native iOS surface barely moved:
- iOS min deployment target already **15.5** (Podfile + xcodeproj).
- Firebase pods already at **12.9.0**, `cloud_firestore` at 6.1.3 in
  `ios/Podfile.lock` — matches the post-upgrade `pubspec.lock`.
- The upgrade changed only ~2 Dart deps in oneofus; the ListTile→Material fix is
  pure Dart, platform-agnostic.

So the real risks are environmental (Flutter/Xcode versions, signing), not the
app code. Run `pod install` and let CocoaPods re-lock; large native churn is not
expected.

## 5. Pre-flight checklist

- [ ] Flutter on Mac == 3.44.6 (`flutter --version`)
- [ ] `flutter doctor` clean; Xcode recent enough
- [ ] `flutter pub get` succeeds
- [ ] `cd ios && pod install` succeeds
- [ ] `FireChoice.prod` set in `lib/core/config.dart`
- [ ] One fresh commit made since the Android `builds/324` release (clears the guard)
- [ ] Apple signing/provisioning valid
- [ ] `bin/build_ipa.sh` → uploads via Transporter/Xcode to App Store Connect
