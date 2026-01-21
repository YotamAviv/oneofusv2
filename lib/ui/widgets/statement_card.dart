import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/trust_statement.dart';

import 'json_display.dart';
import 'key_widget.dart';
import '../interpreter.dart';
import '../../core/labeler.dart';
import '../../core/keys.dart';
import '../app_shell.dart';

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

  const StatementCard({
    super.key,
    required this.statement,
  });

  @override
  Widget build(BuildContext context) {
    final subjectToken = statement.subjectToken;
    final verb = statement.verb;
    final myKeyToken = Keys().identityToken!;
    
    // Access global state
    final peersStatements = AppShell.instance.peersStatements.value;

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
      final TrustStatement? peerStatement = peersStatements[subjectToken]?.where((s) =>
              s.subjectToken == myKeyToken && s.verb == TrustVerb.trust).firstOrNull;
      final bool vouchesBack = peerStatement != null;
      final name = statement.moniker!;

      trailingIcon = Tooltip(
        message: vouchesBack
            ? '$name has vouched for you as ${peerStatement.moniker}'
            : '$name has yet to vouch for your identity, humanity, and integrity',
        child: InkWell(
          onTap: peerStatement != null ? () => _showJson(context, peerStatement.jsonish.json) : null,
          borderRadius: BorderRadius.circular(20),
          child: Icon(
            vouchesBack ? Icons.check_circle : Icons.check_circle_outline_rounded,
            size: 20,
            color: vouchesBack ? themeColor : Colors.grey.shade300,
          ),
        ),
      );
    }

    // 3. Common Metadata
    final bool showShortId = false; // DO NOT REMVE MY CODE (I AM THE HUMAN)
    final String shortId = '#${subjectToken.substring(subjectToken.length - 6)}';

    final actions = [
      CardAction(
        icon: Icons.edit_outlined,
        onTap: () => AppShell.instance.editStatement(statement),
      ),
      CardAction(
        icon: Icons.backspace_outlined,
        label: 'CLEAR',
        color: Colors.orange.shade400,
        onTap: () => AppShell.instance.clearStatement(statement),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
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
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showJson(context, statement.subject),
                                  borderRadius: BorderRadius.circular(4),
                                  child: KeyWidget(statement: statement, color: themeColor),
                                ),
                                if (trailingIcon != null) ...[
                                  const SizedBox(width: 8),
                                  trailingIcon,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showJson(context, statement.jsonish.json),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.shield_outlined,
                                size: 20,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showShortId) ...[
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

  void _showJson(BuildContext context, Map<String, dynamic> json) {
    // Construct a context map for the Labeler.
    final Map<String, List<TrustStatement>> combined = {};
    
    if (AppShell.instance.peersStatements.value.isNotEmpty) {
      combined.addAll(AppShell.instance.peersStatements.value);
    }

    // Add my statements so the Labeler can resolve names I've assigned
    final myToken = Keys().identityToken;
    if (myToken != null && AppShell.instance.myStatements.value.isNotEmpty) {
      combined[myToken] = AppShell.instance.myStatements.value;
    }
    
    final labeler = Labeler(combined, myToken!);
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
                Expanded(
                  child: JsonDisplay(
                    json,
                    instanceInterpreter: interpreter,
                    fit: StackFit.expand,
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
