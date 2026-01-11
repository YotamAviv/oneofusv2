import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

/// Statement signing and verification are handled here.
typedef Json = Map<String, dynamic>;

abstract class StatementSigner {
  Future<String> sign(Json json, String string);
}

abstract class StatementVerifier {
  Future<bool> verify(Json json, String string, String signature);
}

enum TrustVerb {
  trust('trust', 'trusted'),
  block('block', 'blocked'),
  replace('replace', 'replaced'),
  delegate('delegate', 'delegated'),
  clear('clear', 'cleared');

  const TrustVerb(this.label, this.pastTense);
  final String label;
  final String pastTense;
}

enum ContentVerb {
  rate('rate', 'rated'),
  relate('relate', 'related'),
  dontRelate('dontRelate', 'un-related'),
  equate('equate', 'equated'),
  dontEquate('dontEquate', 'un-equated'),
  follow('follow', 'followed'),
  clear('clear', 'cleared');

  const ContentVerb(this.label, this.pastTense);
  final String label;
  final String pastTense;
}

class Jsonish {
  static final List<String> keysInOrder = [
    'statement',
    'time',
    'I',
    ...TrustVerb.values.map((e) => e.label),
    ...ContentVerb.values.map((e) => e.label),
    'with',
    'other',
    'moniker',
    'revokeAt',
    'domain',
    'tags',
    'recommend',
    'dismiss',
    'censor',
    'stars',
    'comment',
    'contentType',
    'previous',
    'signature',
  ];
  static const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  static final Map<String, int> key2order =
      Map.unmodifiable({for (var e in keysInOrder) e: keysInOrder.indexOf(e)});

  static int compareKeys(String key1, String key2) {
    int? key1i = key2order[key1];
    int? key2i = key2order[key2];
    if (key1i != null && key2i != null) {
      return key1i - key2i;
    } else if (key1i == null && key2i == null) {
      return key1.compareTo(key2);
    } else if (key1i != null) {
      return -1;
    } else {
      return 1;
    }
  }

  static final Map<String, Jsonish> _cache = <String, Jsonish>{};
  static Jsonish? find(String token) => _cache[token];
  static void wipeCache() => _cache.clear();

  final Json _json;
  final String _token;

  factory Jsonish(Json json, [String? serverToken]) {
    String token;
    if (serverToken != null) {
      token = serverToken;
    } else {
      json = order(json);
      String ppJson = encoder.convert(json);
      token = sha1.convert(utf8.encode(ppJson)).toString();
    }
    if (_cache.containsKey(token)) return _cache[token]!;

    Jsonish fresh = Jsonish._internal(Map.unmodifiable(json), token);
    _cache[token] = fresh;
    return fresh;
  }

  static Future<Jsonish> makeVerify(Json json, StatementVerifier verifier) async {
    String signature = json['signature']!;
    Json ordered = order(json);
    String ppJson = encoder.convert(ordered);
    String token = sha1.convert(utf8.encode(ppJson)).toString();
    if (_cache.containsKey(token)) {
      Jsonish cached = _cache[token]!;
      if (cached['signature'] != signature) throw Exception('!verified');
      return cached;
    }

    Json orderedWithoutSig = order(Map.from(json)..removeWhere((k, v) => k == 'signature'));
    String ppJsonWithoutSig = encoder.convert(orderedWithoutSig);
    bool verified = await verifier.verify(json, ppJsonWithoutSig, signature);
    if (!verified) throw Exception('!verified');

    Jsonish fresh = Jsonish._internal(Map.unmodifiable(ordered), token);
    _cache[token] = fresh;
    return fresh;
  }

  static Future<Jsonish> makeSign(Json json, StatementSigner signer) async {
    assert(!json.containsKey('signature'));
    Json ordered = order(json);
    String ppJson = encoder.convert(ordered);
    final String signature = await signer.sign(json, ppJson);
    ordered['signature'] = signature;
    ppJson = encoder.convert(ordered);
    final String token = sha1.convert(utf8.encode(ppJson)).toString();

    if (_cache.containsKey(token)) {
      Jsonish cached = _cache[token]!;
      assert(signature == cached['signature']);
      return cached;
    }

    Jsonish fresh = Jsonish._internal(Map.unmodifiable(ordered), token);
    _cache[token] = fresh;
    return fresh;
  }

  Jsonish._internal(this._json, this._token);

  static dynamic order(dynamic value) {
    if (value is String || value is num || value is bool || value == null) {
      return value;
    } else if (value is Map) {
      String? signature = value['signature'];
      List list = List.of(value.entries)..sort((x, y) => compareKeys(x.key, y.key));
      LinkedHashMap<String, dynamic> orderedMap = LinkedHashMap<String, dynamic>();
      for (MapEntry entry in list.whereNot((e) => (e.key == 'signature'))) {
        orderedMap[entry.key] = Jsonish.order(entry.value);
      }
      if (signature != null) orderedMap['signature'] = signature;
      return orderedMap;
    } else if (value is List) {
      return value.map(order).toList();
    } else {
      throw Exception('Unexpected: (${value.runtimeType}) $value');
    }
  }

  Json get json => _json;
  String get token => _token;
  String get ppJson => encoder.convert(json);

  dynamic operator [](String key) => _json[key];
  bool containsKey(String key) => _json.containsKey(key);
  Iterable get keys => _json.keys;
  Iterable get values => _json.values;

  @override
  String toString() => _json.values.join(':');
}

String getToken(dynamic x) {
  assert(x != null);
  if (x is Json) {
    return Jsonish(x).token;
  } else if (x is String) {
    return x;
  } else {
    throw Exception(x.runtimeType.toString());
  }
}
