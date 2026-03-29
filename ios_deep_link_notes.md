# iOS Cold Start Deep Link Fix

## The Problem
Cold-start deep links (Universal Links like `https://one-of-us.net/sign-in?...`) fail to
trigger the sign-in flow on iOS via TestFlight. Warm-start (app in background) works fine.

## Root Cause
The `app_links` Flutter plugin (v6.4.1) only listens for Universal Links via AppDelegate
callbacks (`application(_:continue:restorationHandler:)`).

Modern Flutter iOS apps use `FlutterSceneDelegate` (configured in Info.plist's
`UIApplicationSceneManifest`). With the Scene-based lifecycle, iOS delivers cold-start
Universal Links to `scene(_:willConnectTo:options:)` on the SceneDelegate — NOT to
the AppDelegate. The plugin never receives the URL, so `getInitialLink()` returns `null`.

Warm start works because `scene(_:continue:)` gets forwarded differently by the engine.

## The Fix
`AppDelegate.swift` defines `AppLinksSceneDelegate`, a subclass of `FlutterSceneDelegate`
that overrides `scene(_:willConnectTo:options:)` to extract the URL from
`connectionOptions.userActivities` (Universal Links) and `connectionOptions.urlContexts`
(custom URL schemes like `keymeid://`) and calls `AppLinks.shared.handleLink(url:)` on
the plugin singleton.

`Info.plist` references `AppLinksSceneDelegate` instead of `FlutterSceneDelegate`.

### Why this is unusual
This is a workaround for a gap in the `app_links` plugin's iOS implementation. The plugin
should handle the Scene lifecycle natively but doesn't as of v6.4.1. If a future version
of `app_links` adds Scene lifecycle support, this subclass may become unnecessary.

## Supporting Changes
- `IPHONEOS_DEPLOYMENT_TARGET` raised from 13.0 to 15.5 (required to `import app_links`
  from Swift; already matched the Podfile)
- `@objc(AppLinksSceneDelegate)` annotation required so iOS can find the class from
  Info.plist (Swift classes need explicit ObjC names for plist resolution)
