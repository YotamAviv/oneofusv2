import 'package:flutter/material.dart';
import '../../ui/app_typography.dart';

class NotificationsScreen extends StatelessWidget {
  final List<String> notifications;

  const NotificationsScreen({super.key, required this.notifications});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Text(
                'NOTIFICATIONS',
                style: AppTypography.header.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'serif',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (notifications.isEmpty)
             Text(
              "No new notifications.",
              style: AppTypography.body,
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  return Text(
                    notifications[index],
                    style: AppTypography.body,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
