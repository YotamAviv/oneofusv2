import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/config.dart';
import 'ui/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.initFirebase();

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

