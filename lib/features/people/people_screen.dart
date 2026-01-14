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
    // Only show people I (Me) trust. Statements from them about me are used for status, not for listing.
    final filteredStatements = widget.statements
        .where((s) => s.verb == TrustVerb.trust && s.iToken == widget.myKeyToken)
        .toList();

    debugPrint("[UI] Building PeopleScreen with ${filteredStatements.length} statements (filtered from ${widget.statements.length}).");
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF),
      body: SafeArea(
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
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00897B)),
                    onPressed: widget.onRefresh,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
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
                          Icon(
                            vouchesBack ? Icons.check_circle : Icons.check_circle_outline_rounded,
                            size: 20,
                            color: vouchesBack ? const Color(0xFF00897B) : Colors.grey,
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
