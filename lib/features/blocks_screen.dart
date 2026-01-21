import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';
import '../ui/app_shell.dart';

class BlocksScreen extends StatelessWidget {
  final ScrollController? scrollController;

  const BlocksScreen({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrustStatement>>(
      valueListenable: AppShell.instance.myStatements,
      builder: (context, myStatements, _) {
        final blocks = myStatements.where((s) => s.verb == TrustVerb.block).toList();

        return StatementListView(
          title: 'BLOCKED KEYS',
          description: 'Keys you have explicitly blocked from interacting with you.',
          bottomDescription: '''Trust: Human, capable, acting in good faith.
Block: Bots, spammers, bad actors, careless, confused..''',
          headerPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          emptyTitle: 'No outstanding blocks',
          emptySubtitle: '',
          emptyIcon: Icons.block_flipped,
          itemCount: blocks.length,
          scrollController: scrollController,
          onAdd: () => AppShell.instance.scan(TrustVerb.block),
          addLabel: 'BLOCK KEY',
          itemBuilder: (context, index) {
            final s = blocks[index];
            return StatementCard(statement: s);
          },
        );
      },
    );
  }
}
