import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

/// The ClearStatementDialog handles the 'nullification' of a previous stance.
/// In a singular disposition model, pushing a "clear" statement effectively
/// wipes the record of any previous claims made by the issuer about the subject.
class ClearStatementDialog extends StatelessWidget {
  final TrustStatement statement;
  
  /// Callback to push the 'clear' statement
  final VoidCallback onSubmit;

  const ClearStatementDialog({
    super.key,
    required this.statement,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDelegate = statement.domain != null;
    final String subjectName = statement.moniker ?? (isDelegate ? statement.domain! : 'this identity');
    
    return AlertDialog(
      title: Text(isDelegate ? 'Clear Delegation' : 'Clear Disposition'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to clear your ${statement.verb.label} statement for $subjectName?',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'This effectively wipes the slate clean, as if you had never stated anything about them at all.',
            style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () {
            onSubmit();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('CLEAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ],
    );
  }
}
