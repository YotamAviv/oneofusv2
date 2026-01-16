import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';

/// Read: http://trust_block_disposition_semantics.md
class PeopleScreen extends StatefulWidget {
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  final VoidCallback? onRefresh;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;
  final Function(TrustStatement) onBlock;

  const PeopleScreen({
    super.key,
    required this.statementsByIssuer,
    required this.myKeyToken,
    this.onRefresh,
    required this.onEdit,
    required this.onClear,
    required this.onBlock,
  });

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  @override
  Widget build(BuildContext context) {
    final List<TrustStatement> myStatements = widget.statementsByIssuer[widget.myKeyToken] ?? [];

    // Filter for those where the latest verb is 'trust'.
    final myTrustStatements = myStatements
        .where((s) => s.verb == TrustVerb.trust)
        .toList();

    return SafeArea(
      child: StatementListView(
        title: 'PEOPLE',
        headerPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        emptyTitle: 'No Trusted People',
        emptySubtitle: 'People you trust by scanning their QR code will appear here.',
        emptyIcon: Icons.people_outline,
        itemCount: myTrustStatements.length,
        itemBuilder: (context, index) {
          final statement = myTrustStatements[index];
          return _buildPersonCard(statement);
        },
      ),
    );
  }

  Widget _buildPersonCard(TrustStatement statement) {
    final vouchesBack = widget.statementsByIssuer[statement.subjectToken]?.any((s) =>
        s.subjectToken == widget.myKeyToken &&
        s.verb == TrustVerb.trust) ?? false;

    final shortId = statement.subjectToken.length >= 6 
        ? '#${statement.subjectToken.substring(statement.subjectToken.length - 6)}' 
        : '';

    final config = StatementCardConfig(
      themeColor: const Color(0xFF00897B),
      statusIcon: Icons.verified_outlined,
      statusTooltip: 'Trusted: A human capable of acting in good faith',
      title: statement.moniker ?? 'Unknown',
      subtitle: shortId,
      timestamp: statement.time,
      trailingIcon: Tooltip(
        message: vouchesBack ? 'Verified: They trust you back' : 'They have not trusted you yet',
        child: Icon(
          vouchesBack ? Icons.check_circle : Icons.check_circle_outline_rounded,
          size: 20,
          color: vouchesBack ? const Color(0xFF00897B) : Colors.grey.shade300,
        ),
      ),
      actions: [
        CardAction(
          icon: Icons.edit_outlined,
          onTap: () => widget.onEdit(statement),
        ),
        CardAction(
          icon: Icons.block_flipped,
          label: 'BLOCK',
          color: Colors.red.shade400,
          onTap: () => widget.onBlock(statement),
        ),
        CardAction(
          icon: Icons.backspace_outlined,
          label: 'CLEAR',
          color: Colors.orange.shade400,
          onTap: () => widget.onClear(statement),
        ),
      ],
    );

    return StatementCard(config: config);
  }
}
