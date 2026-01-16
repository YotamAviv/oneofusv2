import 'package:flutter/material.dart';
import 'package:oneofus_common/util.dart';

class CardAction {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final Color? color;

  const CardAction({
    required this.icon,
    this.label,
    required this.onTap,
    this.color,
  });
}

class StatementCardConfig {
  final Color themeColor;
  final IconData statusIcon;
  final String statusTooltip;
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final Widget? trailingIcon;
  final List<CardAction> actions;

  const StatementCardConfig({
    required this.themeColor,
    required this.statusIcon,
    required this.statusTooltip,
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.trailingIcon,
    required this.actions,
  });
}

class StatementCard extends StatelessWidget {
  final StatementCardConfig config;

  const StatementCard({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
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
                color: config.themeColor,
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
                              config.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF37474F),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (config.trailingIcon != null) ...[
                            config.trailingIcon!,
                            const SizedBox(width: 8),
                          ],
                          Tooltip(
                            message: config.statusTooltip,
                            child: Icon(
                              config.statusIcon,
                              size: 20,
                              color: config.themeColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Latest statement: ${formatUiDatetime(config.timestamp)}',
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      if (config.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          config.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade400,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: config.actions.map((action) {
                          final isLast = config.actions.last == action;
                          return Padding(
                            padding: EdgeInsets.only(right: isLast ? 0 : 8),
                            child: _ActionButtonWidget(action: action, themeColor: config.themeColor),
                          );
                        }).toList(),
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

class _ActionButtonWidget extends StatelessWidget {
  final CardAction action;
  final Color themeColor;

  const _ActionButtonWidget({required this.action, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final activeColor = action.color ?? themeColor;
    return InkWell(
      onTap: action.onTap,
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
            Icon(action.icon, size: 16, color: activeColor),
            if (action.label != null) ...[
              const SizedBox(width: 4),
              Text(
                action.label!,
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
