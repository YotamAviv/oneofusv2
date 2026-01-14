import 'package:collection/collection.dart';
import 'crypto.dart';
import 'jsonish.dart';

class OouSigner implements StatementSigner {
  final OouKeyPair _keyPair;
  final Json _publicKeyJson;

  static Future<OouSigner> make(OouKeyPair keyPair) async {
    OouPublicKey publicKey = await keyPair.publicKey;
    Json publicKeyJson = await publicKey.json;
    return OouSigner._internal(keyPair, publicKeyJson);
  }
  
  OouSigner._internal(this._keyPair, this._publicKeyJson);

  @override
  Future<String> sign(Map<String, dynamic> json, String string) async {
    // Note: Using deep collection equality check for the public key
    if (!const DeepCollectionEquality().equals(json['I'], _publicKeyJson)) {
       throw Exception('Signer public key does not match statement "I" field');
    }
    return await _keyPair.sign(string);
  }
}
