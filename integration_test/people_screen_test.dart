import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oneofus/core/config.dart';
import 'package:oneofus_common/channel_factory.dart' show FireChoice;
import 'package:oneofus/core/keys.dart';
import 'package:oneofus/main.dart' as app;
import 'test_utils.dart';

// This test relies on Lisa from the Simpsons Demo to be there.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('When logged in as Lisa, the people screen shows her trusted contacts', (WidgetTester tester) async {
    // This test should work on both [prod, emulator].
    Set<FireChoice> supported = {FireChoice.emulator, FireChoice.prod};
    assert(supported.contains(Config.fireChoice), "Not supported: ${Config.fireChoice.name}.");
    await Config.initFirebase();
    Config.initChannelFactory();

    // 1. Define Lisa's private key.
    debugPrint("TEST: Defining Lisa's private key.");
    final lisaPrivateKey = {
      "crv": "Ed25519",
      "d": "7j5C4knFNcGxUXuydoJuS9GSwWZH18wT7ZmY_8X33iE",
      "kty": "OKP",
      "x": "u5RjV6Ra-rhVGF4rlVEj5kee4Z4LNMO6QcedEHVa7pU"
    };

    // 2. Load Lisa's key BEFORE the app starts.
    debugPrint("TEST: Calling Keys().loadForTest(lisaPrivateKey).");
    await Keys().loadForTest(lisaPrivateKey);

    // 3. Start the app.
    debugPrint("TEST: Calling tester.pumpWidget.");
    await tester.pumpWidget(const app.App(isTesting: true));
    
    await tester.pump(const Duration(seconds: 1));

    debugPrint("TEST: Waiting for 'Lisa' to appear on card.");
    for (int i = 0; i < 5 && !tester.any(find.text('Lisa')); i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // 4. Navigate to the People screen.
    debugPrint("TEST: Navigating to People screen.");
    await navigateToScreen(tester, 'PEOPLE');

    // 5. Wait for the data to appear.
    debugPrint("TEST: Waiting for 'Maggie' to appear.");
    for (int i = 0; i < 5 && !tester.any(find.text('Maggie')); i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // 6. Verify that all expected data is displayed.
    debugPrint("TEST: Verifying all names are present.");
    expect(find.text('Maggie'), findsOneWidget);
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Homer'), findsOneWidget);
    debugPrint("TEST: PASSED, SUCCESS.");
  });
}
