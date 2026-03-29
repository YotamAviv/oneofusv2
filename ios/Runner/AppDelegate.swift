import Flutter
import UIKit
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Custom SceneDelegate that forwards cold-start deep links to the app_links plugin.
///
/// FlutterSceneDelegate receives Universal Links via scene(_:willConnectTo:options:)
/// on cold start, but the app_links plugin only listens on AppDelegate callbacks.
/// This subclass bridges that gap by extracting the URL from connectionOptions
/// and calling handleLink on the plugin singleton.
@objc(AppLinksSceneDelegate)
class AppLinksSceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // Forward Universal Links from cold start
    for userActivity in connectionOptions.userActivities {
      if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
         let url = userActivity.webpageURL {
        AppLinks.shared.handleLink(url: url)
      }
    }

    // Forward custom URL schemes from cold start
    for urlContext in connectionOptions.urlContexts {
      AppLinks.shared.handleLink(url: urlContext.url)
    }
  }
}
