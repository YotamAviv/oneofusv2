import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/keys.dart';
import '../../ui/error_dialog.dart';
import '../../ui/qr_scanner.dart';

class WelcomeScreen extends StatelessWidget {
  final FirebaseFirestore firestore;

  const WelcomeScreen({super.key, required this.firestore});

  // It's been a struggle to get the top junk aligned...
  static const double heightKludge = 20;

  @override
  Widget build(BuildContext context) {
    final keys = Keys();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF),
      body: Stack(
        children: [
          // Header (matching card page)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, heightKludge, 24, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/oneofus_1024.png',
                      height: 32,
                      errorBuilder: (context, _, __) => const Icon(Icons.shield_rounded, size: 32, color: Color(0xFF00897B)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'ONE-OF-US.NET',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                        color: Color(0xFF37474F),
                        fontFamily: 'serif',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () async {
                      await keys.newIdentity();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: const Color(0xFF37474F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: const Text('CREATE NEW IDENTITY KEY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => _showImportDialog(context, keys),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Color(0xFF37474F), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('IMPORT IDENTITY KEY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F), letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Claim/Replace identity coming soon.')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Color(0xFF37474F), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CLAIM (REPLACE) IDENTITY KEY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F), letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, Keys keys) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IMPORT IDENTITY'),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PASTE KEYS JSON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final scanned = await QrScanner.scan(
                      context, 
                      title: 'Scan Identity QR',
                      validator: (s) async => s.contains('identity'),
                    );
                    if (scanned != null) {
                      try {
                        await keys.importKeys(scanned);
                      } catch (e, stackTrace) {
                        if (context.mounted) {
                          ErrorDialog.show(context, 'Import Error', e, stackTrace);
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('SCAN', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: '{"identity": ...}',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF37474F)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await keys.importKeys(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e, stackTrace) {
                if (context.mounted) {
                  ErrorDialog.show(context, 'Import Error', e, stackTrace);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('IMPORT'),
          ),
        ],
      ),
    );
  }
}
