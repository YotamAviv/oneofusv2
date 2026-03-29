import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/ui/json_display.dart'; // From package
import 'package:app_links/app_links.dart'; // Deep linking
import 'core/config.dart';
import 'core/version_gate.dart';
import 'features/update_required_screen.dart';
import 'ui/app_shell.dart';
import 'ui/app_typography.dart'; // import typography

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Grab the initial deep link immediately so iOS app_links plugin doesn't drop it.
  try {
    final linkString = await AppLinks().getInitialLinkString();
    if (linkString != null) {
      Config.initialDeepLink = Uri.parse(linkString);
    }
  } catch (e) {
    debugPrint('Main: getInitialLinkString failed: \$e');
  }

  await Config.initFirebase();

  // Configure Global JsonDisplay Defaults
  JsonDisplay.defaultTextStyle = AppTypography.mono;
  JsonDisplay.highlightKeys = Set.unmodifiable({
    'I',
    'moniker',
    'domain',
    ...TrustVerb.values.map((e) => e.label),
    ...ContentVerb.values.map((e) => e.label),
  });

  // Check minimum version in background — no startup delay.
  // If blocked, App.updateRequired flips to true and the update screen appears.
  VersionGate.checkInBackground(() => App.updateRequired.value = true);

  runApp(const App());
}

class App extends StatelessWidget {
  /// Flipped to true by VersionGate if the running version is below the minimum.
  static final ValueNotifier<bool> updateRequired = ValueNotifier(false);

  final bool isTesting;
  final FirebaseFirestore? firestore;

  const App({
    super.key,
    this.isTesting = false,
    this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: App.updateRequired,
      builder: (context, blocked, _) {
        return MaterialApp(
          title: 'ONE-OF-US.NET',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00897B),
              primary: const Color(0xFF00897B),
            ),
            useMaterial3: true,
          ),
          home: blocked
              ? const UpdateRequiredScreen()
              : AppShell(
                  isTesting: isTesting,
                  firestore: firestore,
                ),
        );
      },
    );
  }
}
