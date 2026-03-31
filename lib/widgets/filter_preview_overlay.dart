import 'package:flutter/material.dart';

import '../models/filter_models.dart';

class FilterPreviewOverlay extends StatelessWidget {
  const FilterPreviewOverlay({
    super.key,
    required this.preset,
    required this.active,
  });

  final FilterPreset preset;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final warmth = (preset.temperature.clamp(0, 100) / 100).toDouble();
    final tint = Color.lerp(Colors.white, Colors.deepOrange, warmth);
    final dimOpacity = (1 - (preset.brightness.clamp(0, 100) / 100))
        .clamp(0.0, 0.65)
        .toDouble();
    final overlayOpacity = ((preset.opacity.clamp(0, 100) / 100))
        .clamp(0.0, 0.85)
        .toDouble();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: active ? 1 : 0,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: tint?.withAlpha((overlayOpacity * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          if (dimOpacity > 0)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((dimOpacity * 255).round()),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }
}

class FilterPhonePreview extends StatelessWidget {
  const FilterPhonePreview({
    super.key,
    required this.preset,
    required this.active,
    this.label,
    this.helper,
  });

  final FilterPreset preset;
  final bool active;
  final String? label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 0.56,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.surface,
                      scheme.surfaceContainerHighest,
                    ],
                  ),
                ),
              ),
              _MockPhoneScreen(label: label, helper: helper),
              FilterPreviewOverlay(
                preset: preset,
                active: active,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockPhoneScreen extends StatelessWidget {
  const _MockPhoneScreen({this.label, this.helper});

  final String? label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '9:41',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              const Icon(Icons.signal_cellular_alt, size: 14),
              const SizedBox(width: 4),
              const Icon(Icons.wifi, size: 14),
              const SizedBox(width: 4),
              const Icon(Icons.battery_full, size: 14),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label ?? 'Night routine',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  helper ?? 'Screen warmth preview.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _MockPreviewTile(
            title: 'Messages',
            subtitle: 'Sleep early tonight?',
            icon: Icons.chat_bubble_outline,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Icon(Icons.call_outlined),
              Icon(Icons.circle_outlined),
              Icon(Icons.camera_alt_outlined),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _MockPreviewTile extends StatelessWidget {
  const _MockPreviewTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
