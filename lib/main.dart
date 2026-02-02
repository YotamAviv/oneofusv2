import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/ui/json_display.dart'; // From package
import 'core/config.dart';
import 'ui/app_shell.dart';
import 'ui/app_typography.dart'; // import typography

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(const App());
}

class App extends StatelessWidget {
  final bool isTesting;
  final FirebaseFirestore? firestore;

  const App({
    super.key,
    this.isTesting = false,
    this.firestore,
  });

  @override
  Widget build(BuildContext context) {
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
      home: AppShell(
        isTesting: isTesting,
        firestore: firestore,
      ),
    );
  }
}

