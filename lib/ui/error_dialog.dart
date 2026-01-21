import 'package:flutter/material.dart';
import 'app_typography.dart';

class ErrorDialog {
  static void show(BuildContext context, String title, Object error, [StackTrace? stackTrace]) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title.toUpperCase()),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error: $error', style: AppTypography.labelSmall),
              if (stackTrace != null) ...[
                const SizedBox(height: 16),
                Text('STACK TRACE:', style: AppTypography.labelSmall),
                const Divider(),
                Text(stackTrace.toString(), style: AppTypography.mono),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OKAY'),
          ),
        ],
      ),
    );
  }
}
