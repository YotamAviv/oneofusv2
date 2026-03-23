import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=net.oneofus.app';

  static const _appStoreUrl = 'https://apps.apple.com/us/app/one-of-us-net/id6739090070';

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final storeUrl = isAndroid ? _playStoreUrl : _appStoreUrl;
    final storeLabel = isAndroid ? 'Open Play Store' : 'Open App Store';

    return Scaffold(
      backgroundColor: const Color(0xFF00897B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 32),
                const Text(
                  'Update Required',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'A required update is available.\nPlease update the app to continue.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () =>
                      launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00897B),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    storeLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
