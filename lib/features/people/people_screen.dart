import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';

class PeopleScreen extends StatelessWidget {
  final List<TrustStatement> statements;

  const PeopleScreen({super.key, required this.statements});

  @override
  Widget build(BuildContext context) {
    debugPrint("[UI] Building PeopleScreen with ${statements.length} statements.");
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF),
      body: SafeArea(
        child: ListView.builder(
          itemCount: statements.length,
          itemBuilder: (context, index) {
            final statement = statements[index];
            return ListTile(
              title: Text(statement.moniker ?? 'No Moniker'),
            );
          },
        ),
      ),
    );
  }
}
