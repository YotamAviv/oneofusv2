import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oneofus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Fetches data and displays expected names on the People screen', (WidgetTester tester) async {
    // 1. Start the app.
    await tester.pumpWidget(const app.OneOfUsApp());
    
    // 2. Handle both first-time and subsequent runs.
    int pumpCount = 0;
    while (tester.any(find.byType(CircularProgressIndicator))) {
      await tester.pump(const Duration(milliseconds: 100));
      pumpCount++;
      if (pumpCount > 100) { // 10 second timeout
        throw Exception("Timed out waiting for initial load.");
      }
    }

    if (tester.any(find.text('GENERATE NEW IDENTITY'))) {
      await tester.tap(find.text('GENERATE NEW IDENTITY'));
      await tester.pump(const Duration(milliseconds: 500)); 
      while (tester.any(find.byType(CircularProgressIndicator))) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // 3. Wait for network data to load.
    await tester.pump(const Duration(seconds: 10));

    // 4. Navigate to the People screen.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pump(const Duration(seconds: 1)); // Wait for bottom sheet animation

    await tester.tap(find.text('PEOPLE'));
    await tester.pump(const Duration(seconds: 1)); // Wait for page transition

    // 5. Verify that the data is correctly displayed.
    expect(find.text('Maggie'), findsOneWidget);
    expect(find.text('Mom'), findsOneWidget);
    expect(find.text('Homer'), findsOneWidget);
  });
}
