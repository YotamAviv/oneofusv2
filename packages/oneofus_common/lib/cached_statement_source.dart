import 'io.dart';
import 'statement.dart';
import 'source_error.dart';

/// A caching decorator for [StatementSource].
/// Stores fetched statements in memory to avoid redundant network calls.
class CachedStatementSource<T extends Statement> implements StatementSource<T> {
  final StatementSource<T> _delegate;

  // Full histories: Map<Token, List<Statement>>
  final Map<String, List<T>> _fullCache = {};

  // Partial histories: Map<Token, (revokeAt, List<Statement>)>
  final Map<String, (String, List<T>)> _partialCache = {};

  final Map<String, SourceError> _errorCache = {};

  CachedStatementSource(this._delegate);

  @override
  List<SourceError> get errors => List.unmodifiable(_errorCache.values);

  void clear() {
    _fullCache.clear();
    _partialCache.clear();
    _errorCache.clear();
  }

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    final Map<String, List<T>> results = {};
    final Map<String, String?> missing = {};

    // 1. Check cache
    for (final MapEntry<String, String?> entry in keys.entries) {
      final String token = entry.key;
      final String? revokeAt = entry.value;

      if (_errorCache.containsKey(token)) {
        continue;
      }

      if (_fullCache.containsKey(token)) {
        results[token] = _fullCache[token]!;
      } else if (revokeAt != null &&
          _partialCache.containsKey(token) &&
          _partialCache[token]!.$1 == revokeAt) {
        results[token] = _partialCache[token]!.$2;
      } else {
        missing[token] = revokeAt;
      }
    }

    // 2. Fetch missing
    if (missing.isNotEmpty) {
      final Map<String, List<T>> fetched = await _delegate.fetch(missing);

      // 3. Update cache and results
      for (final String token in missing.keys) {
        final SourceError? error =
            _delegate.errors.where((SourceError e) => e.token == token).firstOrNull;
        
        if (error != null) {
          _errorCache[token] = error;
          continue; 
        }

        final List<T> statements = fetched[token] ?? [];
        final String? revokeAt = missing[token];

        if (revokeAt == null) {
          _fullCache[token] = statements;
        } else {
          _partialCache[token] = (revokeAt, statements);
        }
        results[token] = statements;
      }
    }

    return results;
  }
}
