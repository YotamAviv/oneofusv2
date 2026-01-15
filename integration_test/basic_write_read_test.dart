import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/foundation.dart';
import 'package:oneofus/core/config.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/firestore_source.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Basic Write-Read Test (Emulator)', (WidgetTester tester) async {
    // 1. Setup
    await Config.initFirebase();
    final FirebaseFirestore db = Config.db;
    TrustStatement.init();

    final crypto = CryptoFactoryEd25519();
    final myKeyPair = await crypto.createKeyPair();
    final myPublicKeyJson = await (await myKeyPair.publicKey).json;
    final myToken = getToken(myPublicKeyJson);

    final boKeyPair = await crypto.createKeyPair();
    final boPublicKeyJson = await (await boKeyPair.publicKey).json;
    final boToken = getToken(boPublicKeyJson);

    debugPrint('TEST: myToken: $myToken');
    debugPrint('TEST: boToken: $boToken');

    // 2. Write
    final writer = DirectFirestoreWriter(db);
    final signer = await OouSigner.make(myKeyPair);
    
    final statement = TrustStatement.make(
      myPublicKeyJson,
      boPublicKeyJson,
      TrustVerb.trust,
      moniker: 'Bo',
    );

    debugPrint('TEST: Pushing statement...');
    await writer.push(statement, signer);
    debugPrint('TEST: Statement pushed.');

    // 3. Read
    final source = FirestoreSource<TrustStatement>(db);
    debugPrint('TEST: Fetching statements for $myToken...');
    final results = await source.fetch({myToken: null});
    
    final statements = results[myToken] ?? [];
    debugPrint('TEST: Found ${statements.length} statements.');

    // 4. Assert
    expect(statements.length, greaterThanOrEqualTo(1), reason: 'Should find at least one statement');
    
    final latest = statements.first;
    expect(latest.subjectToken, equals(boToken));
    expect(latest.verb, equals(TrustVerb.trust));
    expect(latest.moniker, equals('Bo'));
    
    debugPrint('TEST: Basic Write-Read SUCCESS');
  });
}
