import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';

/// The ClearStatementDialog handles the 'nullification' of a previous stance.
/// In a singular disposition model, pushing a "clear" statement effectively
/// wipes the record of any previous claims made by the issuer about the subject.
class ClearStatementDialog extends StatefulWidget {
  final TrustStatement statement;

  /// Callback to push the 'clear' statement
  final Future<void> Function() onSubmit;

  const ClearStatementDialog({super.key, required this.statement, required this.onSubmit});

  @override
  State<ClearStatementDialog> createState() => _ClearStatementDialogState();

  String get title {
    TrustVerb verb = statement.verb;
    switch (verb) {
      case TrustVerb.delegate:
        return "Clear Delegation";
      case TrustVerb.trust:
        return "Withdraw Vouch";
      case TrustVerb.block:
        return "Remove Block";
      case TrustVerb.replace:
        return "Clear Key Replacement";
      default:
        throw StateError('Unexpected verb for clear dialog: $verb');
    }
  }

  String get body {
    TrustVerb verb = statement.verb;
    String? domain = statement.domain;
    String? moniker = statement.moniker;
    switch (verb) {
      case TrustVerb.delegate:
        return 'Are you sure you want to remove your delegation for "$domain"?';
      case TrustVerb.trust:
        return 'Are you sure you can no longer vouch that this key represents "$moniker" and that "$moniker" is behaving responsibly?';
      case TrustVerb.block:
        return "Are you sure you want to unblock this key?";
      case TrustVerb.replace:
        return "Is this key not to be associated with your identity?";
      default:
        throw StateError('Unexpected verb for clear dialog: $verb');
    }
  }
}

class _ClearStatementDialogState extends State<ClearStatementDialog> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body, style: const TextStyle(fontSize: 14)),
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
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  try {
                    await widget.onSubmit();
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isSaving = false);
                      if (!e.toString().contains("UserCancelled")) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'CLEAR',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
        ),
      ],
    );
  }
}
