import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus/core/keys.dart';
import 'package:oneofus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Identity, bidirectional trust, validate check states and name', (WidgetTester tester) async {
    // 0. Wipe existing keys to ensure we start at the onboarding screen
    await Keys().clearAll();

    final fakeFirestore = FakeFirebaseFirestore();
    final crypto = CryptoFactoryEd25519();
    
    // 2. Start app with FakeFirestore
    debugPrint("TEST: Pumping App.");
    await tester.pumpWidget(app.App(firestore: fakeFirestore, isTesting: true));
    await tester.pump(const Duration(seconds: 1));

    // 2a. Handle onboarding (interface: create new identity key for me)
    debugPrint("TEST: Looking for GENERATE NEW IDENTITY button.");
    expect(find.text('GENERATE NEW IDENTITY'), findsOneWidget);
    debugPrint("TEST: Clicking GENERATE NEW IDENTITY.");
    await tester.tap(find.text('GENERATE NEW IDENTITY'));
    await tester.pump(const Duration(seconds: 2)); // Allow time for key gen and data load

    // Validate: My name is "Me"
    debugPrint("TEST: Verifying name is 'Me'.");
    expect(find.text('Me'), findsOneWidget);
    debugPrint("TEST: Confirmed: Name is 'Me'.");

    // Get my token/identity info
    final myToken = Keys().identityToken;
    final myPublicKeyJson = await Keys().getIdentityPublicKeyJson();
    final myKeyPair = Keys().identity!;

    // 3. Create key for "Bo" (code: create new key for "Bo")
    final boKeyPair = await crypto.createKeyPair();
    final boToken = getToken(await (await boKeyPair.publicKey).json);
    final boPublicKeyJson = await (await boKeyPair.publicKey).json;

    // 4. "Me" trusts "Bo" (code: state: I.trust(Bo))
    final meWriter = DirectFirestoreWriter(fakeFirestore);
    final meSigner = await OouSigner.make(myKeyPair);
    await meWriter.push({
      'statement': 'net.one-of-us',
      'trust': boPublicKeyJson,
      'I': myPublicKeyJson,
      'time': DateTime.now().toUtc().toIso8601String(),
      'with': {
        'moniker': 'Bo',
      },
    }, meSigner);
    debugPrint("TEST: Me trusted Bo.");

    // 5. Navigate to People screen and check for "Bo"
    debugPrint("TEST: Tapping Menu.");
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pump(const Duration(seconds: 1));
    debugPrint("TEST: Tapping PEOPLE.");
    await tester.tap(find.text('PEOPLE'));
    await tester.pump(const Duration(seconds: 1));

    debugPrint("TEST: Tapping Refresh (initial load might need it).");
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(seconds: 2));

    debugPrint("TEST: Looking for Bo.");
    expect(find.text('Bo'), findsOneWidget);
    // Bo doesn't trust me yet - check should be outline (validate: Bo doesn't trust me)
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    debugPrint("TEST: Bo found, check is outline.");

    // 6. "Bo" trusts "me" as "Luke" (code: state: Bo.trust(me) moniker:"Luke")
    final boWriter = DirectFirestoreWriter(fakeFirestore);
    final boSigner = await OouSigner.make(boKeyPair);
    await boWriter.push({
      'statement': 'net.one-of-us',
      'trust': myPublicKeyJson,
      'I': boPublicKeyJson,
      'time': DateTime.now().toUtc().toIso8601String(),
      'with': {
        'moniker': 'Luke',
      },
    }, boSigner);
    debugPrint("TEST: Bo trusted Me as 'Luke' in Firestore.");

    // 7. Refresh (interface: refresh)
    debugPrint("TEST: Tapping Refresh.");
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(seconds: 2)); // Wait for fetch

    // 8. Validate: Bo does trust me (check filled in)
    debugPrint("TEST: Verifying check is filled in.");
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    debugPrint("TEST: Check is now filled in.");

    // TODO: This is klumsy, consider a "Home" key.
    // 9. Go back to Home (Swipe back twice from Page 2 to Page 0)
    debugPrint("TEST: Swiping back to Page 1 (Key Management).");
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500)); // finish animation

    debugPrint("TEST: Swiping back to Page 0 (Home).");
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));

    // Validate: My name is now "Luke"
    debugPrint("TEST: Verifying name is 'Luke' on Identity Card.");
    expect(find.text('Luke'), findsOneWidget);
    debugPrint("TEST: Name is now 'Luke'. SUCCESS.");
  });
}
