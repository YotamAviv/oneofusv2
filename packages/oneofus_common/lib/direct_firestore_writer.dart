import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/statement.dart';
import 'package:oneofus_common/util.dart';


/// Writes statements directly to Firestore.
class DirectFirestoreWriter implements StatementWriter {
  final FirebaseFirestore _fire;

  DirectFirestoreWriter(this._fire);

  @override
  Future<Statement> push(Json json, StatementSigner signer) async {
    final String issuerToken = getToken(json['I']);
    final fireStatements = _fire.collection(issuerToken).doc('statements').collection('statements');
    print('DIRECT_WRITER: Pushing statement for issuer $issuerToken to path: ${issuerToken}/statements/statements');

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

    print('DIRECT_WRITER: SUCCESSFULLY pushed statement ${jsonish.token} for $issuerToken');
    return statement;
  }
}
