import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../app_typography.dart';

class VerbConflictWarning extends StatefulWidget {
  final TrustStatement existingStatement;
  final TrustVerb targetVerb;
  final ValueChanged<bool> onConfirmed;

  const VerbConflictWarning({
    super.key,
    required this.existingStatement,
    required this.targetVerb,
    required this.onConfirmed,
  });

  @override
  State<VerbConflictWarning> createState() => _VerbConflictWarningState();
}

class _VerbConflictWarningState extends State<VerbConflictWarning> {
  bool _isConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Conflict Detected',
                  style: AppTypography.itemTitle.copyWith(
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getWarningText(),
            style: AppTypography.body.copyWith(color: Colors.orange.shade900, height: 1.4),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              setState(() {
                _isConfirmed = !_isConfirmed;
                widget.onConfirmed(_isConfirmed);
              });
            },
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _isConfirmed,
                    onChanged: (val) {
                      setState(() {
                        _isConfirmed = val ?? false;
                        widget.onConfirmed(_isConfirmed);
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I understand, proceed anyway.',
                    style: AppTypography.label.copyWith(
                      // fontSize: 13, // AppTypography.label is 12. Close enough.
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWarningText() {
    final oldVerb = widget.existingStatement.verb;
    final newVerb = widget.targetVerb;
    final moniker = widget.existingStatement.moniker;
    final hasMoniker = moniker != null && moniker.isNotEmpty;
    final name = hasMoniker ? '"$moniker"' : 'this key';

    // Trusting...
    if (newVerb == TrustVerb.trust) {
      if (oldVerb == TrustVerb.block) {
        return 'You are attempting to trust a key that you have previously BLOCKED.';
      }
      if (oldVerb == TrustVerb.delegate) {
        return 'You are attempting to trust a key that is currently one of your DELEGATES.';
      }
    }

    // Blocking...
    if (newVerb == TrustVerb.block) {
      if (oldVerb == TrustVerb.trust) {
        return 'You are attempting to block $name, who you have previously VOUCHED for.';
      }
      if (oldVerb == TrustVerb.delegate) {
        return 'You are attempting to block one of your own DELEGATE keys.';
      }
      if (oldVerb == TrustVerb.replace) {
        return 'You are attempting to block one of your own legacy (replaced) IDENTITY keys.';
      }
    }

    // Delegating...
    if (newVerb == TrustVerb.delegate) {
      if (oldVerb == TrustVerb.trust) {
        return 'You are attempting to delegate permissions to $name, who is currently a distinct identity you vouched for.';
      }
      if (oldVerb == TrustVerb.block) {
        return 'You are attempting to delegate permissions to a key you have previously BLOCKED.';
      }
    }

    // Default fallback
    return 'This key already has a status of "${oldVerb.name.toUpperCase()}". You are changing it to "${newVerb.name.toUpperCase()}".';
  }
}
