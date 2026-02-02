import 'package:intl/intl.dart';

const String kSinceAlways = '<since always>';
final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);

bool b(dynamic d) => d != null;
bool bb(bool? bb) => bb != null && bb;

/// Checks if the Map represents a valid public key (JWK).
bool isPubKey(Map<String, dynamic> json) {
  return json.containsKey('x') && json.containsKey('crv') && json['kty'] == 'OKP';
}

final DateFormat datetimeFormat = DateFormat.yMd().add_jm();

String formatUiDatetime(DateTime datetime) {
  return datetimeFormat.format(datetime.toLocal());
}
