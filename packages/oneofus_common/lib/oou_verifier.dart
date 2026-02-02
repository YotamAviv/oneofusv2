import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/jsonish.dart';

class OouVerifier implements StatementVerifier {
  @override
  Future<bool> verify(Map<String, dynamic> json, String string, signature) async {
    try {
      const factory = CryptoFactoryEd25519();
      OouPublicKey author = await factory.parsePublicKey(json['I']!);
      bool out = await author.verifySignature(string, signature);
      return out;
    } catch (e) {
      return false;
    }
  }
}
