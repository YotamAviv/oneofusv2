import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

class DelegatesScreen extends StatefulWidget {
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  final VoidCallback? onRefresh;

  const DelegatesScreen({
    super.key,
    required this.statementsByIssuer,
    required this.myKeyToken,
    this.onRefresh,
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
    
    debugPrint("[UI] Building DelegatesScreen with ${delegates.length} unique delegates.");
    
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SERVICES',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Color(0xFF37474F),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: delegates.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: delegates.length,
                  itemBuilder: (context, index) {
                    return _buildServiceCard(delegates[index]);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_moon_outlined, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          Text(
            'No Authorized Delegates',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Services you authorize will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blueGrey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(TrustStatement statement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: const Color(0xFF006064),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              statement.domain ?? 'Unknown Service',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF37474F),
                              ),
                            ),
                          ),
                          const Tooltip(
                            message: 'Authorized: This service can act on your behalf',
                            child: Icon(
                              Icons.verified_user_outlined,
                              size: 20,
                              color: Color(0xFF006064),
                            ),
                          ),
                        ],
                      ),
                      if (statement.domain != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          statement.domain!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (statement.comment != null && statement.comment!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          statement.comment!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ActionButton(
                            icon: Icons.settings_outlined,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.no_accounts_outlined,
                            label: 'REVOKE',
                            color: Colors.red.shade400,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? const Color(0xFF006064);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: activeColor.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: activeColor),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
