import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oneofus/core/config.dart';
import 'package:oneofus/core/keys.dart';
import 'package:oneofus/main.dart' as app;
import 'package:oneofus/ui/identity_card_surface.dart';
import 'package:oneofus_common/keys.dart' show FedKey;
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Federated QR checkbox: toggles QR format between bare key and {key, home}',
    (WidgetTester tester) async {
      Config.ensureNotProd();
      await Config.initFirebase();
      await Keys().clearAll();

      final db = Config.db;

      // Start app
      await tester.pumpWidget(app.App(firestore: db, isTesting: true));
      await tester.pump(const Duration(seconds: 1));

      // Create new identity
      debugPrint('TEST: Creating new identity.');
      expect(find.text('CREATE NEW IDENTITY KEY'), findsOneWidget);
      await tester.tap(find.text('CREATE NEW IDENTITY KEY'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('CONGRATULATIONS!'), findsOneWidget);
      await tester.tap(find.text('Okay'));
      await tester.pumpAndSettle();

      // Get my public key so we can verify QR content
      final myPubKeyJson = (await Keys().getIdentityPublicKeyJson())!;
      final bareKeyStr = jsonEncode(myPubKeyJson);
      final federatedStr = jsonEncode(FedKey(myPubKeyJson).toPayload());

      debugPrint('TEST: bare QR: $bareKeyStr');
      debugPrint('TEST: fed QR: $federatedStr');

      // Check QR predicates
      Finder qrWithHome() => find.byWidgetPredicate(
            (w) => w is IdentityCardSurface && w.jsonKey == federatedStr,
          );
      Finder qrBareKey() => find.byWidgetPredicate(
            (w) => w is IdentityCardSurface && w.jsonKey == bareKeyStr,
          );

      // --- Default state: bare key ---
      debugPrint('TEST: Verifying QR is bare key by default.');
      expect(qrBareKey(), findsOneWidget, reason: 'QR should be bare key by default');
      expect(qrWithHome(), findsNothing, reason: 'QR should not have home by default');

      // --- Navigate to Advanced screen ---
      debugPrint('TEST: Navigating to Advanced screen.');
      await navigateToScreen(tester, 'ADVANCED');

      // Locate the federated QR checkbox
      final Finder federatedCheckbox = find.byWidgetPredicate(
        (w) =>
            w is CheckboxListTile &&
            w.title is Text &&
            ((w.title as Text).data?.contains('Federated') ?? false),
      );
      expect(federatedCheckbox, findsOneWidget, reason: 'Federated QR checkbox must exist');

      // Confirm off by default
      expect(
        tester.widget<CheckboxListTile>(federatedCheckbox).value,
        isFalse,
        reason: 'Checkbox must default to OFF',
      );

      // --- Toggle ON ---
      debugPrint('TEST: Toggling federated QR checkbox ON.');
      await tester.tap(federatedCheckbox);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(federatedCheckbox).value,
        isTrue,
        reason: 'Checkbox should now be ON',
      );

      // --- Navigate back to card screen, verify {key, home} format ---
      debugPrint('TEST: Navigating back to card screen, checking {key-home} QR.');
      await navigateToScreen(tester, 'ID');
      await tester.pump(const Duration(seconds: 1));
      expect(qrWithHome(), findsOneWidget, reason: 'QR should now contain home field');
      expect(qrBareKey(), findsNothing, reason: 'QR should no longer be bare key');

      // --- Toggle back OFF ---
      debugPrint('TEST: Toggling federated QR checkbox OFF.');
      await navigateToScreen(tester, 'ADVANCED');
      await tester.tap(federatedCheckbox);
      await tester.pumpAndSettle();

      // --- Navigate to card screen, verify reverts to bare key ---
      debugPrint('TEST: Verifying QR reverts to bare key.');
      await navigateToScreen(tester, 'ID');
      await tester.pump(const Duration(seconds: 1));
      expect(qrBareKey(), findsOneWidget, reason: 'QR should revert to bare key');
      expect(qrWithHome(), findsNothing);

      debugPrint('TEST: PASSED, SUCCESS.');
    },
  );
}
