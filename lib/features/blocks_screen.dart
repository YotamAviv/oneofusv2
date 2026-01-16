import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';

class BlocksScreen extends StatelessWidget {
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  final ScrollController? scrollController;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;

  const BlocksScreen({
    super.key,
    required this.statementsByIssuer,
    required this.myKeyToken,
    this.scrollController,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = (statementsByIssuer[myKeyToken] ?? [])
        .where((s) => s.verb == TrustVerb.block)
        .toList();

    return StatementListView(
      title: 'MY BLOCKS',
      headerPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      emptyTitle: 'No outstanding blocks',
      emptySubtitle: '',
      emptyIcon: Icons.block_flipped,
      itemCount: blocks.length,
      scrollController: scrollController,
      itemBuilder: (context, index) {
        final s = blocks[index];
        return _buildBlockCard(s);
      },
    );
  }

  Widget _buildBlockCard(TrustStatement s) {
    final shortId = s.subjectToken.length >= 6 
        ? '#${s.subjectToken.substring(s.subjectToken.length - 6)}' 
        : '';

    return StatementCard(
      config: StatementCardConfig(
        themeColor: Colors.red.shade700,
        statusIcon: Icons.block_flipped,
        statusTooltip: 'Blocked: You have explicitly denied trust',
        title: s.moniker ?? 'Unknown Identity',
        subtitle: shortId,
        comment: s.comment,
        timestamp: s.time,
        actions: [
          CardAction(
            icon: Icons.settings_outlined,
            onTap: () => onEdit(s),
          ),
          CardAction(
            icon: Icons.backspace_outlined,
            label: 'CLEAR',
            color: Colors.orange.shade400,
            onTap: () => onClear(s),
          ),
        ],
      ),
    );
  }
}
