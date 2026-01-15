import 'dart:convert';

import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/io.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/trust_statement.dart';
import '../core/keys.dart';

final crypto = CryptoFactoryEd25519();

class Tester {
  static StatementWriter? writer;

  static void init(writer) {
    Tester.writer = writer;
  }

  static Future<void> egos() async {
    final TestKey poser = await TestKey.create();
    final TestKey hipster = await TestKey.create();
    final TestKey jock = await TestKey.create();

    await doTrust(poser, hipster, moniker: 'Hipster', comment: 'Trusting Hipster');
    await doTrust(hipster, poser, moniker: 'Poser', comment: 'Trusting Poser');
    await doTrust(poser, jock, moniker: 'Jock', comment: 'Trusting Jock');

    await Keys().importKeys(jsonEncode({kOneofusDomain: poser.keyPairJson}));
  }

  static Future<void> longname() async {
    final TestKey poser = await TestKey.create();
    final TestKey hipster = await TestKey.create();

    await doTrust(poser, hipster, moniker: 'Hipster');
    await doTrust(hipster, poser, moniker: 'Poserwith Longname');

    await Keys().importKeys(jsonEncode({kOneofusDomain: poser.keyPairJson}));
  }

  static Map tests = {'egos': egos, 'longname': longname};

  static Future<TrustStatement> doTrust(
    TestKey i,
    TestKey subject, {
    required String moniker,
    String? comment,
  }) async {
    Json s = TrustStatement.make(
      i.publicKeyJson,
      subject.publicKeyJson,
      TrustVerb.trust,
      moniker: moniker,
      comment: comment,
    );
    OouSigner signer = await OouSigner.make(i.keyPair);
    await writer!.push(s, signer);
    return TrustStatement(Jsonish(s));
  }
}

class TestKey {
  final OouKeyPair keyPair;
  final Json keyPairJson;
  final Json publicKeyJson;

  TestKey.internal(this.keyPair, this.keyPairJson, this.publicKeyJson);

  static Future<TestKey> create() async {
    final keyPair = await crypto.createKeyPair();
    final Json keyPairJson = await keyPair.json;
    final publicKey = await keyPair.publicKey;
    final Json publicKeyJson = await publicKey.json;
    return TestKey.internal(keyPair, keyPairJson, publicKeyJson);
  }
}
