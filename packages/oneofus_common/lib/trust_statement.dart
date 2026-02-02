import 'jsonish.dart';
import 'statement.dart';
import 'clock.dart';

const String kOneofusDomain = 'one-of-us.net';
const String kSinceAlways = '<since always>';

extension type IdentityKey(String value) {}
extension type DelegateKey(String value) {}

class TrustStatement extends Statement {
  static final Map<String, TrustStatement> _cache = <String, TrustStatement>{};

  static void init() {
    Statement.registerFactory(
        'net.one-of-us', _TrustStatementFactory(), TrustStatement, kOneofusDomain);
  }

  final TrustVerb verb;
  final String? moniker;
  final String? revokeAt;
  final String? domain;

  IdentityKey get iKey => IdentityKey(getToken(i));

  IdentityKey get subjectAsIdentity {
    if (verb == TrustVerb.trust ||
        verb == TrustVerb.block ||
        verb == TrustVerb.replace ||
        verb == TrustVerb.clear) {
      return IdentityKey(subjectToken);
    }
    throw Exception('Subject of $verb statement is not an IdentityKey');
  }

  DelegateKey get subjectAsDelegate {
    if (verb == TrustVerb.delegate || verb == TrustVerb.clear) {
      return DelegateKey(subjectToken);
    }
    throw Exception('Subject of $verb statement is not a DelegateKey');
  }

  factory TrustStatement(Jsonish jsonish) {
    if (_cache.containsKey(jsonish.token)) return _cache[jsonish.token]!;

    TrustVerb? verb;
    dynamic subject;
    for (var v in TrustVerb.values) {
      subject = jsonish[v.label];
      if (subject != null) {
        verb = v;
        break;
      }
    }
    if (verb == null) throw Exception('No verb found in TrustStatement');

    Json? withx = jsonish['with'];
    TrustStatement s = TrustStatement._internal(
      jsonish,
      subject,
      verb: verb,
      moniker: (withx != null) ? withx['moniker'] : null,
      revokeAt: (withx != null) ? withx['revokeAt'] : null,
      domain: (withx != null) ? withx['domain'] : null,
    );
    _cache[s.token] = s;
    return s;
  }

  TrustStatement._internal(
    super.jsonish,
    super.subject, {
    required this.verb,
    required this.moniker,
    required this.revokeAt,
    required this.domain,
  });

  static Json make(Json iJson, Json subject, TrustVerb verb,
      {String? revokeAt, String? moniker, String? domain, String? comment}) {
    Json json = {
      'statement': Statement.type<TrustStatement>(),
      'time': clock.nowIso,
      'I': iJson,
      verb.label: subject,
    };
    if (comment != null) json['comment'] = comment;
    Json withx = {};
    if (revokeAt != null) withx['revokeAt'] = revokeAt;
    if (domain != null) withx['domain'] = domain;
    if (moniker != null) withx['moniker'] = moniker;
    withx.removeWhere((key, value) => value == null);
    if (withx.isNotEmpty) json['with'] = withx;
    return json;
  }

  @override
  bool get isClear => verb == TrustVerb.clear;

  @override
  String getDistinctSignature({Transformer? iTransformer, Transformer? sTransformer}) {
    String canonI = (iTransformer != null) ? iTransformer(iToken) : iToken;
    String canonS = (sTransformer != null) ? sTransformer(subjectToken) : subjectToken;
    return '$canonI:$canonS';
  }
}

class _TrustStatementFactory implements StatementFactory {
  @override
  Statement make(j) => TrustStatement(j);
}
