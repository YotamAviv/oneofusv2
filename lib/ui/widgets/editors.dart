import 'package:flutter/material.dart';

import '../../ui/app_typography.dart';
import '../qr_scanner.dart';

abstract class FieldEditor extends StatefulWidget {
  final ValueChanged<void>? onChanged;

  const FieldEditor({super.key, this.onChanged});
}

abstract class FieldEditorState<T extends FieldEditor, K> extends State<T> {
  // Returns the current value of the field
  K get value;

  // Returns true if the field content is valid
  bool get isValid;

  void notifyChanged() {
    widget.onChanged?.call(null);
  }
}

// --- TextFieldEditor ---
class TextFieldEditor extends FieldEditor {
  final String label;
  final String? initialValue;
  final String? hint;
  final bool enabled;
  final bool required;

  const TextFieldEditor({
    super.key,
    required this.label,
    this.initialValue,
    this.hint,
    this.enabled = true,
    this.required = false,
    super.onChanged,
  });

  @override
  // ignore: library_private_types_in_public_api
  FieldEditorState<TextFieldEditor, String> createState() => _TextFieldEditorState();
}

class _TextFieldEditorState extends FieldEditorState<TextFieldEditor, String> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() => notifyChanged());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  String get value => _controller.text.trim();

  @override
  bool get isValid => !widget.required || _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: AppTypography.labelSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: widget.enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// --- TextBoxEditor (Multiline) ---
class TextBoxEditor extends FieldEditor {
  final String label;
  final String? initialValue;
  final String? hint;
  final int maxLines;

  const TextBoxEditor({
    super.key,
    required this.label,
    this.initialValue,
    this.hint,
    maxLines = 3,
    super.onChanged,
  }) : maxLines = maxLines;

  @override
  // ignore: library_private_types_in_public_api
  FieldEditorState<TextBoxEditor, String> createState() => _TextBoxEditorState();
}

class _TextBoxEditorState extends FieldEditorState<TextBoxEditor, String> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() => notifyChanged());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  String get value => _controller.text.trim();

  @override
  bool get isValid => true; // Always valid

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: AppTypography.labelSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

// --- DelegateRevokeAtEditor ---
class DelegateRevokeAtEditor extends FieldEditor {
  final String? initialRevokeAt;

  const DelegateRevokeAtEditor({super.key, required this.initialRevokeAt, super.onChanged});

  @override
  // ignore: library_private_types_in_public_api
  FieldEditorState<DelegateRevokeAtEditor, String?> createState() => _DelegateRevokeAtEditorState();
}

class _DelegateRevokeAtEditorState extends FieldEditorState<DelegateRevokeAtEditor, String?> {
  String? currentRevokeAt;

  @override
  void initState() {
    super.initState();
    currentRevokeAt = widget.initialRevokeAt;
  }

  @override
  String? get value => currentRevokeAt;

  @override
  bool get isValid {
    const kSinceAlways = '<since always>';
    final isActive = currentRevokeAt == null;
    final isFullyRevoked = currentRevokeAt == kSinceAlways;
    final isPartiallyRevoked = !isActive && !isFullyRevoked;

    if (isPartiallyRevoked) {
      if (currentRevokeAt == null || !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(currentRevokeAt!)) {
        return false;
      }
    }
    return true;
  }

  void _updateAndNotify() {
    notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    const kSinceAlways = '<since always>';
    final isActive = currentRevokeAt == null;
    final isFullyRevoked = currentRevokeAt == kSinceAlways;
    final isPartiallyRevoked = !isActive && !isFullyRevoked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STATUS', style: AppTypography.labelSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatusChip(
                label: 'ACTIVE',
                isSelected: isActive,
                onSelected: () {
                  setState(() => currentRevokeAt = null);
                  _updateAndNotify();
                },
                selectedColor: const Color(0xFF0288D1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusChip(
                label: 'FULLY REVOKED',
                isSelected: isFullyRevoked,
                onSelected: () {
                  setState(() => currentRevokeAt = kSinceAlways);
                  _updateAndNotify();
                },
                selectedColor: Colors.blueGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: _StatusChip(
            label: 'REVOKED AT STATEMENT TOKEN',
            isSelected: isPartiallyRevoked,
            onSelected: () {
              if (!isPartiallyRevoked) {
                setState(() {
                  currentRevokeAt =
                      (widget.initialRevokeAt != null && widget.initialRevokeAt != kSinceAlways)
                      ? widget.initialRevokeAt
                      : "";
                });
                _updateAndNotify();
              }
            },
            selectedColor: Colors.orange,
          ),
        ),
        if (isPartiallyRevoked) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REVOKE AT STATEMENT TOKEN',
                      style: AppTypography.labelSmall.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        (currentRevokeAt == null || currentRevokeAt!.isEmpty)
                            ? "(Scan Statement Token QR Code)"
                            : currentRevokeAt!,
                        style: AppTypography.mono.copyWith(
                          fontSize: 10,
                          color: (currentRevokeAt == null || currentRevokeAt!.isEmpty)
                              ? Colors.grey
                              : Colors.black87,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                onPressed: () async {
                  final scanned = await QrScanner.scan(
                    context,
                    title: 'Scan revokeAt Statement Token',
                    instruction:
                        'Scan the token of the last valid statement signed by the key you want to revoke.',
                    validator: (code) async => RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(code),
                  );
                  if (scanned != null) {
                    setState(() => currentRevokeAt = scanned);
                    _updateAndNotify();
                  }
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final Color selectedColor;

  const _StatusChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.1) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: isSelected ? selectedColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

class ReplaceRevokeAt extends StatelessWidget {
  const ReplaceRevokeAt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERMANENT REPLACEMENT',
                  style: AppTypography.labelSmall.copyWith(color: Colors.orange.shade900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Old key revoked <since always>',
                  style: AppTypography.label.copyWith(color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
