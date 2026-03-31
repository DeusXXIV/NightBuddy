import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/premium_policy.dart';
import '../../services/sleep_audio_service.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../widgets/premium_ui.dart';
import '../home/widgets/sleep_audio_cards.dart';
import '../home/widgets/usual_night_setup_screen.dart';
import '../premium/premium_screen.dart';

class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return appState.when(
      data: (state) => _AudioView(state: state),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _AudioView extends ConsumerWidget {
  const _AudioView({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(sleepAudioControllerProvider);
    final favoriteTrack = sleepTrackOptions.firstWhere(
      (track) => track.id == state.favoriteSleepTrackId,
      orElse: () => sleepTrackOptions.first,
    );
    final remaining = controller.endTime?.difference(DateTime.now());
    final currentTrack = sleepTrackOptions.firstWhere(
      (track) => track.id == controller.activeTrackId,
      orElse: () => sleepTrackOptions.first,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Audio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionIntro(
            title: 'Audio for tonight',
            subtitle:
                'Choose a track, start a timer, or return to your usual audio for the night.',
          ),
          const SizedBox(height: 16),
          _NowPlayingCard(
            isPlaying: controller.isPlaying,
            currentTrackLabel: currentTrack.label,
            remaining: remaining,
            onStop: controller.isPlaying ? () => controller.stop() : null,
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: 'Quick start',
            subtitle:
                'Pick the track and timer you want ready for repeat nights.',
          ),
          const SizedBox(height: 8),
          _UsualAudioCard(
            favoriteTrackLabel: favoriteTrack.label,
            timerMinutes: state.preferredSleepTimerMinutes,
            onOpenSetup: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UsualNightSetupScreen(),
                ),
              );
            },
          ),
          if (!state.isPremium) ...[
            const SizedBox(height: 12),
            PremiumUpsellCard(
              title: 'Unlock more audio',
              subtitle:
                  'Premium adds ${kPremiumSleepTrackNames.join(' and ')} plus future ambient packs.',
              onTap: () => _openPremium(context),
            ),
          ],
          const SizedBox(height: 16),
          const _SectionHeader(
            title: 'Sleep music',
            subtitle:
                'Longer tracks for settling in. $kFreeSleepTrackName is included.',
          ),
          const SizedBox(height: 8),
          SleepMusicCard(
            isPremium: state.isPremium,
            onUpgrade: () => _openPremium(context),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: 'Ambient soundscapes',
            subtitle:
                'Gentle background loops for steady sleep sound.',
          ),
          const SizedBox(height: 8),
          AmbientSoundscapesCard(
            isPremium: state.isPremium,
            onUpgrade: () => _openPremium(context),
          ),
        ],
      ),
    );
  }

  void _openPremium(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: _mutedColor(context)),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
        ),
      ],
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.isPlaying,
    required this.currentTrackLabel,
    required this.remaining,
    required this.onStop,
  });

  final bool isPlaying;
  final String currentTrackLabel;
  final Duration? remaining;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final subtitle = isPlaying
        ? remaining == null
              ? '$currentTrackLabel is playing now.'
              : '$currentTrackLabel • ${_formatDuration(remaining!)} left on timer.'
        : 'No sleep audio is running right now.';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Now playing',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            if (isPlaying) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onStop,
                  child: const Text('Stop audio'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return 'under 1m';
    final minutes = duration.inMinutes;
    if (minutes < 1) return 'under 1m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class _UsualAudioCard extends StatelessWidget {
  const _UsualAudioCard({
    required this.favoriteTrackLabel,
    required this.timerMinutes,
    required this.onOpenSetup,
  });

  final String favoriteTrackLabel;
  final int timerMinutes;
  final VoidCallback onOpenSetup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usual audio defaults',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(label: 'Favorite', value: favoriteTrackLabel),
                _InfoPill(label: 'Timer', value: _formatTimerMinutes(timerMinutes)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onOpenSetup,
                child: const Text('Open usual night setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimerMinutes(int minutes) {
    if (minutes <= 0) return 'Off';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
