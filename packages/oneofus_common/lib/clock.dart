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
