import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/crypto.dart';
import 'package:oneofus_common/crypto25519.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/direct_firestore_writer.dart';
import 'package:oneofus_common/oou_signer.dart';
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

  /// Returns `true` if the sign-in was successful (and any new delegate statement published).
  /// Returns `false` if the sign-in failed or was cancelled by the user.
  static Future<bool> signIn(String scanned, BuildContext context, {
    FirebaseFirestore? firestore,
    List<TrustStatement>? myStatements,
    VoidCallback? onSending,
  }) async {
    try {
      if (!await validateSignIn(scanned)) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid sign-in data')));
        }
        return false;
      }

      final Json received = jsonDecode(scanned);
      final String domain = received['domain']!;
      final String urlKey = 'url';
      final String urlString = received[urlKey]!;
      final String encryptionPkKey = 'encryptionPk';

      // 1. Verify that the URL matches the domain specified.
      final Uri uri = Uri.parse(urlString);
      final String host = uri.host;
      if (host != domain && !host.endsWith('.$domain')) {
        // Allow local development overrides (Android emulator, localhost)
        final bool isLocal = host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
        if (!isLocal) {
          throw Exception('Security mismatch: Sign-in URL ($urlString) does not match the service domain ($domain)');
        }
      }

      final Keys keys = Keys();
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
          // If we have cached statements, check if a delegate already exists for this domain
          if (myStatements != null && context.mounted) {
            final existing = myStatements.where((s) => 
              s.verb == TrustVerb.delegate && s.domain == domain
            ).firstOrNull;

            if (existing != null) {
              final bool rotate = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Existing Delegate Found'),
                  content: Text(
                    'The network shows you already have a delegate for $domain, '
                    'but the key is not on this device. \n\n'
                    'Creating a new one will rotate your delegate for this service. Proceed?'
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ROTATE KEY')),
                  ],
                ),
              ) ?? false;
              
              if (!rotate) return false;
            }
          }

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
          return false;
        }
        // If proceed is false, we continue with just identity (no delegate)
      }

      // 3. Prepare Payload
      final identityPubKeyJson = await (await keys.identity!.publicKey).json;

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Unknown';
      String osVersion = 'Unknown';

      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }

      final Map<String, dynamic> send = {
        'identity': identityPubKeyJson,
        'session': session,
        'endpoint': Config.exportUrlForServer,
        'appInfo': {
          'appName': packageInfo.appName,
          'packageName': packageInfo.packageName,
          'version': packageInfo.version,
          'buildNumber': packageInfo.buildNumber,
        },
        'deviceInfo': {
          'device': deviceName,
          'os': osVersion,
          'platform': Platform.operatingSystem,
        },
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
        // 'uri' was already parsed and verified at the beginning of this method.
        Uri postUri = uri;

        // Handle Android Emulator localhost mapping if needed
        if (postUri.host == 'localhost' || postUri.host == '127.0.0.1') {
          // This is a common pattern for local dev
          postUri = postUri.replace(host: '10.0.2.2');
        }

        final response = await http.post(postUri, headers: _headers, body: jsonEncode(send));

        if (onSending != null) onSending();

      if (context.mounted) {
        String message = delegateKeyPair != null
            ? 'Sent identity public key and delegate public/private key pair to $domain'
            : 'Sent identity public key to $domain';
        if (response.statusCode >= 200 && response.statusCode < 300) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign in failed: ${response.statusCode} - ${response.body}')),
          );
          return false;
        }
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error during sign in: $e')));
      }
      return false;
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
