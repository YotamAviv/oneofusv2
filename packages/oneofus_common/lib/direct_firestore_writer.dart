import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/util.dart';


/// Writes statements directly to Firestore.
/// 
/// CONSIDERATION: Async/Optimistic Writes (Jan 2026)
/// Proposal: Make writes more AJAX-like by signing the statement locally (using cached head)
/// and pushing the *Signed Statement* asynchronously. This would improve UI responsiveness by 
/// removing the network round-trip from the UI blocking path.
/// 
/// Decision: REJECTED (for now).
/// Reason: The chained nature of statements requires the signature to lock in the *exact* previous hash.
/// Pre-signing introduces a "Fragile Chain" risk:
/// 1. Stale Head: If the local cache is milliseconds out of date (e.g. another device wrote), 
///    the signature is invalid (wrong 'previous').
/// 2. Poisoned Queue: If user actions A, B, C are queued rapidly, and A fails validation, 
///    B and C (which point to A) are also dead. They cannot be retried without re-signing.
/// 3. Data Loss: "Fire and forget" makes it hard to recover the user's intent/content after a silent failure.
/// 
/// Current "Just-in-Time" signing inside push() ensures we always sign the specific tip-of-chain at the moment of commit.
class DirectFirestoreWriter implements StatementWriter {
  final FirebaseFirestore _fire;

  DirectFirestoreWriter(this._fire);

  @override
  Future<Statement> push(Json json, StatementSigner signer, {String? previous}) async {
    final String issuerToken = getToken(json['I']);
    final fireStatements = _fire.collection(issuerToken).doc('statements').collection('statements');

    // Note: This is not truly transactional because the Flutter SDK does not
    // support queries inside transactions for this use case. A Cloud Function
    // would be required for a fully atomic read-modify-write operation.
    final latestSnapshot = await fireStatements.orderBy('time', descending: true).limit(1).get();

    String? previousToken;
    DateTime? prevTime;

    if (latestSnapshot.docs.isNotEmpty) {
      final latestDoc = latestSnapshot.docs.first;
      previousToken = latestDoc.id;
      prevTime = parseIso(latestDoc.data()['time']);
    }

    if (previous != null) {
      if (previous.isEmpty) {
        if (previousToken != null) {
          throw Exception(
              'Push Rejected: Optimistic locking failure. Expected Genesis (no previous), found=$previousToken');
        }
      } else if (previousToken != previous) {
        throw Exception(
            'Push Rejected: Optimistic locking failure. Expected previous=$previous, found=$previousToken');
      }
    }

    if (previousToken != null) {
      json['previous'] = previousToken;
    }

    final Jsonish jsonish = await Jsonish.makeSign(json, signer);
    final statement = Statement.make(jsonish);

    await _fire.runTransaction((transaction) async {
      final docRef = fireStatements.doc(jsonish.token);
      final doc = await transaction.get(docRef);
      if (doc.exists) {
        throw Exception('Statement already exists: ${jsonish.token}');
      }

      if (prevTime != null) {
        final DateTime thisTime = parseIso(json['time']!);
        if (!thisTime.isAfter(prevTime)) {
          throw Exception('Timestamp must be after previous statement ($thisTime <= $prevTime)');
        }
      }

      transaction.set(docRef, jsonish.json);
    });

    return statement;
  }
}
