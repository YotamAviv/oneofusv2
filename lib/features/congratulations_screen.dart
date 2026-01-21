import 'package:flutter/material.dart';

class CongratulationsScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const CongratulationsScreen({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF), // Match App Shell / Welcome
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CONGRATULATIONS!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Color(0xFF00695C),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You possess a public/private cryptographic key pair!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF37474F),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '''The public key is your Identity Key. Your private key is stored securely on this device (it's yours, see Import / Export).
                
Your Identity is displayed on the main screen. Other folks with the app can scan that to vouch for your humanity and identity.

Use the QR icon (bottom center) to:
- scan other folks' keys to vouch for their identities. Doing so will use your private key to sign and publish a statement which will grow your (and our) identity network.
- sign in to a service using a delegate key.''',
                // textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF546E7A),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: const Text(
                  'Okay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
