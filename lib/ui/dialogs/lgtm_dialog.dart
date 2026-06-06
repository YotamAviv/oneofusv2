import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/ui/json_display.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_typography.dart';

Widget _buildDragHandle() => Center(
  child: Container(
    width: 36, height: 4,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
  ),
);

// ─── Shared link row ─────────────────────────────────────────────────────────

class _LinkRow extends StatefulWidget {
  final Uri uri;
  final ValueNotifier<bool> interpret;
  final Interpreter? interpreter;
  const _LinkRow({required this.uri, required this.interpret, this.interpreter});
  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.interpret,
      builder: (context, interpreted, _) {
        final spec = widget.uri.queryParameters['spec'] ?? '';
        final label = interpreted && widget.interpreter != null
            ? widget.interpreter!.interpret(spec)?.toString() ?? spec
            : spec;
        final displayUri = widget.uri.replace(queryParameters: {'spec': label});
        final linkStyle = const TextStyle(
            fontSize: 11, color: Colors.blue, decoration: TextDecoration.underline);

        return GestureDetector(
          onTap: () => launchUrl(widget.uri, mode: LaunchMode.externalApplication),
          child: Text(displayUri.toString(),
              style: linkStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
        );
      },
    );
  }
}

// ─── Card 1: before publishing ───────────────────────────────────────────────

class LgtmDialog extends StatefulWidget {
  final TrustStatement statement;
  final Interpreter? interpreter;
  final Uri uri;

  const LgtmDialog({
    super.key,
    required this.statement,
    required this.uri,
    this.interpreter,
  });

  @override
  State<LgtmDialog> createState() => _LgtmDialogState();
}

class _LgtmDialogState extends State<LgtmDialog> {
  final ValueNotifier<bool> _interpret = ValueNotifier(true);

  @override
  void dispose() { _interpret.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDragHandle(),
          Text('FYI: To be signed and published.',
              style: AppTypography.caption.copyWith(color: Colors.black87)),
          const SizedBox(height: 4),
          _LinkRow(uri: widget.uri, interpret: _interpret, interpreter: widget.interpreter),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(8),
                child: JsonDisplay(widget.statement.jsonish.json,
                    interpret: _interpret, interpreter: widget.interpreter),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('LOOKS GOOD'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card 2: after publishing ────────────────────────────────────────────────

class LgtmPublishedDialog extends StatefulWidget {
  final TrustStatement statement;
  final Interpreter? interpreter;
  final Uri uri;

  const LgtmPublishedDialog({
    super.key,
    required this.statement,
    required this.uri,
    this.interpreter,
  });

  @override
  State<LgtmPublishedDialog> createState() => _LgtmPublishedDialogState();
}

class _LgtmPublishedDialogState extends State<LgtmPublishedDialog> {
  final ValueNotifier<bool> _interpret = ValueNotifier(true);

  @override
  void dispose() { _interpret.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDragHandle(),
          Text('Published ✓',
              style: AppTypography.caption.copyWith(color: Colors.black87, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _LinkRow(uri: widget.uri, interpret: _interpret, interpreter: widget.interpreter),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(8),
                child: JsonDisplay(widget.statement.jsonish.json,
                    interpret: _interpret,
                    interpreter: widget.interpreter,
                    keyColors: const {'signature': Colors.red}),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OKAY'),
            ),
          ),
        ],
      ),
    );
  }
}
