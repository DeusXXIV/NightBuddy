import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/sleep_audio_service.dart';
import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';
import '../../../widgets/premium_ui.dart';

class SleepMusicCard extends ConsumerStatefulWidget {
  const SleepMusicCard({
    super.key,
    required this.isPremium,
    required this.onUpgrade,
  });

  final bool isPremium;
  final VoidCallback onUpgrade;

  @override
  ConsumerState<SleepMusicCard> createState() => _SleepMusicCardState();
}

class _SleepMusicCardState extends ConsumerState<SleepMusicCard> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider).valueOrNull ?? AppState.initial();
    final audio = ref.watch(sleepAudioControllerProvider);
    final favoriteId = state.favoriteSleepTrackId;
    final favorite = sleepTrackOptions.firstWhere(
      (option) => option.id == favoriteId,
      orElse: () => sleepTrackOptions.first,
    );
    final preferredTimerMinutes = state.preferredSleepTimerMinutes;
    final active = sleepTrackOptions.firstWhere(
      (option) => option.id == audio.activeTrackId,
      orElse: () => sleepTrackOptions.first,
    );
    final isPlaying = audio.isPlaying;
    final remaining = audio.endTime?.difference(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note_outlined),
                const SizedBox(width: 8),
                Text(
                  'Sleep music',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPlaying ? 'Playing ${active.label}' : 'Pick a track to unwind.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.star_outline, size: 16, color: _mutedColor(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Favorite: ${favorite.label}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: _mutedColor(context)),
                  ),
                ),
                TextButton(
                  onPressed: () => _handlePlay(context, favorite.id),
                  child: const Text('Play favorite'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Usual timer: ${_formatTimerMinutes(preferredTimerMinutes)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            ),
            if (remaining != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Timer: ${_formatDuration(remaining)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: sleepTrackOptions.map((option) {
                final selected = option.id == audio.activeTrackId;
                final locked = option.isPremium && !widget.isPremium;
                final isFavorite = option.id == favoriteId;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(option.label),
                      if (isFavorite) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 16),
                      ],
                      if (locked) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_outline, size: 16),
                      ],
                    ],
                  ),
                  selected: selected,
                  onSelected: (_) => _handlePlay(context, option.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sleepTrackOptions.map((option) {
                final isFavorite = option.id == favoriteId;
                final locked = option.isPremium && !widget.isPremium;
                return ActionChip(
                  avatar: Icon(
                    isFavorite ? Icons.star : Icons.star_outline,
                    size: 16,
                  ),
                  label: Text(
                    isFavorite
                        ? '${option.label} favorited'
                        : 'Favorite ${option.label}',
                  ),
                  onPressed: locked
                      ? () {
                          showPremiumLockedSnackBar(
                            context,
                            featureName: option.label,
                          );
                          widget.onUpgrade();
                        }
                      : () {
                          ref
                              .read(appStateProvider.notifier)
                              .setFavoriteSleepTrack(
                                isFavorite ? null : option.id,
                              );
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ...[15, 30, 60].map(
                  (minutes) => Padding(
                    padding: EdgeInsets.only(right: minutes == 60 ? 0 : 8),
                    child: OutlinedButton(
                      onPressed: isPlaying
                          ? () => audio.startTimer(Duration(minutes: minutes))
                          : null,
                      style: minutes == preferredTimerMinutes
                          ? OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${minutes}m'),
                          if (minutes == preferredTimerMinutes) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star, size: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: isPlaying ? audio.stop : null,
                  child: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0m';
    final minutes = duration.inMinutes;
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String _formatTimerMinutes(int minutes) {
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    }
    return '${minutes}m';
  }

  Future<void> _handlePlay(BuildContext context, String trackId) async {
    final result = await ref.read(sleepAudioControllerProvider).playTrack(trackId);
    if (!context.mounted) return;
    switch (result) {
      case SleepAudioResult.playing:
        return;
      case SleepAudioResult.premiumLocked:
        final lockedOption = sleepTrackOptions.firstWhere(
          (option) => option.id == trackId,
          orElse: () => const SleepTrackOption(id: 'track', label: 'This track'),
        );
        showPremiumLockedSnackBar(
          context,
          featureName: lockedOption.label,
        );
        widget.onUpgrade();
        return;
      case SleepAudioResult.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Track unavailable')),
        );
        return;
    }
  }
}

class AmbientSoundscapesCard extends StatelessWidget {
  const AmbientSoundscapesCard({
    super.key,
    required this.isPremium,
    required this.onUpgrade,
  });

  final bool isPremium;
  final VoidCallback onUpgrade;

  static const _options = [
    SleepTrackOption(id: 'rain', label: 'Rain'),
    SleepTrackOption(id: 'fan', label: 'Fan', isPremium: true),
    SleepTrackOption(id: 'ocean', label: 'Ocean', isPremium: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headphones_outlined),
                const SizedBox(width: 8),
                Text(
                  'Ambient soundscapes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rain will be included. Fan and Ocean will be part of Premium when available.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _options.map((option) {
                final locked = option.isPremium && !isPremium;
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
                  selected: false,
                  onSelected: (_) {
                    if (locked) {
                      showPremiumLockedSnackBar(
                        context,
                        featureName: option.label,
                      );
                      onUpgrade();
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Soundscape unavailable')),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
