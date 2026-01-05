import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../services/premium_service.dart';
import '../../state/app_notifier.dart';

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final premiumService = ref.read(premiumServiceProvider);
    final products = ref.watch(premiumProductsProvider);

    return appState.when(
      data: (state) => Scaffold(
        appBar: AppBar(title: const Text('Go Premium')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlock the full experience',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const _Bullet(text: 'Remove ads'),
              const _Bullet(text: 'Unlock extra presets and more custom slots'),
              const _Bullet(text: 'Advanced scheduling (weekend vs weekday)'),
              const _Bullet(text: 'Better sleep with deeper warmth tuning'),
              const SizedBox(height: 16),
              if (state.isPremium)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Premium is active on this device.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.green),
                  ),
                ),
              products.when(
                data: (items) {
                  final product = items.isNotEmpty ? items.first : null;
                  final priceText =
                      product?.price ?? 'Loading price (configure in Play Console)';
                  return Card(
                    child: ListTile(
                      title: const Text('Premium'),
                      subtitle: Text(priceText),
                      trailing: ElevatedButton(
                        onPressed: state.isPremium || product == null
                            ? null
                            : () async {
                                final ok = await premiumService.startPurchase();
                                if (ok) {
                                  await ref
                                      .read(appStateProvider.notifier)
                                      .setPremium(true);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Premium unlocked'),
                                      ),
                                    );
                                  }
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Purchase failed'),
                                    ),
                                  );
                                }
                              },
                        child: Text(state.isPremium
                            ? 'Unlocked'
                            : product == null
                                ? 'Loading...'
                                : 'Upgrade Now'),
                      ),
                    ),
                  );
                },
                loading: () => const Card(
                  child: ListTile(
                    title: Text('Premium'),
                    subtitle: Text('Loading products...'),
                    trailing: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Card(
                  child: ListTile(
                    title: const Text('Premium'),
                    subtitle: Text('Error loading products: $err'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await premiumService.restorePurchases();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restore flow started')),
                    );
                  }
                },
                child: const Text('Restore Purchase'),
              ),
              TextButton(
                onPressed: () async {
                  final uri = 'https://play.google.com/store/account/subscriptions';
                  if (await canLaunchUrlString(uri)) {
                    await launchUrlString(uri, mode: LaunchMode.externalApplication);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to open subscriptions page')),
                    );
                  }
                },
                child: const Text('Manage purchases'),
              ),
              const Spacer(),
              const Text(
                'No price shown here. Configure real products and prices in Play Console.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
