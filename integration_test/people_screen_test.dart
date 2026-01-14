import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus/core/keys.dart';
import 'package:oneofus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('When logged in as Lisa, the people screen shows her trusted contacts', (WidgetTester tester) async {
    // 1. Define Lisa's private key.
    debugPrint("TEST: Defining Lisa's private key.");
    final lisaPrivateKey = {
      "crv": "Ed25519",
      "d": "WCtPGxyJ9dL6qP3eEuuOCxLHgTZjbbdofge3j6c85vo",
      "kty": "OKP",
      "x": "D6oXiGksgfL4AP6lf2vXnAoq54_t1p8k-3SXs1Bgm8g"
    };

    // 2. Load Lisa's key BEFORE the app starts.
    debugPrint("TEST: Calling Keys().loadForTest(lisaPrivateKey).");
    await Keys().loadForTest(lisaPrivateKey);

    // 3. Start the app.
    debugPrint("TEST: Calling tester.pumpWidget with isTesting: true.");
    await tester.pumpWidget(const app.OneOfUsApp(isTesting: true));
    await tester.pump(const Duration(seconds: 1)); // Let app initialize.

    // 4. Navigate to the People screen.
    debugPrint("TEST: Navigating to People screen.");
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('PEOPLE'));
    await tester.pump(const Duration(seconds: 1));

    // 5. Wait for the data to appear.
    debugPrint("TEST: Polling for 'Maggie' to appear.");
    bool found = false;
    for (int i = 0; i < 20; i++) {
      if (tester.any(find.text('Maggie'))) {
        debugPrint("TEST: Found 'Maggie'.");
        found = true;
        break;
      }
      await tester.pump(const Duration(seconds: 1));
    }

    if (!found) {
      fail("TEST: Timed out waiting for 'Maggie'.");
    }

    // 6. Verify that all expected data is displayed.
    debugPrint("TEST: Verifying all names are present.");
    expect(find.text('Maggie'), findsOneWidget);
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Homer'), findsOneWidget);
  });
}
