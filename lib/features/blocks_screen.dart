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
  final VoidCallback onScan;

  const BlocksScreen({
    super.key,
    required this.statementsByIssuer,
    required this.myKeyToken,
    this.scrollController,
    required this.onEdit,
    required this.onClear,
    required this.onScan,
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
      onAdd: onScan,
      addLabel: 'BLOCK KEY',
      itemBuilder: (context, index) {
        final s = blocks[index];
        return _buildBlockCard(s);
      },
    );
  }

  Widget _buildBlockCard(TrustStatement s) {
    return StatementCard(
      statement: s,
      statementsByIssuer: statementsByIssuer,
      myKeyToken: myKeyToken,
      onEdit: onEdit,
      onClear: onClear,
    );
  }
}
