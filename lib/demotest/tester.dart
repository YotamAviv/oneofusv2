import 'dart:convert';

import 'package:oneofus_common/crypto/crypto.dart';
import 'package:oneofus_common/crypto/crypto25519.dart';
import 'package:oneofus_common/statement_writer.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/trust_statement.dart';
import '../core/keys.dart';

final crypto = CryptoFactoryEd25519();

class Tester {
  static StatementWriter? writer;
  static Map<String, TestKey> name2key = {};

  static void init(writer) {
    Tester.writer = writer;
  }

  static Future<void> egos() async {
    name2key.clear();
    final TestKey poser = await TestKey.create();
    final TestKey hipster = await TestKey.create();
    final TestKey jock = await TestKey.create();
    name2key['poser'] = poser;
    name2key['hipster'] = hipster;
    name2key['jock'] = jock;

    await doTrust(poser, hipster, moniker: 'Hipster', comment: 'Trusting Hipster');
    await doTrust(hipster, poser, moniker: 'Poser', comment: 'Trusting Poser');
    await doTrust(poser, jock, moniker: 'Jock', comment: 'Trusting Jock');
    await doTrust(jock, poser, moniker: 'Poser', comment: 'Jock trusting Poser');

    TestKey activeDelegate = await TestKey.create();
    await doDelegate(poser, activeDelegate, domain: 'nerdster.org');
    await doDelegate(
      poser,
      await TestKey.create(),
      domain: 'nerdster.org',
      revokeAt: '<since always>',
    );
    await doDelegate(hipster, await TestKey.create(), domain: 'nerdster.org');
    await doDelegate(jock, await TestKey.create(), domain: 'nerdster.org');

    await doBlock(poser, await TestKey.create(), comment: 'spam');
    await doReplace(poser, await TestKey.create(), revokeAt: kSinceAlways, comment: 'lost');

    // --- Overrides and Compromise Simulation ---
    // 1. Overwrites: poser updates previous trusts
    await doTrust(poser, hipster, moniker: 'Hipster (updated)');
    await doTrust(poser, jock, moniker: 'Jock', comment: '(Last Valid)');

    // 2. Fraudulent statements (Simulated compromise)
    await doBlock(poser, hipster, comment: 'Fraudulent block from compromise');
    await doTrust(poser, await TestKey.create(), moniker: 'Fake Friend');

    await Keys().importKeys(
      jsonEncode({kOneofusDomain: poser.keyPairJson, 'nerdster.org': activeDelegate.keyPairJson}),
    );
  }

  static Future<void> longname() async {
    name2key.clear();
    final TestKey poser = await TestKey.create();
    final TestKey hipster = await TestKey.create();
    name2key['poser'] = poser;
    name2key['hipster'] = hipster;

    await doTrust(poser, hipster, moniker: 'Hipster');
    await doTrust(hipster, poser, moniker: 'Poserwith Longname');

    await Keys().importKeys(jsonEncode({kOneofusDomain: poser.keyPairJson}));
  }

  static Future<void> useKey(String key) async {
    await Keys().importKeys(jsonEncode({kOneofusDomain: name2key[key]!.keyPairJson}));
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

  static Future<TrustStatement> doDelegate(
    TestKey i,
    TestKey subject, {
    required String domain,
    String? comment,
    String? revokeAt,
  }) async {
    Json s = TrustStatement.make(
      i.publicKeyJson,
      subject.publicKeyJson,
      TrustVerb.delegate,
      domain: domain,
      comment: comment,
      revokeAt: revokeAt,
    );
    OouSigner signer = await OouSigner.make(i.keyPair);
    await writer!.push(s, signer);
    return TrustStatement(Jsonish(s));
  }

  static Future<TrustStatement> doBlock(TestKey i, TestKey subject, {String? comment}) async {
    Json s = TrustStatement.make(
      i.publicKeyJson,
      subject.publicKeyJson,
      TrustVerb.block,
      comment: comment,
    );
    OouSigner signer = await OouSigner.make(i.keyPair);
    await writer!.push(s, signer);
    return TrustStatement(Jsonish(s));
  }

  static Future<TrustStatement> doReplace(TestKey i, TestKey subject, {String? comment, String? revokeAt}) async {
    Json s = TrustStatement.make(
      i.publicKeyJson,
      subject.publicKeyJson,
      TrustVerb.replace,
      comment: comment,
      revokeAt: revokeAt,
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
