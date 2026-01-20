import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/util.dart';

import 'json_display.dart';
import 'key_widget.dart';
import '../interpreter.dart';
import '../../core/labeler.dart';

class CardAction {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final Color? color;

  const CardAction({
    required this.icon,
    this.label,
    required this.onTap,
    this.color,
  });
}

class StatementCard extends StatelessWidget {
  final TrustStatement statement;
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;

  const StatementCard({
    super.key,
    required this.statement,
    required this.statementsByIssuer,
    required this.myKeyToken,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final subjectToken = statement.subjectToken;
    final verb = statement.verb;

    // 1. Determine Color
    Color themeColor;
    switch (verb) {
      case TrustVerb.delegate:
        themeColor = Colors.blue.shade700;
        break;
      case TrustVerb.trust:
        themeColor = const Color(0xFF00897B); // Teal/Green for Identity
        break;
      case TrustVerb.block:
        themeColor = Colors.red.shade700;
        break;
      case TrustVerb.replace:
        themeColor = const Color(0xFF00897B); // Green (Identity)
        break;
      default:
        themeColor = Colors.grey;
    }

    // 2. Determine "Verified" Badge (Only for Trust)
    Widget? trailingIcon;
    if (verb == TrustVerb.trust) {
      final vouchesBack = statementsByIssuer[subjectToken]?.any((s) =>
              s.subjectToken == myKeyToken && s.verb == TrustVerb.trust) ??
          false;

      trailingIcon = Tooltip(
        message: vouchesBack
            ? 'Verified: They trust you back'
            : 'They have not trusted you yet',
        child: Icon(
          vouchesBack ? Icons.check_circle : Icons.check_circle_outline_rounded,
          size: 20,
          color: vouchesBack ? themeColor : Colors.grey.shade300,
        ),
      );
    }

    // 3. Common Metadata
    final shortId = subjectToken.length >= 6
        ? '#${subjectToken.substring(subjectToken.length - 6)}'
        : '';

    final actions = [
      CardAction(
        icon: Icons.shield_outlined,
        onTap: () => _showJson(context, statement),
        color: Colors.blueGrey,
      ),
      CardAction(
        icon: Icons.edit_outlined,
        onTap: () => onEdit(statement),
      ),
      CardAction(
        icon: Icons.backspace_outlined,
        label: 'CLEAR',
        color: Colors.orange.shade400,
        onTap: () => onClear(statement),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: themeColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              statement.moniker ?? (statement.domain ?? 'Unknown'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF37474F),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trailingIcon != null) ...[
                            trailingIcon,
                            const SizedBox(width: 8),
                          ],
                          KeyWidget(statement: statement, color: themeColor),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Latest statement: ${formatUiDatetime(statement.time)}',
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      if (shortId.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          shortId,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      if (statement.comment != null &&
                          statement.comment!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(Icons.comment_outlined,
                                    size: 12, color: Colors.grey.shade400),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statement.comment!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions.map((action) {
                          final isLast = actions.last == action;
                          return Padding(
                            padding: EdgeInsets.only(right: isLast ? 0 : 8),
                            child: _ActionButtonWidget(
                                action: action, themeColor: themeColor),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJson(BuildContext context, TrustStatement statement) {
    final labeler = Labeler(statementsByIssuer, myKeyToken);
    final interpreter = OneOfUsInterpreter(labeler);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 400, // Fixed height for scrolling
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Statement Data',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: JsonDisplay(
                    statement.jsonish.json,
                    instanceInterpreter: interpreter,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButtonWidget extends StatelessWidget {
  final CardAction action;
  final Color themeColor;

  const _ActionButtonWidget({required this.action, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final activeColor = action.color ?? themeColor;
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: activeColor.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 16, color: activeColor),
            if (action.label != null) ...[
              const SizedBox(width: 4),
              Text(
                action.label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
