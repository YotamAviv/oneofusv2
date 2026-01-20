import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';

class HistoryScreen extends StatelessWidget {
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  final ScrollController? scrollController;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;

  const HistoryScreen({
    super.key,
    required this.statementsByIssuer,
    required this.myKeyToken,
    this.scrollController,
    required this.onEdit,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final equivalents = (statementsByIssuer[myKeyToken] ?? [])
        .where((s) => s.verb == TrustVerb.replace)
        .toList();

    return StatementListView(
      title: 'IDENTITY HISTORY',
      headerPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      emptyTitle: 'No previous identity keys',
      emptySubtitle: '',
      emptyIcon: Icons.history_outlined,
      itemCount: equivalents.length,
      scrollController: scrollController,
      itemBuilder: (context, index) {
        final s = equivalents[index];
        return _buildHistoryCard(s);
      },
    );
  }

  Widget _buildHistoryCard(TrustStatement s) {
    return StatementCard(
      statement: s,
      statementsByIssuer: statementsByIssuer,
      myKeyToken: myKeyToken,
      onEdit: onEdit,
      onClear: onClear,
    );
  }
}
