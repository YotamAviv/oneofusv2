import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oneofus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Data layer fetches statements successfully', (WidgetTester tester) async {
    // Start the app.
    app.main();
    await tester.pumpAndSettle();

    // The _testFetchStatements function is called in initState. We need to wait for it.
    // A generous delay is the most reliable way to wait for a network call.
    await Future.delayed(const Duration(seconds: 15));
    
    // Pump a single frame to make sure the UI updates with the result.
    await tester.pump();

    // Find the hidden Text widget by its key.
    final resultFinder = find.byKey(const ValueKey('test_fetch_result'));
    expect(resultFinder, findsOneWidget);

    // Extract the data.
    final resultTextWidget = tester.widget<Text>(resultFinder);
    final resultData = resultTextWidget.data ?? "ERROR: WIDGET HAD NO DATA";

    // Print all fetched data to the console for verification.
    debugPrint("--- FETCHED DATA ---");
    // The data is a single string with newlines escaped. We replace them for readability.
    debugPrint(resultData.replaceAll('\\n', '\\n'));
    debugPrint("--------------------");

    // Check that the result contains valid JSON data.
    expect(resultData, startsWith('{"statement":'));
  });
}
