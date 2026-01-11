import 'jsonish.dart';

abstract class OouCryptoFactory {
  Future<OouKeyPair> createKeyPair();
  Future<OouKeyPair> parseKeyPair(Json json);
  Future<OouPublicKey> parsePublicKey(Json json);

  Future<PkeKeyPair> createPke();
  Future<PkeKeyPair> parsePkeKeyPair(Json json);
  Future<PkePublicKey> parsePkePublicKey(Json json);
}

abstract class OouKeyPair {
  Future<Json> get json;
  Future<OouPublicKey> get publicKey;
  Future<String> sign(String cleartext);
  Future<String> encryptForSelf(String cleartext);
  Future<String> decryptFromSelf(String ciphertext);
  Future<String> encrypt(String cleartext, OouPublicKey otherPublicKey);
  Future<String> decrypt(String ciphertext);
}

abstract class OouPublicKey {
  Future<Json> get json;
  Future<bool> verifySignature(String cleartext, String signature);
}

abstract class PkeKeyPair {
  Future<PkePublicKey> get publicKey;
  Future<Json> get json;
  Future<String> encrypt(String cleartext, PkePublicKey otherPublicKey);
  Future<String> decrypt(String ciphertext, PkePublicKey otherPublicKey);
}

abstract class PkePublicKey {
  Future<Json> get json;
}
