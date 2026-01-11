import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:jwk/jwk.dart';

import 'jsonish.dart';
import 'crypto.dart';

final ed25519 = Ed25519();
final x25519 = X25519();
final aesGcm256 = AesGcm.with256bits();

const nonceLength = 12;
const macLength = 16;

class _PublicKey implements OouPublicKey {
  final PublicKey _publicKey;

  _PublicKey(this._publicKey);

  @override
  Future<Json> get json async {
    final Jwk jwk = Jwk.fromPublicKey(_publicKey);
    return jwk.toJson();
  }

  @override
  Future<bool> verifySignature(String cleartext, String signatureHex) async {
    Signature signature = Signature(hex.decode(signatureHex), publicKey: _publicKey);
    return await ed25519.verifyString(cleartext, signature: signature);
  }
}

class _KeyPair implements OouKeyPair {
  final SimpleKeyPair _keyPair;

  _KeyPair(this._keyPair);

  @override
  Future<Json> get json async {
    Jwk jwk = await Jwk.fromKeyPair(_keyPair);
    return jwk.toJson();
  }

  @override
  Future<OouPublicKey> get publicKey async {
    PublicKey publicKey = await _keyPair.extractPublicKey();
    return _PublicKey(publicKey);
  }

  @override
  Future<String> sign(String cleartext) async {
    final signature = await ed25519.signString(
      cleartext,
      keyPair: _keyPair,
    );
    return hex.encode(signature.bytes);
  }

  @override
  Future<String> encryptForSelf(String cleartext) async {
    final secretBytes = await _keyPair.extractPrivateKeyBytes();
    SecretKey secretKey = SecretKey(secretBytes);
    final secretBox = await aesGcm256.encryptString(
      cleartext,
      secretKey: secretKey,
    );
    return hex.encode(secretBox.concatenation());
  }

  @override
  Future<String> decryptFromSelf(String ciphertext) async {
    List<int> bytes = hex.decode(ciphertext);
    SecretBox secretBox = SecretBox.fromConcatenation(bytes, nonceLength: nonceLength, macLength: macLength);
    final secretBytes = await _keyPair.extractPrivateKeyBytes();
    SecretKey secretKey = SecretKey(secretBytes);
    return await aesGcm256.decryptString(
      secretBox,
      secretKey: secretKey,
    );
  }

  @override
  Future<String> encrypt(String cleartext, OouPublicKey otherPublicKey) {
    throw UnimplementedError();
  }

  @override
  Future<String> decrypt(String ciphertext) {
    throw UnimplementedError();
  }
}

class CryptoFactoryEd25519 implements OouCryptoFactory {
  const CryptoFactoryEd25519();

  @override
  Future<OouKeyPair> createKeyPair() async {
    SimpleKeyPair keyPair = await ed25519.newKeyPair();
    return _KeyPair(keyPair);
  }

  @override
  Future<OouKeyPair> parseKeyPair(Json json) async {
    final jwk = Jwk.fromJson(json);
    final SimpleKeyPair keyPair = jwk.toKeyPair() as SimpleKeyPair;
    return _KeyPair(keyPair);
  }

  @override
  Future<OouPublicKey> parsePublicKey(Json json) async {
    final jwk = Jwk.fromJson(json);
    final PublicKey? publicKey = jwk.toPublicKey();
    return _PublicKey(publicKey!);
  }

  @override
  Future<PkeKeyPair> createPke() async {
    final SimpleKeyPair keyPair = await x25519.newKeyPair();
    return _PkeKeyPair(keyPair);
  }

  @override
  Future<PkeKeyPair> parsePkeKeyPair(Json json) async {
    throw UnimplementedError();
  }

  @override
  Future<PkePublicKey> parsePkePublicKey(Json json) async {
    final Jwk jwk = Jwk.fromJson(json);
    final PublicKey? publicKey = jwk.toPublicKey();
    return _PkePublicKey(publicKey!);
  }
}

class _PkeKeyPair implements PkeKeyPair {
  final SimpleKeyPair keyPair;

  _PkeKeyPair(this.keyPair);

  @override
  Future<String> encrypt(String cleartext, PkePublicKey otherPublicKey) async {
    final SecretKey sharedSecret = await x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: (otherPublicKey as _PkePublicKey).publicKey,
    );
    final secretBox = await aesGcm256.encryptString(
      cleartext,
      secretKey: sharedSecret,
    );
    return hex.encode(secretBox.concatenation());
  }

  @override
  Future<String> decrypt(String ciphertext, PkePublicKey otherPublicKey) async {
    final SecretKey sharedSecret = await x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: (otherPublicKey as _PkePublicKey).publicKey,
    );
    List<int> bytes = hex.decode(ciphertext);
    SecretBox secretBox = SecretBox.fromConcatenation(bytes, nonceLength: nonceLength, macLength: macLength);
    return await aesGcm256.decryptString(
      secretBox,
      secretKey: sharedSecret,
    );
  }

  @override
  Future<Json> get json async {
    Jwk jwk = await Jwk.fromKeyPair(keyPair);
    return jwk.toJson();
  }

  @override
  Future<PkePublicKey> get publicKey async {
    SimplePublicKey simplePublicKey = await keyPair.extractPublicKey();
    return _PkePublicKey(simplePublicKey);
  }
}

class _PkePublicKey implements PkePublicKey {
  final PublicKey publicKey;

  _PkePublicKey(this.publicKey);

  @override
  Future<Json> get json async {
    Jwk jwk = Jwk.fromPublicKey(publicKey);
    return jwk.toJson();
  }
}
