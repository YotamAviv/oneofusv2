import 'jsonish.dart';
import 'util.dart';

typedef Transformer = String Function(String);

abstract class Statement {
  final Jsonish jsonish;
  final DateTime time;
  final Json i;
  final String iToken;

  final dynamic subject;
  final String? comment;

  static final Map<Type, String> _class2type = <Type, String>{};
  static final Map<String, String> _domain2type = <String, String>{};
  static final Map<String, StatementFactory> _type2factory = <String, StatementFactory>{};

  static void registerFactory(String type, StatementFactory factory, Type statementClass,
      [String? domain]) {
    if (_type2factory.containsKey(type)) assert(_type2factory[type] == factory);
    _type2factory[type] = factory;
    _class2type[statementClass] = type;
    if (domain != null) {
      _domain2type[domain] = type;
    }
  }

  static Statement make(Jsonish j) {
    final type = j['statement'];
    final factory = _type2factory[type];
    if (factory == null) throw Exception('No factory for statement type: $type');
    return factory.make(j);
  }

  static String type<T extends Statement>() => _class2type[T]!;
  static String typeForDomain(String domain) => _domain2type[domain]!;

  Statement(this.jsonish, this.subject)
      : time = parseIso(jsonish['time']),
        i = jsonish['I'],
        iToken = getToken(jsonish['I']),
        comment = jsonish['comment'];

  String get subjectToken => (subject is String) ? subject : getToken(subject);
  String get token => jsonish.token;

  dynamic operator [](String key) => jsonish[key];

  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer});
  bool get isClear;

  Json get json => jsonish.json;
}

abstract class StatementFactory {
  Statement make(Jsonish j);
}
