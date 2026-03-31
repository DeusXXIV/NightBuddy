import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/sleep_audio_service.dart';
import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';
import '../../premium/premium_screen.dart';

class UsualNightSetupScreen extends ConsumerWidget {
  const UsualNightSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider).valueOrNull ?? AppState.initial();
    final notifier = ref.read(appStateProvider.notifier);

    Future<void> openPremium() async {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Usual night setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose what your usual night should start with.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick the preset, track, timer, and phone-down window you want to reuse before bed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SetupSection(
            title: 'Bedtime preset',
            subtitle: state.bedtimeModePresetId == null
                ? 'Currently follows your favorite preset.'
                : 'Use a specific preset each night.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Use favorite preset'),
                  selected: state.bedtimeModePresetId == null,
                  onSelected: (_) => notifier.setBedtimeModePresetId(null),
                ),
                ...state.presets.map((preset) {
                  final locked = preset.isPremium && !state.isPremium;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(preset.name),
                        if (locked) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.lock_outline, size: 16),
                        ],
                      ],
                    ),
                    selected: state.bedtimeModePresetId == preset.id,
                    onSelected: (_) async {
                      if (locked) {
                        await openPremium();
                        return;
                      }
                      await notifier.setBedtimeModePresetId(preset.id);
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SetupSection(
            title: 'Sleep music',
            subtitle: 'Choose the track Start usual night should prefer.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sleepTrackOptions.map((option) {
                final locked = option.isPremium && !state.isPremium;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.label),
                      if (locked) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_outline, size: 16),
                      ],
                    ],
                  ),
                  selected: state.favoriteSleepTrackId == option.id,
                  onSelected: (_) async {
                    if (locked) {
                      await openPremium();
                      return;
                    }
                    await notifier.setFavoriteSleepTrack(option.id);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SetupSection(
            title: 'Sleep timer',
            subtitle: 'Applied automatically when your usual track starts.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [15, 30, 60, 90].map((minutes) {
                return ChoiceChip(
                  label: Text(_formatMinutes(minutes)),
                  selected: state.preferredSleepTimerMinutes == minutes,
                  onSelected: (_) =>
                      notifier.setPreferredSleepTimerMinutes(minutes),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _SetupSection(
            title: 'Phone-down window',
            subtitle:
                'Starts a no-phone window when you begin your usual night.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [30, 60, 90, 120].map((minutes) {
                return ChoiceChip(
                  label: Text(_formatMinutes(minutes)),
                  selected: state.screenOffGoalMinutes == minutes,
                  onSelected: (_) => notifier.setScreenOffGoalMinutes(minutes),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    }
    return '${minutes}m';
  }
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
