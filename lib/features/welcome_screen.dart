import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/app_typography.dart';
import '../core/keys.dart';
import '../ui/error_dialog.dart';
import 'replace/replace_flow.dart';

class WelcomeScreen extends StatelessWidget {
  final FirebaseFirestore? firestore;
  final VoidCallback? onIdentityCreated;

  const WelcomeScreen({super.key, required this.firestore, this.onIdentityCreated});

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
                padding: const EdgeInsets.fromLTRB(8, heightKludge, 24, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF37474F)),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      )
                    else
                      const SizedBox(width: 16),

                    Image.asset(
                      'assets/oneofus_1024.png',
                      height: 32,
                      errorBuilder: (context, _, __) =>
                          const Icon(Icons.shield_rounded, size: 32, color: Color(0xFF00897B)),
                    ),
                    const SizedBox(width: 12),
                    const Text('ONE-OF-US.NET', style: AppTypography.header),
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Welcome',
                    textAlign: TextAlign.center,
                    style: AppTypography.hero,
                  ),
                  const Text(
                    'You have no keys on this device',
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () async {
                      if (firestore == null) return;

                      bool proceed = true;
                      if (await keys.load()) {
                        if (!context.mounted) return;
                        proceed =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Already Signed In'),
                                content: const Text(
                                  'You already have an identity. Creating a new one will destroy your current keys and data. Are you sure?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('CANCEL'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(
                                      'OVERWRITE',
                                      style: AppTypography.body.copyWith(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                      }

                      if (!proceed) return;

                      await keys.newIdentity();
                      onIdentityCreated?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      backgroundColor: const Color(0xFF37474F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: Text(
                      'CREATE NEW IDENTITY KEY',
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => _showImportDialog(context, keys),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      side: const BorderSide(color: Color(0xFF37474F), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'IMPORT KEYS FROM A BACKED UP EXPORT',
                      textAlign: TextAlign.center,
                      style: AppTypography.label,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () async {
                      if (firestore != null) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ReplaceFlow(firestore: firestore!, claimMode: true),
                          ),
                        );
                        if (result == true) {
                          onIdentityCreated?.call();
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      side: const BorderSide(color: Color(0xFF37474F), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'CLAIM (REPLACE) IDENTITY KEY',
                      textAlign: TextAlign.center,
                      style: AppTypography.label,
                    ),
                  ),
                ],
              ),
            ),
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
        title: const Text('RESTORE FROM BACKUP'),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your backed up keys JSON below to restore your identity on this installation.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PASTE KEYS JSON', style: AppTypography.labelSmall),
                TextButton.icon(
                  onPressed: () async {
                    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                    if (clipboardData != null && clipboardData.text != null) {
                      controller.text = clipboardData.text!;
                    }
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('PASTE', style: AppTypography.labelSmall),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF00897B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '{"identity": ...}',
                hintStyle: AppTypography.caption,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              style: AppTypography.mono,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: AppTypography.labelSmall),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await keys.importKeys(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  onIdentityCreated?.call();
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
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }
}
