import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'keys.dart';
import '../ui/app_typography.dart';

class ShareService {
  static const String homeUrl = 'https://one-of-us.net';

  static Future<void> shareIdentityPackage() async {
    final Json pubKeyJson = (await Keys().getIdentityPublicKeyJson())!;
    final String prettyJson = Jsonish(pubKeyJson).ppJson;
    final String minJson = jsonEncode(Jsonish(pubKeyJson).json);
    final String base64Key = base64Url.encode(utf8.encode(minJson));
    final String token = Keys().identityToken!;

    final String deepLink = "$homeUrl/vouch.html#$base64Key";

    // DEBUG: Print link for easy testing in emulator
    debugPrint('SHARE LINK: $deepLink');

    final String message = '''We're building a decentralized identity network.
Use this link to vouch for my identity: $deepLink

App store links and more at: https://one-of-us.net

In case the link doesn't work, use your ONE-OF-US.NET phone app to scan the QR code or copy/paste the text below:


$prettyJson


''';

    final Uint8List imageBytes = await _generateQrImage(prettyJson);
    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/oneofus_id_$token.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(imageBytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(imagePath)], text: message, subject: 'Vouch for my identity'),
    );
  }

  static Future<void> shareIdentityText() async {
    final Json pubKeyJson = (await Keys().getIdentityPublicKeyJson())!;
    final String text = Jsonish(pubKeyJson).ppJson;
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'ONE-OF-US.NET Public Identity Key'),
    );
  }

  static Future<void> shareIdentityQr() async {
    final Json pubKeyJson = (await Keys().getIdentityPublicKeyJson())!;
    final String text = Jsonish(pubKeyJson).ppJson;
    final String token = Keys().identityToken!;
    await _shareQrImage(text, 'oneofus_id_$token.png', 'ONE-OF-US.NET Public Identity Key QR');
  }

  static Future<void> shareHomeLink() async {
    await SharePlus.instance.share(ShareParams(text: homeUrl, subject: 'ONE-OF-US.NET'));
  }

  static Future<void> _shareQrImage(String data, String fileName, String subject) async {
    final Uint8List imageBytes = await _generateQrImage(data);
    final directory = await getTemporaryDirectory();
    final imagePath = '${directory.path}/$fileName';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(imageBytes);

    await SharePlus.instance.share(ShareParams(files: [XFile(imagePath)], subject: subject));
  }

  static Future<Uint8List> _generateQrImage(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );

    final ui.Image image = await painter.toImage(1024);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
