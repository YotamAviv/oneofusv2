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

  /// Verifies that a collection of statements is ordered by time (descending)
  /// and contains only one type of statement (TrustStatement or ContentStatement).
  /// Uses assert, only checks in debug mode
  static void validateOrderTypes(Iterable<Statement> statements) {
    assert(() {
      if (statements.isEmpty) return true;
      final Type firstType = statements.first.runtimeType;

      Statement? previous;
      int i = 0;
      for (final Statement current in statements) {
        if (current.runtimeType != firstType) {
          throw 'Collection contains mixed statement types: $firstType and ${current.runtimeType}';
        }

        if (previous != null) {
          if (!previous.time.isAfter(current.time)) {
            throw 'Statements are not in strictly descending time order.\n'
                'Index ${i - 1}: ${previous.time}\n'
                'Index $i: ${current.time}';
          }
        }
        previous = current;
        i++;
      }
      return true;
    }());
  }

  /// Helper to validate multiple collections of statements.
  /// Uses assert, only checks in debug mode
  static void validateOrderTypess(Iterable<Iterable<Statement>> collections) {
    assert(() {
      for (final collection in collections) {
        validateOrderTypes(collection);
      }
      return true;
    }());
  }

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
