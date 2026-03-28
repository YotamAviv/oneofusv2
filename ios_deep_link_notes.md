# iOS Cold Start Deep Link Debugging Notes

## The Issue
Cold starts from deep links (both Universal Links like `one-of-us.net` and custom schemes like `keymeid://`) are failing to trigger the sign-in/vouch flow on iOS via TestFlight. We already updated the Flutter code in `app_shell.dart` to synchronously attach the `uriLinkStream` listener to ensure events aren't missed during startup, but it still fails.

## Hypothesis
The issue is likely happening at the native iOS layer or within the `app_links` plugin itself before the URL ever reaches Dart code.

## Debugging Steps for the Mac
1. Plug the iPhone into the Mac via USB.
2. Open the Xcode workspace: `ios/Runner.xcworkspace`.
3. Select the physical iPhone as the deployment target and run the app (Product > Run).
4. Once it launches, **terminate the application** (swipe up from the bottom and swipe the app away).
5. Open the **Notes** app, **Safari**, or **Messages** and tap one of your sign-in deep links or vouch links to trigger a cold start.
6. Observe the **Xcode Console Output** at the bottom of the screen.

## What to Look For in the Console
- **Native Method Invocations:** Look for the AppDelegate methods that handle deep links. 
  - For `keymeid://` links, look for `application(_:open:options:)`.
  - For Universal Links, look for `application(_:continue:restorationHandler:)`.
- **Plugin Activity:** Look for any output from the `app_links` plugin. Does it receive the URL? Does it report sending it to the Flutter engine?
- **Flutter Errors:** Are there any Dart exceptions or Flutter Engine errors printing just as the app wakes up?
- **Timing Issues:** Does the link arrive before the Flutter engine is fully initialized, causing it to be dropped?

*(Do not commit this file. Feel free to delete it once you're on the Mac!)*
