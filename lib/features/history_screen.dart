import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';
import '../ui/app_shell.dart';

class HistoryScreen extends StatelessWidget {
  final ScrollController? scrollController;

  const HistoryScreen({
    super.key,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrustStatement>>(
      valueListenable: AppShell.instance.myStatements,
      builder: (context, myStatements, _) {
        final equivalents = myStatements
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
            return StatementCard(statement: s);
          },
        );
      },
    );
  }
}
