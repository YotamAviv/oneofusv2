import 'package:flutter/material.dart';

class AdvancedScreen extends StatelessWidget {
  final VoidCallback onShowBlocks;
  final VoidCallback onShowEquivalents;
  final VoidCallback onReplaceKey;

  const AdvancedScreen({
    super.key,
    required this.onShowBlocks,
    required this.onShowEquivalents,
    required this.onReplaceKey,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADVANCED',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Color(0xFF37474F),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A gateway to functionality that is necessary for completeness but that is rarely used.',
                style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 32),

              _buildSection(
                context,
                title: 'My equivalent keys',
                content: 'Lost or compromised keys can\'t be recovered. But they can be replaced. '
                    'Your replaced keys remain associated with your identity so that those who trusted or followed those keys still follow you.',
                buttonLabel: 'MANAGE IDENTITY HISTORY',
                icon: Icons.history_rounded,
                onTap: onShowEquivalents,
              ),

              const SizedBox(height: 24),

              _buildSection(
                context,
                title: 'My outstanding blocks',
                content: 'In case you\'ve blocked a key, you can see them here and change your mind.',
                buttonLabel: 'VIEW BLOCKED KEYS',
                icon: Icons.block_flipped,
                onTap: onShowBlocks,
              ),

              const SizedBox(height: 24),

              _buildSection(
                context,
                title: 'Replace my key',
                content: 'Create and start using a new key. No one will know it\'s you unless you have folks vouch for you all over again. '
                    'Avoid it if you can.',
                buttonLabel: 'ROTATE IDENTITY KEY',
                icon: Icons.published_with_changes_rounded,
                color: Colors.red.shade700,
                onTap: onReplaceKey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? const Color(0xFF00897B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(buttonLabel),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor.withOpacity(0.1),
            foregroundColor: themeColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: themeColor.withOpacity(0.2)),
            ),
          ),
        ),
      ],
    );
  }
}
