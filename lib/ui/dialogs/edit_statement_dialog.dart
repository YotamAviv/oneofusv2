import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

import '../../ui/app_typography.dart';
import '../../core/keys.dart';
import '../widgets/editors.dart';
import '../widgets/verb_conflict_warning.dart';

class EditStatementDialog extends StatefulWidget {
  final TrustStatement proposedStatement;
  final TrustStatement? existingStatement;
  final bool isNewScan;

  final Future<void> Function(TrustStatement statement) onSubmit;

  const EditStatementDialog({
    super.key,
    required this.proposedStatement,
    this.existingStatement,
    this.isNewScan = false,
    required this.onSubmit,
  });

  @override
  State<EditStatementDialog> createState() => _EditStatementDialogState();
}

class _FieldDef {
  final String name;
  final String? Function(TrustStatement)? initialValueGetter;
  final Widget Function({
    required BuildContext context,
    required GlobalKey<FieldEditorState> key,
    String? initialValue,
    required ValueChanged<void> onChanged,
    bool enabled,
  }) builder;
  final bool required;
  final bool immutable;

  const _FieldDef(this.name, this.builder, {this.initialValueGetter, this.required = false, this.immutable = false});
}

class _EditStatementDialogState extends State<EditStatementDialog> {
  TrustVerb? _selectedVerb;
  bool _isSaving = false;
  bool _warningConfirmed = false;
  bool _hasConflict = false;
  
  // Dynamic State
  final Map<String, GlobalKey<FieldEditorState>> _editorKeys = {};
  bool _isFormValid = true; // Cached validity state
  bool _hasChanges = false;

  static final Map<TrustVerb, List<_FieldDef>> _fieldConfigs = {
    TrustVerb.trust: [
      _FieldDef('moniker', 
        initialValueGetter: (s) => s.moniker,
        ({required key, initialValue, required onChanged, enabled = true, required context}) => 
        TextFieldEditor(
          key: key,
          label: 'MONIKER (Required)',
          initialValue: initialValue,
          hint: 'Name you know them by',
          required: true,
          enabled: enabled,
          onChanged: onChanged,
        ), required: true),
      _FieldDef('comment', 
        initialValueGetter: (s) => s.comment,
        ({required key, initialValue, required onChanged, enabled = true, required context}) => 
        TextBoxEditor(
          key: key,
          label: 'COMMENT (Optional)',
          initialValue: initialValue,
          hint: 'E.g. "Colleague from work", "Met at conference"',
          onChanged: onChanged,
        )),
    ],
    TrustVerb.block: [
      _FieldDef('comment', 
        initialValueGetter: (s) => s.comment,
        ({required key, initialValue, required onChanged, enabled = true, required context}) => 
        TextBoxEditor(
          key: key,
          label: 'REASON (Recommended)',
          initialValue: initialValue,
          hint: 'Why are you blocking this key?',
          onChanged: onChanged,
        )),
    ],
    TrustVerb.delegate: [
      _FieldDef('domain', 
        initialValueGetter: (s) => s.domain,
        ({required key, initialValue, required onChanged, enabled = true, required context}) => 
        TextFieldEditor(
          key: key,
          label: 'DOMAIN',
          initialValue: initialValue,
          hint: 'e.g. nerdster.org',
          enabled: enabled,
          required: true,
          onChanged: onChanged,
        ), required: true, immutable: true),
      _FieldDef('revokeAt', 
        initialValueGetter: (s) => s.revokeAt,
        ({required key, initialValue, required onChanged, enabled = true, required context}) => 
        DelegateRevokeAtEditor(
          key: key,
          initialRevokeAt: initialValue,
          onChanged: onChanged,
        )),
    ],
    TrustVerb.replace: [
      _FieldDef('revokeAt', 
        initialValueGetter: (s) => s.revokeAt,
        ({required key, initialValue, required onChanged, enabled = true, required context}) => 
        const ReplaceRevokeAt()),
      _FieldDef('comment', 
        initialValueGetter: (s) => s.comment,
        ({required key, initialValue, required onChanged, enabled = true, required context}) => 
        TextBoxEditor(
          key: key,
          label: 'COMMENT',
          initialValue: initialValue,
          hint: 'Reason for replacement',
          onChanged: onChanged,
        )),
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedVerb = widget.proposedStatement.verb;
    
    // Initialize Keys for current verb
    final fields = _fieldConfigs[_selectedVerb] ?? [];
    for (var field in fields) {
      _editorKeys[field.name] = GlobalKey<FieldEditorState>();
    }
    
    // We defer initial validation check to post frame because keys aren't attached yet
    // But we can initialize boolean checks
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForChanges());

    // Determine initial "has changes" state:
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
    super.dispose();
  }

  String get _title {
    String newOrUpdate = widget.isNewScan ? 'New' : 'Update';
    switch (_selectedVerb) {
      case TrustVerb.trust: return '$newOrUpdate Vouch';
      case TrustVerb.block: return '$newOrUpdate Block';
      case TrustVerb.replace: return '$newOrUpdate Key Replacement';
      case TrustVerb.delegate: return '$newOrUpdate Delegate';
      default: throw StateError('Unexpected verb for title: $_selectedVerb');
    }
  }
  
  // _isFormValid is now a field updated by _checkForChanges

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
          child: Text('CANCEL', style: AppTypography.labelSmall),
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
    if (widget.existingStatement == null || widget.existingStatement!.verb != _selectedVerb) {
      if (!_hasChanges) setState(() => _hasChanges = true);
      return;
    }

    bool hasValChanges = false;

    // Check Validity on every change
    final fields = _fieldConfigs[_selectedVerb] ?? [];
    bool newValidity = true;
    
    for (var field in fields) {
      final key = _editorKeys[field.name];
      // Skip if key not attached (e.g. ReplaceRevokeAt)
      if (key == null || key.currentState == null) continue;
      
      // Pull validity from child
      if (!key.currentState!.isValid) {
        newValidity = false;
        // Don't break here if we want to check all, but for boolean result break is fine.
        // However, if we wanted to show specific errors per field, we'd continue.
      }
    }
    
    // Check for Value Changes
    if (widget.existingStatement == null || widget.existingStatement!.verb != _selectedVerb) {
      // New or Verb change = always changed regardless of field values
      hasValChanges = true;
    } else {
      for (var field in fields) {
        final key = _editorKeys[field.name];
        if (key == null || key.currentState == null) continue;
        
        final currentVal = (key.currentState as dynamic).value as String?;
        final initialVal = field.initialValueGetter != null 
            ? field.initialValueGetter!(widget.proposedStatement) 
            : widget.proposedStatement.json[field.name] as String?;

        if (currentVal != initialVal) {
          hasValChanges = true;
          break; // Optimization
        }
      }
    }

    if (_hasChanges != hasValChanges || _isFormValid != newValidity) {
      setState(() {
        _hasChanges = hasValChanges;
        _isFormValid = newValidity;
      });
    }
  }

  List<Widget> _buildFields() {
    final fields = _fieldConfigs[_selectedVerb] ?? [];
    List<Widget> children = [];
    
    for (var field in fields) {
      final initialVal = field.initialValueGetter != null 
          ? field.initialValueGetter!(widget.proposedStatement) 
          : widget.proposedStatement.json[field.name] as String?;

      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: field.builder(
            context: context,
            key: _editorKeys[field.name]!,
            initialValue: initialVal,
            enabled: field.immutable ? widget.isNewScan : true,
            onChanged: (_) => _checkForChanges(),
          ),
        )
      );
    }
    return children;
  }

  Future<void> _submit() async {
    if (_selectedVerb == null || !_isFormValid) return;

    setState(() => _isSaving = true);
    
    try {
      // Harvest Data
      String? moniker;
      String? comment;
      String? domain;
      String? revokeAt;

      // Helper to safely get value from key
      String? getValue(String name) {
        final key = _editorKeys[name];
        if (key != null && key.currentState != null) {
          return (key.currentState as dynamic).value;
        }
        return null;
      }

      moniker = getValue('moniker');
      comment = getValue('comment');
      domain = getValue('domain');
      revokeAt = getValue('revokeAt');

      // Special handling for Replace which doesn't use a FieldEditor for revokeAt
      if (_selectedVerb == TrustVerb.replace) {
        revokeAt = '<since always>';
      } else if (revokeAt == null) {
         revokeAt = widget.proposedStatement.revokeAt; 
      }

      Json iJson = (await Keys().getIdentityPublicKeyJson())!;
      // Subject is stored under the verb key in the original statement
      final subjectJson = widget.proposedStatement.json[widget.proposedStatement.verb.label];

      final json = TrustStatement.make(
        iJson,
        subjectJson,
        _selectedVerb!,
        moniker: moniker,
        comment: comment,
        domain: domain,
        revokeAt: revokeAt,
      );

      final statement = TrustStatement(Jsonish(json));
      await widget.onSubmit(statement);
      
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        if (!e.toString().contains("UserCancelled")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
