import 'package:intl/intl.dart';

final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);

/// Checks if the Map represents a valid public key (JWK).
bool isPubKey(Map<String, dynamic> json) {
  return json.containsKey('x') && json.containsKey('crv') && json['kty'] == 'OKP';
}

/// Extracts a public key from a QR / invitation-link payload.
///
/// Understands two formats:
///   Old (current): bare key JSON  {"crv":...,"kty":"OKP","x":...}
///   New (Key Federation Phase 1): {"key": {...}, "home": "..."}
///
/// If `home` is present it must be a known ONE-OF-US.NET value; any other
/// value throws [UnsupportedError] so call-site catch blocks can surface
/// a user-friendly error (Key Federation not yet implemented).
///
/// Returns the key Map, or null if the payload is not a recognized format.
Map<String, dynamic>? extractKeyFromPayload(Map<String, dynamic> json) {
  if (isPubKey(json)) return json; // old format — no home field, nothing to check
  final dynamic key = json['key'];
  if (key is Map<String, dynamic> && isPubKey(key)) {
    // New format — validate home before accepting.
    final dynamic home = json['home'];
    if (home != null) {
      const knownHomes = {'one-of-us.net', 'export.one-of-us.net'};
      if (!knownHomes.contains(home)) {
        throw UnsupportedError(
          'Key Federation not yet supported (home: $home). '
          'Update your app to vouch for keys from other organizations.',
        );
      }
    }
    return key;
  }
  return null;
}

final DateFormat datetimeFormat = DateFormat.yMd().add_jm();

String formatUiDatetime(DateTime datetime) {
  return datetimeFormat.format(datetime.toLocal());
}
