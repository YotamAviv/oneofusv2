import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart';
import '../core/keys.dart';
import '../demotest/tester.dart';

class DevScreen extends StatelessWidget {
  final VoidCallback onRefresh;

  const DevScreen({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final keys = Keys();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('DIAGNOSTICS (DEV)', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        const Divider(),
        const Text('DEMO DATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 12),
        ...Tester.tests.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () async {
              try {
                await entry.value();
                onRefresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Test "${entry.key}" completed and identity imported.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error running ${entry.key}: $e')),
                  );
                }
              }
            },
            child: Text('RUN ${entry.key.toUpperCase()}'),
          ),
        )).toList(),
        if (Tester.name2key.isNotEmpty) ...[
          const Divider(),
          const Text('SWITCH KEYS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 12),
          ...Tester.name2key.keys.map((name) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await Tester.useKey(name);
                  onRefresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Switched to key: $name')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error switching to $name: $e')),
                    );
                  }
                }
              },
              child: Text('USE KEY: ${name.toUpperCase()}'),
            ),
          )).toList(),
        ],
      ],
    );
  }
}
