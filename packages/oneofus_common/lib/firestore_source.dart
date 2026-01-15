import 'package:cloud_firestore/cloud_firestore.dart';
import 'jsonish.dart';
import 'statement.dart';
import 'io.dart';
import 'source_error.dart';

class FirestoreSource<T extends Statement> implements StatementSource<T> {
  final FirebaseFirestore _firestore;

  FirestoreSource(this._firestore);

  @override
  final List<SourceError> errors = [];

  @override
  Future<Map<String, List<T>>> fetch(Map<String, String?> keys) async {
    errors.clear();
    final Map<String, List<T>> results = {};

    for (var entry in keys.entries) {
      final issuerToken = entry.key;
      final revokeAtToken = entry.value;

      try {
        final query = _firestore
            .collection(issuerToken)
            .doc('statements')
            .collection('statements')
            .orderBy('time', descending: true);

        final snapshot = await query.get();
        final List<T> statements = [];

        bool foundRevokeAt = false;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final jsonish = Jsonish(data, doc.id);
          final statement = Statement.make(jsonish) as T;

          if (revokeAtToken != null && !foundRevokeAt) {
            if (statement.token == revokeAtToken) {
              foundRevokeAt = true;
              statements.add(statement);
            }
            continue;
          }

          statements.add(statement);
        }

        results[issuerToken] = statements;
      } catch (e) {
        print('FIRESTORE_SOURCE ERROR for $issuerToken: $e');
        errors.add(SourceError(
          'Error fetching statements for $issuerToken: $e',
          token: issuerToken,
          originalError: e,
        ));
      }
    }

    return results;
  }
}
