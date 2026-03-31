import 'package:flutter/material.dart';

class PremiumUpsellCard extends StatelessWidget {
  const PremiumUpsellCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.actionLabel = 'View premium',
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: TextButton(onPressed: onTap, child: Text(actionLabel)),
      ),
    );
  }
}

class PremiumInlineNotice extends StatelessWidget {
  const PremiumInlineNotice({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.actionLabel = 'View premium',
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onTap, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}

void showPremiumLockedSnackBar(
  BuildContext context, {
  required String featureName,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$featureName is part of Premium.'),
      duration: const Duration(seconds: 2),
    ),
  );
}
