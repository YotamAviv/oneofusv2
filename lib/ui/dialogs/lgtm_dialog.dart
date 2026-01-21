import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
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
  late ValueNotifier<bool> _interpret;

  @override
  void initState() {
    super.initState();
    _interpret = ValueNotifier<bool>(true);
  }

  @override
  void dispose() {
    _interpret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review Statement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Please review the exact data that will be cryptographically signed and published.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
               const Text("Translate tokens", style: TextStyle(fontWeight: FontWeight.bold)),
               const Spacer(),
               Switch(
                 value: _interpret.value,
                 onChanged: (v) => setState(() => _interpret.value = v),
               ),
              ],
            ),
            const Divider(),
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
                interpret: _interpret,
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
