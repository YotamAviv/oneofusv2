import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';

/// A singleton class responsible for managing the user's cryptographic keys.
///
/// It handles loading keys from and saving them to secure storage
/// Must maintain compatibility with the V1 app's data structure.
///
/// Source for
/// - user's primary identity key
/// - service delegate keys.
class Keys {
  // --- Singleton Setup ---
  static final Keys _instance = Keys._internal();
  factory Keys() => _instance;
  Keys._internal();

  // --- V1 Compatibility Constants ---
  static const _storage = FlutterSecureStorage();
  static const String _storageKey = kOneofusDomain; // 'one-of-us.net'

  // --- Internal State ---
  Map<String, OouKeyPair> _keys = {};
  bool _isLoaded = false;

  /// Returns true if the keyring has been loaded from secure storage.
  bool get isLoaded => _isLoaded;

  /// The user's primary identity key pair. Returns null if not loaded.
  OouKeyPair? get identity => _keys[kOneofusDomain];

  /// Retrieves the delegate key pair for a specific service domain.
  /// Returns null if no delegate key exists for that domain.
  OouKeyPair? delegate(String domain) => _keys[domain];

  /// Loads all keys from secure storage.
  ///
  /// Returns `true` if a primary identity key was found, `false` otherwise.
  /// This is used by the UI to decide whether to show the main screen or
  /// the onboarding flow.
  Future<bool> load() async {
    if (_isLoaded) return identity != null;

    final jsonString = await _storage.read(key: _storageKey);
    if (jsonString == null) {
      _isLoaded = true;
      return false;
    }

    try {
      final keyMapJson = jsonDecode(jsonString) as Map<String, dynamic>;
      final Map<String, OouKeyPair> loadedKeys = {};
      const factory = CryptoFactoryEd25519();

      for (final entry in keyMapJson.entries) {
        final keyJson = entry.value as Map<String, dynamic>;
        loadedKeys[entry.key] = await factory.parseKeyPair(keyJson);
      }
      _keys = loadedKeys;
      _isLoaded = true;
      return identity != null;
    } catch (e) {
      // Data is corrupted or in an unexpected format. Treat as no keys found.
      _isLoaded = true;
      return false;
    }
  }

  /// Generates a new primary identity key, saves it, and makes it active.
  Future<OouKeyPair> newIdentity() async {
    final newIdentity = await const CryptoFactoryEd25519().createKeyPair();
    _keys[kOneofusDomain] = newIdentity;
    await _save();
    return newIdentity;
  }

  /// Generates a new delegate key for a service, saves it, and returns it.
  Future<OouKeyPair> newDelegate(String domain) async {
    final newDelegate = await const CryptoFactoryEd25519().createKeyPair();
    _keys[domain] = newDelegate;
    await _save();
    return newDelegate;
  }
  
  Future<void> importKeys(String jsonString) async {
    // 1. Validate the JSON before saving.
    final keyMap = jsonDecode(jsonString) as Map<String, dynamic>;
    if (!keyMap.containsKey(kOneofusDomain)) {
      throw Exception('Invalid key file: Missing primary identity key.');
    }

    // 2. Overwrite the raw string in secure storage.
    await _storage.write(key: _storageKey, value: jsonString);

    // 3. Reset the internal state to force a reload.
    _keys = {};
    _isLoaded = false;
    await load();
    assert(isLoaded);
  }

  /// Returns the SHA-1 token of the current identity public key.
  Future<String?> getIdentityToken() async {
    if (identity == null) return null;
    final pubKey = await identity!.publicKey;
    final json = await pubKey.json;
    return getToken(json);
  }

  /// Returns the full public key JSON of the current identity.
  Future<Json?> getIdentityPublicKeyJson() async {
    if (identity == null) return null;
    final pubKey = await identity!.publicKey;
    return await pubKey.json;
  }

  /// Returns a map of all stored keys in their raw JSON format.
  Future<Map<String, Json>> getAllKeyJsons() async {
    final Map<String, Json> keyMapJson = {};
    for (final entry in _keys.entries) {
      keyMapJson[entry.key] = await entry.value.json;
    }
    return keyMapJson;
  }

  /// Serializes all keys to the V1-compatible map and saves to secure storage.
  Future<void> _save() async {
    final Map<String, Json> keyMapJson = await getAllKeyJsons();
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(keyMapJson),
    );
  }
}
