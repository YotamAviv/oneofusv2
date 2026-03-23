import 'package:intl/intl.dart';

final DateTime date0 = DateTime.fromMicrosecondsSinceEpoch(0);

final DateFormat datetimeFormat = DateFormat.yMd().add_jm();

String formatUiDatetime(DateTime datetime) {
  return datetimeFormat.format(datetime.toLocal());
}
