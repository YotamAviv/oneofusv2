import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/oou_signer.dart';
import 'package:oneofus_common/util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config.dart';
import 'keys.dart';

class SignInService {
  static const Map<String, String> _headers = {'Content-Type': 'application/json; charset=UTF-8'};

  static Future<bool> validateSignIn(String scanned) async {
    // uri, publicKey: Older phone apps, recently removed
    try {
      final Json received = jsonDecode(scanned);
      return (received.containsKey('domain')) &&
          received.containsKey('url') &&
          received.containsKey('encryptionPk');
    } catch (e) {
      return false;
    }
  }

  static Future<void> signIn(String scanned, BuildContext context, {FirebaseFirestore? firestore}) async {
    try {
      if (!await validateSignIn(scanned)) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid sign-in data')));
        }
        return;
      }

      final Json received = jsonDecode(scanned);
      final String domain = received['domain']!;
      final String urlKey = 'url';
      final String encryptionPkKey = 'encryptionPk';

      final keys = Keys();
      assert (keys.identity != null, 'No identity key.. Unexpected.');

      final factory = const CryptoFactoryEd25519();

      // 1. Prepare PKE for secure transfer
      final Json webPkePublicKeyJson = received[encryptionPkKey]!;
      final String session = getToken(webPkePublicKeyJson);
      final PkePublicKey webPkePublicKey = await factory.parsePkePublicKey(webPkePublicKeyJson);
      final PkeKeyPair myPkeKeyPair = await factory.createPke();
      final PkePublicKey myPkePublicKey = await myPkeKeyPair.publicKey;

      // 2. Get or Create Delegate Key
      OouKeyPair? delegateKeyPair = keys.delegate(domain);
      if (delegateKeyPair == null) {
        final bool? proceed = await _showCreateDelegateDialog(context, domain);
        if (proceed == true) {
          delegateKeyPair = await keys.newDelegate(domain);

          final identity = keys.identity!;
          final pubKeyJson = await (await delegateKeyPair.publicKey).json;
          final iPubKeyJson = await (await identity.publicKey).json;

          final statementJson = TrustStatement.make(
            iPubKeyJson,
            pubKeyJson,
            TrustVerb.delegate,
            domain: domain,
          );

          final writer = DirectFirestoreWriter(firestore ?? FirebaseFirestore.instance);
          final signer = await OouSigner.make(identity);
          await writer.push(statementJson, signer);
        } else if (proceed == null) {
          // User cancelled
          return;
        }
        // If proceed is false, we continue with just identity (no delegate)
      }

      // 3. Prepare Payload
      final identityPubKeyJson = await (await keys.identity!.publicKey).json;
      final Map<String, dynamic> send = {
        'date': clock.nowIso,
        'identity': identityPubKeyJson,
        'session': session,
        'endpoint': Config.exportUrlForServer,
      };

      if (delegateKeyPair != null) {
        send['ephemeralPK'] = await myPkePublicKey.json;
        final delegateKeyPairJson = await delegateKeyPair.json;
        final String delegateCleartext = jsonEncode(delegateKeyPairJson);
        final String delegateCiphertext = await myPkeKeyPair.encrypt(
          delegateCleartext,
          webPkePublicKey,
        );
        send['delegateCiphertext'] = delegateCiphertext;
      }

      // 4. Send POST
      Uri uri = Uri.parse(received[urlKey]);

      // Handle Android Emulator localhost mapping if needed
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        // This is a common pattern for local dev
        uri = uri.replace(host: '10.0.2.2');
      }

      final response = await http.post(uri, headers: _headers, body: jsonEncode(send));

      if (context.mounted) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Successfully signed in to $domain')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign in failed: ${response.statusCode} - ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error during sign in: $e')));
      }
    }
  }

  static Future<bool?> _showCreateDelegateDialog(BuildContext context, String domain) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Delegate Key?'),
          content: Text(
            'You are signing in to $domain. Would you like to create a delegate key for this service?\n\n'
            'This allows the service to act on your behalf without having access to your primary identity key.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            TextButton(
              child: const Text('No, just identity'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes, create delegate'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }
}
