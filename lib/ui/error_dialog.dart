import 'package:flutter/material.dart';

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
              Text('Error: $error', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (stackTrace != null) ...[
                const SizedBox(height: 16),
                const Text('STACK TRACE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Divider(),
                Text(stackTrace.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
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
