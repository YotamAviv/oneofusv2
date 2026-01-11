import 'package:intl/intl.dart';

final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);
const String kSinceAlways = '<since always>';

bool b(dynamic d) => d == null ? false : true;
bool bb(bool? bb) => bb != null && bb;

abstract class Clock {
  DateTime get now;
  String get nowIso => formatIso(now);
}

class LiveClock extends Clock {
  @override
  DateTime get now => DateTime.now();
}

Clock clock = LiveClock();

DateTime parseIso(String iso) => DateTime.parse(iso);

String formatIso(DateTime datetime) {
  return datetime.toUtc().toIso8601String();
}

final DateFormat datetimeFormat = DateFormat.yMd().add_jm();

String formatUiDatetime(DateTime datetime) {
  return datetimeFormat.format(datetime.toLocal());
}
