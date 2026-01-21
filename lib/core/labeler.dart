import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

class Labeler {
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  String? _myMoniker;

  Labeler(this.statementsByIssuer, this.myKeyToken);

  /// Resolves the moniker for "Me" based on who I trust.
  /// Mimics logic from CardScreen.
  String get myMoniker {
    if (_myMoniker != null) return _myMoniker!;

    // 1. Who do I trust?
    final trustedByMe = (statementsByIssuer[myKeyToken] ?? [])
        .where((s) => s.verb == TrustVerb.trust)
        .map((s) => s.subjectToken)
        .toSet();

    // 2. Do they trust me?
    for (final issuer in trustedByMe) {
      final statements = statementsByIssuer[issuer] ?? [];
      for (final s in statements) {
        if (s.subjectToken == myKeyToken && s.verb == TrustVerb.trust) {
          if (s.moniker != null && s.moniker!.isNotEmpty) {
            _myMoniker = s.moniker!;
            return _myMoniker!;
          }
        }
      }
    }

    _myMoniker = 'Me'; // No trusted circle established yet
    return _myMoniker!;
  }

  /// Returns a label for the token if one exists (Delegate, Trust, Own Key).
  String? getLabel(String token) {
    if (token == myKeyToken) return myMoniker;

    // Check my statements for this token
    final myStatements = statementsByIssuer[myKeyToken] ?? [];
    
    // 1. Is it one of my trusted associates?
    // Find 'trust' statement for this token
    final trustStmt = myStatements.where(
      (s) => s.subjectToken == token && s.verb == TrustVerb.trust,
    ).firstOrNull;
    
    if (trustStmt != null && trustStmt.moniker != null) {
      return trustStmt.moniker;
    }

    // 2. Is it one of my delegates?
    final delegateStmts = myStatements.where((s) => s.verb == TrustVerb.delegate).toList();
    final matchingDelegate = delegateStmts
        .where((s) => s.subjectToken == token)
        .firstOrNull;
    
    if (matchingDelegate != null) {
      final domain = matchingDelegate.domain!;
      
      // Calculate counter based on other delegates for this domain
      final siblings = delegateStmts
          .where((s) => s.domain == domain)
          .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
      
      final index = siblings.indexWhere((s) => s.subjectToken == token);
      if (index == 0) {
        return '$myMoniker@$domain';
      } else {
        return '$myMoniker@$domain (${index + 1})';
      }
    }

    // 3. Is it one of my replaced keys?
    final replaceStmts = myStatements.where((s) => s.verb == TrustVerb.replace).toList();
    final matchingReplace = replaceStmts
        .where((s) => s.subjectToken == token)
        .firstOrNull;
    
    if (matchingReplace != null) {
      // Calculate counter based on all replaced keys
      replaceStmts.sort((a, b) => a.time.compareTo(b.time));
      
      final index = replaceStmts.indexWhere((s) => s.subjectToken == token);
      return '$myMoniker (${index + 2})';
    }

    return null; 
  }
}
