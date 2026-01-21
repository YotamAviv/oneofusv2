import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';

class DelegatesScreen extends StatefulWidget {
  final List<TrustStatement> myStatements;
  final String myKeyToken;
  final Future<void> Function()? onRefresh;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;
  final VoidCallback onScan;

  const DelegatesScreen({
    super.key,
    required this.myStatements,
    required this.myKeyToken,
    this.onRefresh,
    required this.onEdit,
    required this.onClear,
    required this.onScan,
  });

  @override
  State<DelegatesScreen> createState() => DelegatesScreenState();
}

class DelegatesScreenState extends State<DelegatesScreen> {
  @override
  Widget build(BuildContext context) {
    // Filter by delegate verb
    final List<TrustStatement> myStatements = widget.myStatements;
    
    final delegates = myStatements
        .where((s) => s.verb == TrustVerb.delegate)
        .toList();
    
    return SafeArea(
      child: StatementListView(
        title: 'SERVICES',
        headerPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        emptyTitle: 'No Authorized Delegates',
        emptySubtitle: 'Services you authorize will appear here.',
        emptyIcon: Icons.shield_moon_outlined,
        itemCount: delegates.length,
        onAdd: widget.onScan,
        addLabel: 'CLAIM DELEGATE',
        itemBuilder: (context, index) {
          return _buildServiceCard(delegates[index]);
        },
      ),
    );
  }

  Widget _buildServiceCard(TrustStatement statement) {
    return StatementCard(
      statement: statement,
      // Delegates screen doesn't typically show bi-directional trust
      myKeyToken: widget.myKeyToken,
      onEdit: widget.onEdit,
      onClear: widget.onClear,
    );
  }
}
