import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

class PeopleScreen extends StatefulWidget {
  final Map<String, List<TrustStatement>> statementsByIssuer;
  final String myKeyToken;
  final VoidCallback? onRefresh;
  final Function(TrustStatement) onEdit;
  final Function(TrustStatement) onClear;
  final Function(TrustStatement) onBlock;

  const PeopleScreen({
    super.key,
    required this.statementsByIssuer,
    required this.myKeyToken,
    this.onRefresh,
    required this.onEdit,
    required this.onClear,
    required this.onBlock,
  });

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  @override
  Widget build(BuildContext context) {
    final List<TrustStatement> myStatements = widget.statementsByIssuer[widget.myKeyToken] ?? [];

    // 2. Filter for those where the latest verb is 'trust'.
    // People we blocked or cleared should not appear in the "Trusted" list.
    final myTrustStatements = myStatements
        .where((s) => s.verb == TrustVerb.trust)
        .toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PEOPLE',
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
            child: myTrustStatements.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: myTrustStatements.length,
                  itemBuilder: (context, index) {
                    final statement = myTrustStatements[index];
                    return _buildPersonCard(statement);
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
          Icon(Icons.people_outline, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          Text(
            'No Trusted People',
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
              'People you trust by scanning their QR code will appear here.',
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

  Widget _buildPersonCard(TrustStatement statement) {
    final vouchesBack = widget.statementsByIssuer[statement.subjectToken]?.any((s) =>
        s.subjectToken == widget.myKeyToken &&
        s.verb == TrustVerb.trust) ?? false;

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
                color: const Color(0xFF00897B),
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
                              statement.moniker!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF37474F),
                              ),
                            ),
                          ),
                          Tooltip(
                            message: vouchesBack ? 'Verified: They trust you back' : 'They have not trusted you yet',
                            child: Icon(
                              vouchesBack ? Icons.check_circle : Icons.check_circle_outline_rounded,
                              size: 20,
                              color: vouchesBack ? const Color(0xFF00897B) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (statement.comment != null && statement.comment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
                            icon: Icons.edit_outlined,
                            onTap: () => widget.onEdit(statement),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.backspace_outlined,
                            label: 'CLEAR',
                            onTap: () => widget.onClear(statement),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.block_flipped,
                            label: 'BLOCK',
                            color: Colors.red.shade400,
                            onTap: () => widget.onBlock(statement),
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
    final activeColor = color ?? const Color(0xFF00897B);
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
