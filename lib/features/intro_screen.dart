import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../ui/app_typography.dart';

class IntroScreen extends StatelessWidget {
  final VoidCallback? onShowWelcome;

  const IntroScreen({super.key, this.onShowWelcome});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          const Text(
            'INTRO',
            style: AppTypography.header,
          ),
          const SizedBox(height: 24),
          const Text(
            'Our Own Decentralized, Heterogeneous Identity Network',
            style: AppTypography.hero,
          ),
          const SizedBox(height: 24),
          const Text(
            '''If you believe that knowing who's who is important, who should be the authority? Us, right?''',
            style: AppTypography.body,
          ),
          const SizedBox(height: 40),
          const Text(
            '''We're building our own human identity network by cryptographically signing each other's public keys, creating a web of trust. Share the app and vouch for us humans.''',
            style: AppTypography.body,
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: "That network (our network) can be leveraged anywhere. Try signing in to the Nerdster (",
                  style: AppTypography.body,
                ),
                TextSpan(
                  text: "https://nerdster.org",
                  style: AppTypography.link,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(
                          Uri.parse("https://nerdster.org"),
                          mode: LaunchMode.externalApplication,
                        ),
                ),
                const TextSpan(
                  text: ") and see.",
                  style: AppTypography.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: "Read more at ",
                  style: AppTypography.body,
                ),
                TextSpan(
                  text: "https://one-of-us.net",
                  style: AppTypography.link,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(Uri.parse("https://one-of-us.net")),
                ),
              ],
            ),
          ),
          if (onShowWelcome != null) ...[
            const SizedBox(height: 40),
            Center(
              child: TextButton(
                onPressed: onShowWelcome,
                child: const Text(
                  'View Congratulations Screen',
                  style: AppTypography.label,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
