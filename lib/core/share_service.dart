import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'keys.dart';
import '../ui/app_typography.dart';

class ShareService {
  static const String homeUrl = 'https://one-of-us.net';

  static Future<void> shareIdentityPackage() async {
    final Json pubKeyJson = (await Keys().getIdentityPublicKeyJson())!;
    final String minJson = jsonEncode(Jsonish(pubKeyJson).json);
    final String base64Key = base64Url.encode(utf8.encode(minJson));

    final String deepLink = "$homeUrl/vouch.html#$base64Key";

    // DEBUG: Print link for testing in emulator
    debugPrint('deepLink: $deepLink');

    final String message =
        '''We're building a decentralized identity network.

Vouch for me using this link: $deepLink
''';

    await SharePlus.instance.share(ShareParams(text: message, subject: 'Vouch for my identity'));
  }

  static void showQrDialog(BuildContext context, String data, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppTypography.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(data: data, version: QrVersions.auto, gapless: false),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }
}
