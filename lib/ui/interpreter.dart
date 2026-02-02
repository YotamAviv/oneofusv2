import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/clock.dart';
import '../util.dart';
import '../core/labeler.dart';
import 'widgets/json_display.dart';

const kUnknown = '<unknown key>';

class OneOfUsInterpreter implements Interpreter {
  final Labeler labeler;

  OneOfUsInterpreter(this.labeler);

  @override
  dynamic interpret(dynamic d) {
    if (d is Jsonish) {
      return interpret(d.json);
    } else if (d is TrustStatement) {
      return interpret(d.json);
    } else if (d is Iterable) {
      return List.of(d.map(interpret));
    } else if (d is Map && d['crv'] == 'Ed25519') {
      // It's a Key
      try {
        String token = getToken(d); 
        final label = labeler.getLabel(token);
        return label != null ? label : kUnknown;
      } catch (e) {
        return d;
      }
    } else if (d is Map) {
      // It's a general Map
      List<String> keys = List.of(d.keys.cast<String>())..sort(Jsonish.compareKeys); 
      Map out = {};
      for (String key in keys) {
        if (key == 'statement' || key == 'signature' || key == 'previous') continue;
        out[interpret(key)] = interpret(d[key]);
      }
      return out;
    } else if (d is String) {
      final label = labeler.getLabel(d);
      if (label != null) return label;
      
      if (RegExp(r'^[0-9a-f]{40}$').hasMatch(d)) {
        return '<crypto token>';
      }
      try {
        return formatUiDatetime(parseIso(d));
      } catch (e) {
        return d;
      }
    } else {
      return d;
    }
  }
}
