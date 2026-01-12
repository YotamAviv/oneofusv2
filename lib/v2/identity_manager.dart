import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/trust_statement.dart'; // For kOneofusDomain

class IdentityManager {
  static const _storage = FlutterSecureStorage();
  
  // The master key in FlutterSecureStorage used by V1
  static const String _storageKey = kOneofusDomain; // 'one-of-us.net'
  
  OouKeyPair? _identityKeyPair;
  Map<String, dynamic> _allKeyPairs = {};
  
  OouKeyPair? get identityKeyPair => _identityKeyPair;

  /// Returns a snapshot of all stored key pairs (Identity and Delegates) in raw JSON format.
  Future<Map<String, dynamic>> getAllKeyPairs() async {
    return _allKeyPairs;
  }

  /// Loads the identity key from secure storage using V1 naming conventions.
  /// Returns true if a key was found and loaded.
  Future<bool> loadIdentity() async {
    final jsonString = await _storage.read(key: _storageKey);
    if (jsonString == null) return false;

    try {
      _allKeyPairs = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // V1 stores the primary identity under the domain name key
      final identityKeyJson = _allKeyPairs[kOneofusDomain];
      if (identityKeyJson == null) return false;

      _identityKeyPair = await const CryptoFactoryEd25519().parseKeyPair(identityKeyJson);
      return true;
    } catch (e) {
      // Parsing failed or format mismatch
      return false;
    }
  }

  /// Generates a new identity key and saves it to secure storage in V1 format.
  Future<void> generateNewIdentity() async {
    _identityKeyPair = await const CryptoFactoryEd25519().createKeyPair();
    final json = await _identityKeyPair!.json;
    
    // Maintain the V1 map structure
    _allKeyPairs[kOneofusDomain] = json;
    
    await _storage.write(
      key: _storageKey, 
      value: jsonEncode(_allKeyPairs)
    );
  }

  /// Returns the current identity's public key as JSON.
  Future<Json?> getPublicKeyJson() async {
    if (_identityKeyPair == null) return null;
    final publicKey = await _identityKeyPair!.publicKey;
    return await publicKey.json;
  }

  /// Returns the current identity's token.
  Future<String?> getIdentityToken() async {
    final json = await getPublicKeyJson();
    if (json == null) return null;
    return getToken(json);
  }
}
