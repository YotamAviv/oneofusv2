import 'package:flutter/material.dart';

class StatementListView extends StatelessWidget {
  final String title;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? headerPadding;

  const StatementListView({
    super.key,
    required this.title,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.itemCount,
    required this.itemBuilder,
    this.scrollController,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.headerPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: headerPadding ?? const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
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
          child: itemCount == 0
              ? _buildEmptyState()
              : ListView.builder(
                  controller: scrollController,
                  padding: padding,
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(emptyIcon, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          Text(
            emptyTitle,
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
              emptySubtitle,
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
}
