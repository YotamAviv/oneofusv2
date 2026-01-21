import 'package:flutter/material.dart';
import '../../ui/app_typography.dart';
import '../demotest/tester.dart';

class DevScreen extends StatelessWidget {
  final VoidCallback onRefresh;

  const DevScreen({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('DIAGNOSTICS (DEV)', style: AppTypography.header),
        const Divider(),
        Text('DEMO DATA', style: AppTypography.labelSmall.copyWith(color: Colors.blue)),
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
          Text('SWITCH KEYS', style: AppTypography.labelSmall.copyWith(color: Colors.green)),
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
