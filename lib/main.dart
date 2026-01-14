import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/config.dart';
import 'firebase_options.dart';
import 'ui/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Config.fireChoice == FireChoice.emulator) {
    // Connect to local Firebase Emulators
    // 10.0.2.2 is the magic IP for the Android Emulator to reach the host machine
    FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8081);
  }

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
      home: MainScreen(
        isTesting: isTesting,
        firestore: firestore,
      ),
    );
  }
}

