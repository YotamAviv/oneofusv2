import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

/// The EditStatementDialog handles the refinement or transformation of an existing
/// statement. In our singular disposition model, we don't 'edit' data in-place;
/// we restate our stance towards a subject.


/// New direction:
/// - Don't allow blocking from PEOPLE screen.
///   This makes things simpler as, sematically, we vouch for "people" but block "keys".
/// - This class could be used for editing statements with verbs [trust, block, replace].
/// 
/// - Scanning a key is different from strict editing:
/// We should allow both [TRUST, BLOCK] and not be predispositioned to either.
/// We want to show:
///     'Trust: "human, capable of acting in good faith"',
///     'Block: "Bots, spammers, bad actors, careless, confused.."',
/// 
/// We don't want to show that text the same exact way for editing an existing trust or block. 
/// We probably want to 
/// just show half of it, or possibly show half of it greyed out.
/// 
/// If this special case is too complex, we don't have to force it.
/// Also, if using this dialog for the verb [replace] is too complex, we don't have to force it.
/// 
/// This is a good time to use better language and have clearer text for confused users.
/// 
/// So:
/// This upcoming "new direction" change will change
/// - this class
/// - the PEOPLE screen
/// 

///
/// Business Rules:
/// - Verbs [delegate, replace, block] are 'locked': once you've taken this stance,
///   you can only update the metadata (like comments or specific flags) but you
///   cannot change the verb using this interface (use Clear followed by a new Scan instead).
/// - The [trust] verb is 'fluid': it is the only verb that allows upgrading directly
///   to a [block].
/// - [revokeAt] logic is specific to authority stances (delegates/replacements).
class EditStatementDialog extends StatefulWidget {
  final TrustStatement statement;
  final TrustVerb? initialVerb; // Optional override for the starting state

  /// Callback to push the final statement to the storage layer
  final Future<void> Function({
    required TrustVerb verb,
    String? moniker,
    String? comment,
    String? revokeAt,
  })
  onSubmit;

  const EditStatementDialog({
    super.key,
    required this.statement,
    this.initialVerb,
    required this.onSubmit,
  });

  @override
  State<EditStatementDialog> createState() => _EditStatementDialogState();

  String get title {
    TrustVerb verb = statement.verb;
    switch (statement.verb) {
      case TrustVerb.trust:
        return "Edit Vouch";
      case TrustVerb.block:
        return "Edit Block";
      case TrustVerb.replace:
        return "Edit Key Replacement";
      default:
        throw StateError('Unexpected verb for clear dialog: $verb');
    }
  }
}

class _EditStatementDialogState extends State<EditStatementDialog> {
  late TextEditingController _monikerController;
  late TextEditingController _commentController;
  late TrustVerb _selectedVerb;
  final String kSinceAlways = '<since always>';
  bool _isSaving = false;
  bool _lastCanSubmit = false;

  @override
  void initState() {
    super.initState();
    _monikerController = TextEditingController(text: widget.statement.moniker);
    _commentController = TextEditingController(text: widget.statement.comment);
    _selectedVerb = widget.initialVerb ?? widget.statement.verb;

    _lastCanSubmit = _canSubmit();

    _monikerController.addListener(_onFieldChanged);
    _commentController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final curCanSubmit = _canSubmit();
    if (curCanSubmit != _lastCanSubmit) {
      setState(() {
        _lastCanSubmit = curCanSubmit;
      });
    }
  }

  @override
  void dispose() {
    _monikerController.removeListener(_onFieldChanged);
    _commentController.removeListener(_onFieldChanged);
    _monikerController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  bool get _isTrust => _selectedVerb == TrustVerb.trust;
  bool get _isBlock => _selectedVerb == TrustVerb.block;
  bool get _isReplace => _selectedVerb == TrustVerb.replace;

  bool get _verbIsFluid => widget.statement.verb == TrustVerb.trust;

  String get _submitButtonLabel {
    if (_isBlock) return 'BLOCK';
    return 'UPDATE';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trust: "human, capable of acting in good faith"',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const Text(
              'Block: "Bots, spammers, bad actors, careless, confused.."',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),

            // Verb Transformation (Only allowed for 'trust')
            if (_verbIsFluid) ...[
              Text(
                'STANCE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('TRUST')),
                      selected: _isTrust,
                      onSelected:
                          (widget.initialVerb == null || widget.initialVerb == TrustVerb.trust)
                          ? (val) => setState(() {
                              if (val) {
                                _selectedVerb = TrustVerb.trust;
                                _lastCanSubmit = _canSubmit();
                              }
                            })
                          : null,
                      selectedColor: const Color(0xFF00897B).withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _isTrust ? const Color(0xFF00897B) : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('BLOCK')),
                      selected: _isBlock,
                      onSelected:
                          (widget.initialVerb == null || widget.initialVerb == TrustVerb.block)
                          ? (val) => setState(() {
                              if (val) {
                                _selectedVerb = TrustVerb.block;
                                _lastCanSubmit = _canSubmit();
                              }
                            })
                          : null,
                      selectedColor: Colors.red.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _isBlock ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_isTrust || widget.statement.moniker != null) ...[
              Text(
                'NAME ${_isTrust ? "(REQUIRED)" : ""}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _monikerController,
                enabled: _isTrust,
                style: _isTrust
                    ? null
                    : const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
                decoration: InputDecoration(
                  hintText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
            ],

            ...[
              Text(
                'COMMENT ("OPTIONAL")',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _commentController,
                enabled: true,
                style: null,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 12),
            Text(
              'LATEST STATEMENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              widget.statement.time.toIso8601String().substring(0, 16).replaceFirst('T', ' '),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
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
          onPressed: _lastCanSubmit ? _handleSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isBlock
                ? Colors.red
                : (_isReplace ? Colors.green : const Color(0xFF00897B)),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _submitButtonLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
        ),
      ],
    );
  }

  bool _canSubmit() {
    if (_isSaving) return false;
    final curMoniker = _monikerController.text.trim();
    final curComment = _commentController.text.trim();

    // Check if anything actually changed
    final changedVerb = _selectedVerb != widget.statement.verb;
    final changedMoniker = curMoniker != (widget.statement.moniker ?? '');
    final changedComment = curComment != (widget.statement.comment ?? '');

    bool hasChanged = changedVerb || (_isTrust && changedMoniker) || changedComment;

    // Check validation
    bool isMonikerValid = _selectedVerb != TrustVerb.trust || curMoniker.isNotEmpty;

    return hasChanged && isMonikerValid;
  }

  void _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(
        verb: _selectedVerb,
        moniker: _selectedVerb == TrustVerb.trust ? _monikerController.text.trim() : null,
        comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
        revokeAt: _selectedVerb == TrustVerb.replace ? kSinceAlways : null,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
