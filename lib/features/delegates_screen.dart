import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import '../ui/widgets/statement_card.dart';
import '../ui/widgets/statement_list_view.dart';

class DelegatesScreen extends StatefulWidget {
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  final VoidCallback? onRefresh;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;

  const DelegatesScreen({
    super.key,
    required this.statementsByIssuer,
    required this.myKeyToken,
    this.onRefresh,
    required this.onEdit,
    required this.onClear,
  });

  @override
  State<DelegatesScreen> createState() => DelegatesScreenState();
}

class DelegatesScreenState extends State<DelegatesScreen> {
  @override
  Widget build(BuildContext context) {
    final myStatements = widget.statementsByIssuer[widget.myKeyToken] ?? [];
    
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
        itemBuilder: (context, index) {
          return _buildServiceCard(delegates[index]);
        },
      ),
    );
  }

  Widget _buildServiceCard(TrustStatement statement) {
    final isRevoked = statement.revokeAt != null;
    
    final shortId = statement.subjectToken.length >= 6 
        ? '#${statement.subjectToken.substring(statement.subjectToken.length - 6)}' 
        : '';

    final config = StatementCardConfig(
      themeColor: const Color(0xFF006064),
      statusIcon: isRevoked ? Icons.key_off_outlined : Icons.vpn_key_outlined,
      statusTooltip: isRevoked 
          ? 'Revoked: This service is no longer authorized'
          : 'Authorized: This service can act on your behalf',
      title: statement.domain ?? 'Unknown Service',
      subtitle: shortId,
      timestamp: statement.time,
      actions: [
        CardAction(
          icon: Icons.settings_outlined,
          onTap: () => widget.onEdit(statement),
        ),
        CardAction(
          icon: Icons.clear_outlined,
          label: 'CLEAR',
          color: Colors.orange.shade400,
          onTap: () => widget.onClear(statement),
        ),
      ],
    );

    return StatementCard(config: config);
  }
}
