import 'package:flutter/material.dart';
import 'package:oneofus_common/trust_statement.dart';

class PeopleScreen extends StatefulWidget {
  final List<TrustStatement> statements;

  const PeopleScreen({super.key, required this.statements});

  @override
  State<PeopleScreen> createState() => PeopleScreenState();
}

class PeopleScreenState extends State<PeopleScreen> {
  late List<TrustStatement> _statements;

  @override
  void initState() {
    super.initState();
    _statements = widget.statements;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[UI] Building PeopleScreen with ${_statements.length} statements.");
    return Scaffold(
      backgroundColor: const Color(0xFFF2F0EF),
      body: SafeArea(
        child: ListView.builder(
          itemCount: _statements.length,
          itemBuilder: (context, index) {
            final statement = _statements[index];
            return ListTile(
              title: Text(statement.moniker ?? 'No Moniker'),
            );
          },
        ),
      ),
    );
  }
}
