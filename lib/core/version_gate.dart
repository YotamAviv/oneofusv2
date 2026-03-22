import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'config.dart';

class VersionGate {
  static const _key = 'minimum_version';

  /// Fetches the minimum required app version from Firebase Remote Config in
  /// the background. Calls [onBlocked] if the running version is below it.
  /// Fails open (silently) on any error or timeout.
  static void checkInBackground(VoidCallback onBlocked) {
    if (Config.fireChoice == FireChoice.fake) return;
    _check(onBlocked);
  }

  static Future<void> _check(VoidCallback onBlocked) async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({_key: '0.0.0'});
      await remoteConfig.fetchAndActivate();

      final minimum = remoteConfig.getString(_key);
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      if (_isBelow(current, minimum)) {
        debugPrint('[VersionGate] Blocked: $current < $minimum');
        onBlocked();
      } else {
        debugPrint('[VersionGate] OK: $current >= $minimum');
      }
    } catch (e) {
      debugPrint('[VersionGate] Error: $e (failing open)');
    }
  }

  /// Returns true if [version] is strictly below [minimum].
  static bool _isBelow(String version, String minimum) {
    try {
      final v = _parse(version);
      final m = _parse(minimum);
      for (var i = 0; i < 3; i++) {
        if (v[i] < m[i]) return true;
        if (v[i] > m[i]) return false;
      }
      return false; // equal — not blocked
    } catch (_) {
      return false; // fail open on parse error
    }
  }

  static List<int> _parse(String v) {
    // Strip build number if present (e.g. "2.0.16+109" -> "2.0.16")
    final bare = v.contains('+') ? v.split('+').first : v;
    final parts = bare.split('.');
    return [
      int.parse(parts[0]),
      int.parse(parts.length > 1 ? parts[1] : '0'),
      int.parse(parts.length > 2 ? parts[2] : '0'),
    ];
  }
}
