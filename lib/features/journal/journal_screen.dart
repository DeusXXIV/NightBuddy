import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sleep_journal.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../widgets/premium_ui.dart';
import '../home/widgets/sleep_journal_widgets.dart';
import '../premium/premium_screen.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return appState.when(
      data: (state) => _JournalView(state: state),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}

class _JournalView extends StatelessWidget {
  const _JournalView({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.sleepJournalEntries;
    final activeStart = state.sleepJournalActiveStart;
    final latestEntry = entries.isEmpty ? null : entries.first;
    final weeklyEntries = entries.where((entry) {
      final difference = DateTime.now().difference(entry.endedAt);
      return difference.inDays < 7;
    }).length;
    final averageDuration = entries.isEmpty
        ? null
        : entries
                  .map((entry) => entry.duration.inMinutes)
                  .reduce((a, b) => a + b) ~/
              entries.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionIntro(
            title: 'Sleep journal',
            subtitle:
                'See tonight\'s log, recent sleep, and longer patterns in one place.',
          ),
          const SizedBox(height: 16),
          _JournalOverviewCard(
            activeStart: activeStart,
            latestEntry: latestEntry,
            weeklyEntries: weeklyEntries,
            averageDurationMinutes: averageDuration,
          ),
          const SizedBox(height: 16),
          const _SectionHeader(
            title: 'Tonight',
            subtitle:
                'Log tonight, finish a sleep entry, or complete your morning check-in.',
          ),
          const SizedBox(height: 8),
          SleepJournalCard(
            activeStart: activeStart,
            entries: entries,
            sleepGoalMinutes: state.sleepGoalMinutes,
            isPremium: state.isPremium,
            onUpgrade: () => _openPremium(context),
          ),
          const SizedBox(height: 12),
          MorningCheckInCard(state: state),
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'History & trends',
            subtitle: state.isPremium
                ? 'Review weekly patterns and share a summary when you need it.'
                : 'See recent patterns here. Premium unlocks deeper weekly trends and export.',
          ),
          const SizedBox(height: 8),
          WeeklySummaryCard(
            entries: entries,
            sleepGoalMinutes: state.sleepGoalMinutes,
            onShare: () =>
                shareWeeklySummary(context, entries, state.sleepGoalMinutes),
            isPremium: state.isPremium,
            onUpgrade: () => _openPremium(context),
          ),
          if (!state.isPremium) ...[
            const SizedBox(height: 12),
            PremiumUpsellCard(
              title: 'Unlock deeper journal insights',
              subtitle:
                  'Premium adds weekly trends and CSV export for a fuller view of your sleep.',
              onTap: () => _openPremium(context),
            ),
          ],
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

class _JournalOverviewCard extends StatelessWidget {
  const _JournalOverviewCard({
    required this.activeStart,
    required this.latestEntry,
    required this.weeklyEntries,
    required this.averageDurationMinutes,
  });

  final DateTime? activeStart;
  final SleepJournalEntry? latestEntry;
  final int weeklyEntries;
  final int? averageDurationMinutes;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tonightStatus = activeStart == null
        ? (latestEntry == null
              ? 'No sleep logged yet'
              : 'Last sleep ${_formatMinutes(latestEntry!.duration.inMinutes)}')
        : 'Tracking for ${_formatDuration(now.difference(activeStart!))}';
    final qualityLabel = latestEntry == null
        ? 'No recent rating'
        : 'Latest quality ${latestEntry!.quality}/5';
    final averageLabel = averageDurationMinutes == null
        ? 'No average yet'
        : 'Average ${_formatMinutes(averageDurationMinutes!)}';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'At a glance',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(label: 'Tonight', value: tonightStatus),
                _InfoPill(label: 'This week', value: '$weeklyEntries logged'),
                _InfoPill(label: 'Quality', value: qualityLabel),
                _InfoPill(label: 'Average', value: averageLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return 'under 1m';
    return _formatMinutes(minutes);
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
