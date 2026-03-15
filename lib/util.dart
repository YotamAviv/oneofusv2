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
/// The `home` field in the new format is intentionally ignored until
/// Key Federation support is implemented.
///
/// Returns the key Map, or null if the payload is not a recognized format.
Map<String, dynamic>? extractKeyFromPayload(Map<String, dynamic> json) {
  if (isPubKey(json)) return json; // old format
  final dynamic key = json['key'];
  if (key is Map<String, dynamic> && isPubKey(key)) return key; // new format, ignore home
  return null;
}

final DateFormat datetimeFormat = DateFormat.yMd().add_jm();

String formatUiDatetime(DateTime datetime) {
  return datetimeFormat.format(datetime.toLocal());
}
