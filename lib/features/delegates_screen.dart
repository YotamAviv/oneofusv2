import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';
import '../ui/app_shell.dart';

class DelegatesScreen extends StatefulWidget {
  const DelegatesScreen({super.key});

  @override
  State<DelegatesScreen> createState() => DelegatesScreenState();
}

class DelegatesScreenState extends State<DelegatesScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TrustStatement>>(
      valueListenable: AppShell.instance.myStatements,
      builder: (context, myStatements, _) {
        // Filter by delegate verb
        final delegates = myStatements
            .where((s) => s.verb == TrustVerb.delegate)
            .toList();
        
        return SafeArea(
          child: StatementListView(
            title: 'SERVICES',
            description: 'Services (websites, apps) you have authorized to verify your identity.',
            headerPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            emptyTitle: 'No Authorized Delegates',
            emptySubtitle: 'Services you authorize will appear here.',
            emptyIcon: Icons.shield_moon_outlined,
            itemCount: delegates.length,
            onAdd: () => AppShell.instance.scan(TrustVerb.delegate),
            addLabel: 'CLAIM DELEGATE',
            itemBuilder: (context, index) {
              return StatementCard(statement: delegates[index]);
            },
          ),
        );
      },
    );
  }
}
