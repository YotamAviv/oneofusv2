import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oneofus/core/config.dart';
import 'package:oneofus/core/keys.dart';
import 'package:oneofus/main.dart' as app;
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Identity, bidirectional trust, validate check states and name', (
    WidgetTester tester,
  ) async {
    debugPrint('Config.fireChoice=${Config.fireChoice.name}');

    // 0. Safety check: refuse to run if Prod
    Config.ensureNotProd();

    // Initialize Firebase correctly (handles Fake/Emulator/Prod logic)
    await Config.initFirebase();

    // 0. Wipe existing keys to ensure we start at the onboarding screen
    await Keys().clearAll();

    final db = Config.db;
    final crypto = CryptoFactoryEd25519();

    // 2. Start app with active Firestore
    debugPrint("TEST: Pumping App.");
    await tester.pumpWidget(app.App(firestore: db, isTesting: true));
    await tester.pump(const Duration(seconds: 1));

    // 2a. Handle onboarding (interface: create new identity key for me)
    debugPrint("TEST: Looking for CREATE NEW IDENTITY KEY button.");
    expect(find.text('CREATE NEW IDENTITY KEY'), findsOneWidget);
    debugPrint("TEST: Clicking CREATE NEW IDENTITY KEY.");
    await tester.tap(find.text('CREATE NEW IDENTITY KEY'));
    await tester.pump(const Duration(seconds: 2)); // Allow time for key gen and data load

    // Validate: My name is "Me"
    debugPrint("TEST: Verifying name is 'Me'.");
    expect(find.text('Me'), findsOneWidget);
    debugPrint("TEST: Confirmed: Name is 'Me'.");

    // Get my token/identity info
    final myPublicKeyJson = await Keys().getIdentityPublicKeyJson();
    final myKeyPair = Keys().identity!;

    // 3. Create key for "Bo" (code: create new key for "Bo")
    final boKeyPair = await crypto.createKeyPair();
    final boPublicKeyJson = await (await boKeyPair.publicKey).json;

    // 4. "Me" trusts "Bo" (code: state: I.trust(Bo))
    final meWriter = DirectFirestoreWriter(db);
    final meSigner = await OouSigner.make(myKeyPair);

    final meToBoStatement = TrustStatement.make(
      myPublicKeyJson!,
      boPublicKeyJson,
      TrustVerb.trust,
      moniker: 'Bo',
    );

    await meWriter.push(meToBoStatement, meSigner);
    debugPrint("TEST: Me trusted Bo.");

    debugPrint("TEST: Tapping Refresh.");
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(seconds: 2));

    // 5. Navigate to People screen and check for "Bo"
    debugPrint("TEST: Navigating to People screen.");
    await navigateToScreen(tester, 'PEOPLE');

    debugPrint("TEST: Tapping Refresh (initial load might need it).");
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(seconds: 2));

    debugPrint("TEST: Looking for Bo.");
    expect(find.text('Bo'), findsOneWidget);
    // Bo doesn't trust me yet - check should be outline (validate: Bo doesn't trust me)
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    debugPrint("TEST: Bo found, check is outline.");

    // 6. "Bo" trusts "me" as "Luke" (code: state: Bo.trust(me) moniker:"Luke")
    final boWriter = DirectFirestoreWriter(db);
    final boSigner = await OouSigner.make(boKeyPair);

    final boToMeStatement = TrustStatement.make(
      boPublicKeyJson,
      myPublicKeyJson,
      TrustVerb.trust,
      moniker: 'Luke',
    );

    await boWriter.push(boToMeStatement, boSigner);
    debugPrint("TEST: Bo trusted Me as 'Luke' in Firestore.");

    // 7. Refresh (interface: refresh)
    debugPrint("TEST: Tapping Refresh.");
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(seconds: 2)); // Wait for fetch

    // 8. Validate: Bo does trust me (check filled in)
    debugPrint("TEST: Verifying check is filled in.");
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    debugPrint("TEST: Check is now filled in.");

    // 9. Go back to Home
    debugPrint("TEST: Navigating back to ID screen.");
    await navigateToScreen(tester, 'ID');

    // Validate: My name is now "Luke"
    debugPrint("TEST: Verifying name is 'Luke' on Identity Card.");
    expect(find.text('Luke'), findsOneWidget);
    debugPrint("TEST: Name is now 'Luke'.");
    debugPrint("TEST PASSED, SUCCESS.");
  });
}
