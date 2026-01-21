import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';
import '../ui/app_shell.dart';

/// Read: http://trust_block_disposition_semantics.md
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrustStatement>>(
      valueListenable: AppShell.instance.myStatements,
      builder: (context, myStatements, _) {
       return ValueListenableBuilder<Map<String, List<TrustStatement>>>(
          valueListenable: AppShell.instance.peersStatements,
          builder: (context, peersStatements, _) {
            // Filter for those where the latest verb is 'trust'.
            final myTrustStatements = myStatements
                .where((s) => s.verb == TrustVerb.trust)
                .toList();

            return SafeArea(
              child: StatementListView(
                title: 'PEOPLE',
                description: 'People whose identity you have explicitly vouched for.',
                bottomDescription: '''Trust: Human, capable, acting in good faith.
Block: Bots, spammers, bad actors, careless, confused..''',
                headerPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                emptyTitle: 'No Trusted People',
                emptySubtitle: 'People you trust by scanning their QR code will appear here.',
                emptyIcon: Icons.people_outline,
                itemCount: myTrustStatements.length,
                itemBuilder: (context, index) {
                  final statement = myTrustStatements[index];
                  return StatementCard(statement: statement);
                },
              ),
            );
          }
        );
      }
    );
  }
}
