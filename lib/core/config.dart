import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../firebase_options.dart';

enum FireChoice { fake, emulator, prod }

class Config {
  // --- Hard coded - use for Environment Switch ---
  static final FireChoice _fireChoice = FireChoice.emulator;

  static FireChoice get fireChoice => _fireChoice;

  static String get _emulatorHost {
    if (kIsWeb) return 'localhost';
    // 10.0.2.2 is for Android Emulator, localhost for Desktop/iOS Simulator
    return (defaultTargetPlatform == TargetPlatform.android) ? '10.0.2.2' : 'localhost';
  }

  static Future<void> initFirebase() async {
    if (fireChoice != FireChoice.fake) {
      FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(options: options);
      if (fireChoice == FireChoice.emulator) {
        FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8081);
      }
    }
  }

  static FirebaseFirestore? _db;
  static FirebaseFirestore get db {
    _db ??= (fireChoice == FireChoice.fake ? FakeFirebaseFirestore() : FirebaseFirestore.instance);
    return _db!;
  }

  /// Safety check for tests or destructive operations
  static void ensureNotProd() {
    debugPrint('fireChoice=$fireChoice');
    if (fireChoice == FireChoice.prod) {
      throw StateError("Operation not allowed in production environment!");
    }
  }

  // --- Service Registry (formerly V2Config) ---
  static final Map<String, String> _urls = {};

  static void registerUrl(String domain, String url) {
    _urls[domain] = url;
  }

  static String? getUrl(String domain) => _urls[domain];

  static Uri makeSimpleUri(String domain, dynamic spec, {String? revokeAt}) {
    final String? baseUrl = getUrl(domain);
    if (baseUrl == null) {
      return Uri.parse('about:blank');
    }

    final uri = Uri.parse(baseUrl);
    final params = <String, String>{'spec': jsonEncode(spec)};
    if (revokeAt != null) {
      params['revokeAt'] = revokeAt;
    }

    final newParams = Map<String, String>.from(uri.queryParameters)..addAll(params);
    return uri.replace(queryParameters: newParams);
  }

  // --- Static Named Endpoints ---
  static String get exportUrl {
    switch (fireChoice) {
      case FireChoice.emulator:
        return 'http://$_emulatorHost:5002/one-of-us-net/us-central1/export';
      case FireChoice.prod:
      default:
        return 'https://export.one-of-us.net';
    }
  }

  /// This is the endpoint we tell the server to use when it needs to fetch data.
  /// If the server is also running in an emulator on the same host, it should use 127.0.0.1.
  static String get exportUrlForServer {
    switch (fireChoice) {
      case FireChoice.emulator:
        return 'http://127.0.0.1:5002/one-of-us-net/us-central1/export';
      case FireChoice.prod:
      default:
        return 'https://export.one-of-us.net';
    }
  }

  static String get signInUrl {
    switch (fireChoice) {
      case FireChoice.emulator:
        return 'http://$_emulatorHost:5001/nerdster/us-central1/signin';
      case FireChoice.prod:
      default:
        return 'https://signin.nerdster.org/signin';
    }
  }
}
