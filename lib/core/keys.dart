import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';

/// A singleton class responsible for managing the user's cryptographic keys.
class Keys extends ChangeNotifier {
  // --- Singleton Setup ---
  static final Keys _instance = Keys._internal();
  factory Keys() => _instance;
  Keys._internal();

  // --- V1 Compatibility Constants ---
  static const _storage = FlutterSecureStorage();
  static const String _storageKey = kOneofusDomain; // 'one-of-us.net'

  // --- Internal State ---
  Map<String, OouKeyPair> _keys = {};
  String? _identityToken;
  final Set<String> _delegateTokens = {};
  bool _isLoaded = false;

  /// Returns true if the keyring has been loaded from secure storage.
  bool get isLoaded => _isLoaded;

  /// The user's primary identity key pair. Returns null if not loaded.
  OouKeyPair? get identity {
    assert(_isLoaded, 'Keys must be loaded before accessing identity.');
    return _keys[kOneofusDomain];
  }

  /// Returns the SHA-1 token of the current identity public key.
  String? get identityToken {
    assert(_isLoaded, 'Keys must be loaded before accessing identityToken.');
    return _identityToken;
  }

  /// Retrieves the delegate key pair for a specific service domain.
  OouKeyPair? delegate(String domain) {
    if (domain == kOneofusDomain) {
      throw ArgumentError('Use identity property to access the primary identity key.');
    }
    return _keys[domain];
  }

  /// FOR TESTING ONLY: Loads a specific private key as the main identity.
  Future<void> loadForTest(Json privateKey) async {
    const factory = CryptoFactoryEd25519();
    final keyPair = await factory.parseKeyPair(privateKey);
    _keys = {kOneofusDomain: keyPair};
    await refreshTokens();
    _isLoaded = true;
  }

  /// Refreshes the cached tokens from the current key pairs.
  Future<void> refreshTokens() async {
    _delegateTokens.clear();
    for (final entry in _keys.entries) {
      final domain = entry.key;
      final key = entry.value;
      final pubKey = await key.publicKey;
      final token = getToken(await pubKey.json);
      if (domain == kOneofusDomain) {
        _identityToken = token;
      } else {
        _delegateTokens.add(token);
      }
    }

    if (!_keys.containsKey(kOneofusDomain)) {
      _identityToken = null;
    }
    notifyListeners();
  }

  /// Returns true if the token matches the current primary identity.
  bool isIdentityToken(String? token) => token != null && token == _identityToken;

  /// Returns true if the token matches any of the stored delegate keys.
  bool isDelegateToken(String? token) => token != null && _delegateTokens.contains(token);

  /// Loads all keys from secure storage.
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
      await refreshTokens();
      _isLoaded = true;
      return identity != null;
    } catch (e) {
      _isLoaded = true;
      throw Exception('Failed to load keys from secure storage. The data may be corrupted: $e');
    }
  }

  /// Generates a new primary identity key, saves it, and makes it active.
  Future<OouKeyPair> newIdentity() async {
    final newIdentity = await const CryptoFactoryEd25519().createKeyPair();
    _keys[kOneofusDomain] = newIdentity;
    await refreshTokens();
    await _save();
    return newIdentity;
  }

  /// Generates a new delegate key for a service, saves it, and returns it.
  Future<OouKeyPair> newDelegate(String domain) async {
    if (domain == kOneofusDomain) {
      throw ArgumentError('Cannot create a delegate for the identity domain.');
    }
    if (!domain.contains('.') || domain.length < 3) {
      throw ArgumentError('Invalid domain name: $domain');
    }
    final newDelegate = await const CryptoFactoryEd25519().createKeyPair();
    _keys[domain] = newDelegate;
    await refreshTokens();
    await _save();
    return newDelegate;
  }
  
  Future<void> importKeys(String jsonString) async {
    final Map<String, dynamic> keyMap;
    try {
      keyMap = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Invalid JSON format: $e');
    }

    if (!keyMap.containsKey(kOneofusDomain)) {
      throw Exception('Invalid key file: Missing primary identity key ($kOneofusDomain).');
    }

    // Validate that all entries can be parsed as valid Ed25519 key pairs
    const factory = CryptoFactoryEd25519();
    try {
      for (final entry in keyMap.entries) {
        final keyData = entry.value as Map<String, dynamic>;
        await factory.parseKeyPair(keyData);
      }
    } catch (e) {
      throw Exception('Invalid key data in file: $e');
    }

    await _storage.write(key: _storageKey, value: jsonString);
    _keys = {};
    _isLoaded = false;
    await load();

    notifyListeners();
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

  // s/clearAll/wipe
  /// COMPLETELY WIPES all keys from memory and secure storage.
  Future<void> clearAll() async {
    await _storage.delete(key: _storageKey);
    _keys.clear();
    _identityToken = null;
    _isLoaded = false;
    notifyListeners();
  }
}
