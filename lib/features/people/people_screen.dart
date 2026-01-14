import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:oneofus_common/jsonish.dart';

class PeopleScreen extends StatefulWidget {
  final List<TrustStatement> statements;
  final String myKeyToken;
  final VoidCallback? onRefresh;

  const PeopleScreen({
    super.key,
    required this.statements,
    required this.myKeyToken,
    this.onRefresh,
  });

  @override
  State<PeopleScreen> createState() => PeopleScreenState();
}

class PeopleScreenState extends State<PeopleScreen> {
  @override
  Widget build(BuildContext context) {
    // 1. Filter for trust statements issued by ME.
    // 2. De-duplicate by subjectToken, keeping the latest time.
    final Map<String, TrustStatement> latestBySubject = {};
    for (var s in widget.statements) {
      if (s.verb == TrustVerb.trust && s.iToken == widget.myKeyToken) {
        final existing = latestBySubject[s.subjectToken];
        if (existing == null || s.time.isAfter(existing.time)) {
          latestBySubject[s.subjectToken] = s;
        }
      }
    }
    final filteredStatements = latestBySubject.values.toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    debugPrint("[UI] Building PeopleScreen with ${filteredStatements.length} unique people (filtered from ${widget.statements.length}).");
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
            child: filteredStatements.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredStatements.length,
                  itemBuilder: (context, index) {
                    final statement = filteredStatements[index];
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
    final vouchesBack = widget.statements.any((s) =>
        s.iToken == statement.subjectToken &&
        s.subjectToken == widget.myKeyToken &&
        s.verb == TrustVerb.trust);

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
                              statement.moniker ?? 'Unknown',
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
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.backspace_outlined,
                            label: 'CLEAR',
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.block_flipped,
                            label: 'BLOCK',
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
