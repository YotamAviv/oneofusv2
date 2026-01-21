import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Our Own Decentralized, Heterogeneous Identity Network',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF37474F),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '''If you believe that knowing who's who is important, who should be the authority? Us, right?

— I am not a robot
You reading this now are either one of us or one of them.''',
            style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF455A64)),
          ),
          const SizedBox(height: 40),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '''We're building our own network by cryptographically signing each other's public keys, creating a web of trust. Share the app and vouch for us humans.''',
                style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF455A64)),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text:
                          "That network (our network) can be leveraged anywhere. Try signing in to the Nerdster (",
                      style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF455A64)),
                    ),
                    TextSpan(
                      text: "https://nerdster.org",
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF00897B),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(Uri.parse("https://nerdster.org"));
                        },
                    ),
                    const TextSpan(
                      text: ") and see.",
                      style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF455A64)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: "Read more at ",
                      style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF455A64)),
                    ),
                    TextSpan(
                      text: "https://one-of-us.net",
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF00897B),
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(Uri.parse("https://one-of-us.net"));
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onShowWelcome != null) ...[
            const SizedBox(height: 40),
            Center(
              child: TextButton(
                onPressed: onShowWelcome,
                child: const Text(
                  'View Congratulations Screen',
                  style: TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
