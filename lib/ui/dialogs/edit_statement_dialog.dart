import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

import '../widgets/editors.dart';
import '../widgets/verb_conflict_warning.dart';
import '../qr_scanner.dart';

class EditStatementDialog extends StatefulWidget {
  final TrustStatement statement;
  final TrustStatement? existingStatement;
  final TrustVerb? initialVerb;
  final bool isNewScan;

  final Future<void> Function({
    required TrustVerb verb,
    String? moniker,
    String? comment,
    String? domain,
    String? revokeAt,
  }) onSubmit;

  const EditStatementDialog({
    super.key,
    required this.statement,
    this.existingStatement,
    this.initialVerb,
    this.isNewScan = false,
    required this.onSubmit,
  });

  @override
  State<EditStatementDialog> createState() => _EditStatementDialogState();
}

class _EditStatementDialogState extends State<EditStatementDialog> {
  TrustVerb? _selectedVerb;
  bool _isSaving = false;
  bool _warningConfirmed = false;
  bool _hasConflict = false;
  
  // Field Editor Keys
  late GlobalKey<FieldEditorState> _monikerKey;
  late GlobalKey<FieldEditorState> _commentKey;
  late GlobalKey<FieldEditorState> _domainKey;
  late GlobalKey<FieldEditorState> _revokeAtKey;

  // Validation State
  bool _monikerValid = false;
  bool _delegateValid = true; 
  bool _domainValid = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedVerb = widget.initialVerb ?? widget.statement.verb;
    
    // Initialize Keys
    _monikerKey = GlobalKey<FieldEditorState>();
    _commentKey = GlobalKey<FieldEditorState>();
    _domainKey = GlobalKey<FieldEditorState>();
    _revokeAtKey = GlobalKey<FieldEditorState>();

    // Initial validation state based on existing data
    _monikerValid = widget.statement.moniker?.isNotEmpty ?? false;
    _domainValid = widget.statement.domain?.isNotEmpty ?? false;
    
    // Determine initial "has changes" state:
    // 1. If no existing statement, we are creating new -> Changed
    // 2. If verb mismatch, we are changing disposition -> Changed
    // 3. Otherwise (same verb, existing statement), we start with NO changes (pre-filled)
    if (widget.existingStatement == null) {
      _hasChanges = true;
    } else {
      _hasChanges = widget.existingStatement!.verb != _selectedVerb;
    }

    if (widget.isNewScan && widget.existingStatement != null) {
      if (widget.existingStatement!.verb != _selectedVerb) {
        _hasConflict = true;
      }
    }
  }

  @override
  void dispose() {
    // Keys don't need disposal, controllers are owned by children
    super.dispose();
  }

  String get _title {
    if (widget.isNewScan) return 'New Statement';
    switch (_selectedVerb) {
      case TrustVerb.trust: return 'Edit Vouch';
      case TrustVerb.block: return 'Edit Block';
      case TrustVerb.replace: return 'Key Replacement';
      case TrustVerb.delegate: return 'Delegate Access';
      default: return 'Edit Statement';
    }
  }
  
  bool get _isFormValid {
    switch (_selectedVerb) {
      case TrustVerb.trust:
        return _monikerValid;
      case TrustVerb.block:
        return true; 
      case TrustVerb.delegate:
        return _domainValid && _delegateValid;
      case TrustVerb.replace:
        return true; // Moniker is inherited/fixed
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canSubmit = !_isSaving && _isFormValid && _hasChanges;
    if (_hasConflict && !_warningConfirmed) {
      canSubmit = false;
    }
    return AlertDialog(
      title: Text(_title),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hasConflict) ...[
              VerbConflictWarning(
                existingStatement: widget.existingStatement!,
                targetVerb: _selectedVerb!,
                onConfirmed: (v) => setState(() => _warningConfirmed = v),
              ),
              const SizedBox(height: 24),
            ],

            // Re-introduced layout logic for "plopping in" FieldEditors
            ..._buildFields(),

            if (_isSaving) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
      actions: _isSaving ? null : [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL', style: TextStyle(color: Colors.grey.shade600)),
        ),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: _verbColor.withOpacity(canSubmit ? 1.0 : 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_submitLabel),
        ),
      ],
    );
  }


  Color get _verbColor {
    switch (_selectedVerb) {
      case TrustVerb.trust: return const Color(0xFF00897B);
      case TrustVerb.block: return Colors.red.shade700;
      case TrustVerb.delegate: return Colors.blue.shade700;
      case TrustVerb.replace: return Colors.orange.shade800;
      default: return Colors.black;
    }
  }

  String get _submitLabel {
    if (_selectedVerb == TrustVerb.block) return 'BLOCK KEY';
    if (_selectedVerb == TrustVerb.replace) return 'REPLACE KEY';
    return 'SAVE';
  }

  void _checkForChanges() {
    // If no existing statement (creation) or verb changed, we consider it "changed" compared to DB.
    if (widget.existingStatement == null || widget.existingStatement!.verb != _selectedVerb) {
      if (!_hasChanges) setState(() => _hasChanges = true);
      return;
    }

    // Otherwise, we compare current form values against the initial/existing statement values.
    
    String? currentMoniker;
    if (_monikerKey.currentState != null) {
      currentMoniker = (_monikerKey.currentState as dynamic).value;
    }

    String? currentComment;
    if (_commentKey.currentState != null) {
      currentComment = (_commentKey.currentState as dynamic).value;
    }
    
    String? currentDomain;
    if (_domainKey.currentState != null) {
      currentDomain = (_domainKey.currentState as dynamic).value;
    }
    
    String? currentRevokeAt;
    if (_revokeAtKey.currentState != null) {
      currentRevokeAt = (_revokeAtKey.currentState as dynamic).value;
    }

    // Normalize nulls vs empty strings for comparison
    final initialMoniker = widget.statement.moniker ?? '';
    final initialComment = widget.statement.comment ?? '';
    final initialDomain = widget.statement.domain ?? '';
    final initialRevokeAt = widget.statement.revokeAt; // can be null

    final isChanged = (currentMoniker != null && currentMoniker != initialMoniker) ||
                      (currentComment != null && currentComment != initialComment) ||
                      (currentDomain != null && currentDomain != initialDomain) ||
                      (currentRevokeAt != initialRevokeAt);

    if (_hasChanges != isChanged) {
      setState(() => _hasChanges = isChanged);
    }
  }

  List<Widget> _buildFields() {
    switch (_selectedVerb) {
      case TrustVerb.trust:
        return [
          TextFieldEditor(
            key: _monikerKey,
            label: 'MONIKER (Required)',
            initialValue: widget.statement.moniker,
            hint: 'Name you know them by',
            required: true,
            onValidityChanged: (valid) {
              if (_monikerValid != valid) setState(() => _monikerValid = valid);
            },
            onChanged: (_) => _checkForChanges(),
          ),
          const SizedBox(height: 16),
          TextBoxEditor(
            key: _commentKey,
            label: 'COMMENT (Optional)',
            initialValue: widget.statement.comment,
            hint: 'E.g. "Colleague from work", "Met at conference"',
            onChanged: (_) => _checkForChanges(),
          ),
        ];

      case TrustVerb.block:
        return [
          TextBoxEditor(
            key: _commentKey,
            label: 'REASON (Recommended)',
            initialValue: widget.statement.comment,
            hint: 'Why are you blocking this key?',
            onChanged: (_) => _checkForChanges(),
          ),
        ];

      case TrustVerb.delegate:
        return [
          TextFieldEditor(
            key: _domainKey,
            label: 'DOMAIN',
            initialValue: widget.statement.domain,
            hint: 'e.g. nerdster.org',
            enabled: widget.isNewScan, // Typically domain is set on creation
            required: true,
            onValidityChanged: (valid) {
              if (_domainValid != valid) setState(() => _domainValid = valid);
            },
            onChanged: (_) => _checkForChanges(),
          ),
          const SizedBox(height: 16),
          DelegateRevokeAtEditor(
            key: _revokeAtKey,
            initialRevokeAt: widget.statement.revokeAt,
            onScan: (context) async {
               return await QrScanner.scan(
                 context,
                 title: 'Scan Revocation Token',
                 validator: (code) async => RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(code),
               );
            },
            onValidityChanged: (valid) {
              if (_delegateValid != valid) setState(() => _delegateValid = valid);
            },
            onChanged: (_) => _checkForChanges(),
          ),
        ];

      case TrustVerb.replace:
        return [
          const ReplaceRevokeAt(),
          const SizedBox(height: 16),
          TextBoxEditor(
            key: _commentKey,
            label: 'COMMENT',
            initialValue: widget.statement.comment,
            hint: 'Reason for replacement',
            onChanged: (_) => _checkForChanges(),
          ),
        ];

      default:
        return [];
    }
  }

  Future<void> _submit() async {
    if (_selectedVerb == null) return;
    
    // Safety check, though UI should prevent this
    if (!_isFormValid) return;

    setState(() => _isSaving = true);
    
    try {
      // Gather data from keys
      String? moniker;
      if (_monikerKey.currentState != null) {
        moniker = (_monikerKey.currentState as dynamic).value;
      }

      String? comment;
      if (_commentKey.currentState != null) {
        comment = (_commentKey.currentState as dynamic).value;
      }
      
      String? domain;
      if (_domainKey.currentState != null) {
        domain = (_domainKey.currentState as dynamic).value;
      }
      
      String? revokeAt;
      if (_revokeAtKey.currentState != null) {
        revokeAt = (_revokeAtKey.currentState as dynamic).value;
      } else if (_selectedVerb == TrustVerb.replace) {
        revokeAt = '<since always>';
      } else {
         revokeAt = widget.statement.revokeAt; // Fallback? should be in key
      }

      await widget.onSubmit(
        verb: _selectedVerb!,
        moniker: moniker,
        comment: comment,
        domain: domain,
        revokeAt: revokeAt,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
