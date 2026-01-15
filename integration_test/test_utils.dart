import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Navigates to a screen by its title in the Management Hub.
/// If not on the ID screen, it taps the Home button first.
Future<void> navigateToScreen(WidgetTester tester, String screenTitle) async {
  final homeFinder = find.byIcon(Icons.home_rounded);
  if (homeFinder.evaluate().isNotEmpty) {
    debugPrint('TEST: Tapping Home button.');
    await tester.tap(homeFinder);
    await tester.pumpAndSettle();
  }

  debugPrint('TEST: Tapping Menu button.');
  await tester.tap(find.byIcon(Icons.menu_rounded));
  await tester.pumpAndSettle();

  debugPrint('TEST: Selecting $screenTitle from menu.');
  await tester.tap(find.text(screenTitle));
  await tester.pumpAndSettle();
}
