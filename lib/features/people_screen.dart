import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';

/// Read: http://trust_block_disposition_semantics.md
class PeopleScreen extends StatefulWidget {
  final List<TrustStatement> myStatements;
  final Map<String, List<TrustStatement>> peersStatements;
  final String myKeyToken;
  final Future<void> Function()? onRefresh;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;

  const PeopleScreen({
    super.key,
    required this.myStatements,
    required this.peersStatements,
    required this.myKeyToken,
    this.onRefresh,
    required this.onEdit,
    required this.onClear,
  });

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  @override
  Widget build(BuildContext context) {
    // Filter for those where the latest verb is 'trust'.
    final myTrustStatements = widget.myStatements
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
    return StatementCard(
      statement: statement,
      peersStatements: widget.peersStatements,
      myKeyToken: widget.myKeyToken,
      onEdit: widget.onEdit,
      onClear: widget.onClear,
    );
  }
}
