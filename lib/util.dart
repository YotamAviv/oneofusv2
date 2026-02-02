import 'package:intl/intl.dart';

final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);

/// Checks if the Map represents a valid public key (JWK).
bool isPubKey(Map<String, dynamic> json) {
  return json.containsKey('x') && json.containsKey('crv') && json['kty'] == 'OKP';
}

final DateFormat datetimeFormat = DateFormat.yMd().add_jm();

String formatUiDatetime(DateTime datetime) {
  return datetimeFormat.format(datetime.toLocal());
}
