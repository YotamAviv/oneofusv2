import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import '../app_typography.dart';
import '../widgets/json_display.dart';

class LgtmDialog extends StatefulWidget {
  final TrustStatement statement;
  final Interpreter? interpreter;

  const LgtmDialog({
    super.key, 
    required this.statement, 
    this.interpreter, 
  });

  @override
  State<LgtmDialog> createState() => _LgtmDialogState();
}

class _LgtmDialogState extends State<LgtmDialog> {

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FYI: The exact data that will be cryptographically signed and published.',
              style: AppTypography.caption.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200)
              ),
              padding: const EdgeInsets.all(8),
              child: JsonDisplay(
                widget.statement.jsonish.json,
                instanceInterpreter: widget.interpreter,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('EDIT'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('LOOKS GOOD'),
        ),
      ],
    );
  }
}
