import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/filter_models.dart';
import '../../../models/sleep_journal.dart';
import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';
import '../../../utils/sleep_metrics.dart';
import '../../../widgets/premium_ui.dart';

const sleepJournalTagOptions = [
  'Stress',
  'Caffeine',
  'Late screen',
  'Workout',
  'Alcohol',
];

class WeeklySummaryData {
  const WeeklySummaryData({
    required this.averageDuration,
    required this.averageQuality,
    required this.streak,
    required this.bedtimeConsistency,
    required this.consistencyScore,
    required this.durationTrend,
    required this.qualityTrend,
    required this.loggedNights,
    required this.goalHitCount,
    required this.recentEntries,
    required this.averageBedtimeMinutes,
    required this.averageWakeMinutes,
  });

  final Duration? averageDuration;
  final double? averageQuality;
  final int streak;
  final double? bedtimeConsistency;
  final int? consistencyScore;
  final Duration? durationTrend;
  final double? qualityTrend;
  final int loggedNights;
  final int goalHitCount;
  final int recentEntries;
  final double? averageBedtimeMinutes;
  final double? averageWakeMinutes;
}

WeeklySummaryData calculateWeeklySummary(
  List<SleepJournalEntry> entries,
  DateTime now,
  int sleepGoalMinutes,
) {
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  final recent = entries.where((entry) => entry.endedAt.isAfter(weekAgo)).toList();
  final previous = entries
      .where(
        (entry) =>
            entry.endedAt.isAfter(twoWeeksAgo) &&
            entry.endedAt.isBefore(weekAgo),
      )
      .toList();
  final recentEntries = recent.length;
  Duration? averageDuration;
  double? averageQuality;
  Duration? previousAverageDuration;
  double? previousAverageQuality;

  if (recent.isNotEmpty) {
    final totalMinutes = recent
        .map((entry) => entry.duration.inMinutes)
        .fold<int>(0, (sum, value) => sum + value);
    averageDuration = Duration(minutes: (totalMinutes / recent.length).round());
    final totalQuality = recent
        .map((entry) => entry.quality)
        .fold<int>(0, (sum, value) => sum + value);
    averageQuality = totalQuality / recent.length;
  }
  if (previous.isNotEmpty) {
    final totalMinutes = previous
        .map((entry) => entry.duration.inMinutes)
        .fold<int>(0, (sum, value) => sum + value);
    previousAverageDuration =
        Duration(minutes: (totalMinutes / previous.length).round());
    final totalQuality = previous
        .map((entry) => entry.quality)
        .fold<int>(0, (sum, value) => sum + value);
    previousAverageQuality = totalQuality / previous.length;
  }

  final bedtimeMinutes =
      recent.map((entry) => _summaryNormalizeLateNightMinutes(entry.startedAt)).toList();
  final wakeMinutes = recent.map((entry) => _summaryMinutesOfDay(entry.endedAt)).toList();
  final averageBedtimeMinutes = _summaryAverageMinutes(bedtimeMinutes);
  final averageWakeMinutes = _summaryAverageMinutes(wakeMinutes);
  final bedtimeConsistency =
      averageBedtimeMinutes == null || bedtimeMinutes.length < 3
          ? null
          : _summaryMeanAbsoluteDeviation(bedtimeMinutes, averageBedtimeMinutes);
  final consistencyScore = bedtimeConsistency == null
      ? null
      : _consistencyScoreFromVariance(bedtimeConsistency);
  final loggedNights = _summaryCountLoggedNights(entries, now, 7);
  final goalHitCount = recent
      .where((entry) => entry.duration.inMinutes >= sleepGoalMinutes)
      .length;
  final streak = _summaryCalculateLogStreak(entries, now);
  final durationTrend = averageDuration != null && previousAverageDuration != null
      ? averageDuration - previousAverageDuration
      : null;
  final qualityTrend = averageQuality != null && previousAverageQuality != null
      ? averageQuality - previousAverageQuality
      : null;

  return WeeklySummaryData(
    averageDuration: averageDuration,
    averageQuality: averageQuality,
    streak: streak,
    bedtimeConsistency: bedtimeConsistency,
    consistencyScore: consistencyScore,
    durationTrend: durationTrend,
    qualityTrend: qualityTrend,
    loggedNights: loggedNights,
    goalHitCount: goalHitCount,
    recentEntries: recentEntries,
    averageBedtimeMinutes: averageBedtimeMinutes,
    averageWakeMinutes: averageWakeMinutes,
  );
}

Future<void> shareWeeklySummary(
  BuildContext context,
  List<SleepJournalEntry> entries,
  int sleepGoalMinutes,
) async {
  if (entries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No sleep entries to share yet')),
    );
    return;
  }
  final summary = calculateWeeklySummary(entries, DateTime.now(), sleepGoalMinutes);
  final goalDuration = Duration(minutes: sleepGoalMinutes);
  final summaryText = StringBuffer()
    ..writeln('NightBuddy weekly summary')
    ..writeln(
      'Average sleep: ${summary.averageDuration == null ? '--' : _formatSummaryDuration(summary.averageDuration!)}',
    )
    ..writeln(
      'Average quality: ${summary.averageQuality == null ? '--' : summary.averageQuality!.toStringAsFixed(1)}/5',
    )
    ..writeln('Streak: ${summary.streak} night(s)')
    ..writeln(
      'Bedtime consistency: ${summary.bedtimeConsistency == null ? '--' : _formatSummaryVariance(summary.bedtimeConsistency!)}',
    );
  if (summary.consistencyScore != null) {
    summaryText.writeln('Consistency score: ${summary.consistencyScore} / 100');
  }
  if (summary.loggedNights > 0) {
    summaryText.writeln('Logged nights: ${summary.loggedNights} / 7');
  }
  if (summary.recentEntries > 0) {
    summaryText.writeln('Goal hits: ${summary.goalHitCount} / ${summary.recentEntries}');
  }
  if (summary.durationTrend != null || summary.qualityTrend != null) {
    final parts = <String>[];
    if (summary.durationTrend != null) {
      final minutes = summary.durationTrend!.inMinutes;
      final direction = minutes >= 0 ? '+' : '-';
      parts.add('$direction${_formatSummaryDuration(Duration(minutes: minutes.abs()))} sleep');
    }
    if (summary.qualityTrend != null) {
      final direction = summary.qualityTrend! >= 0 ? '+' : '-';
      parts.add('$direction${summary.qualityTrend!.abs().toStringAsFixed(1)} quality');
    }
    summaryText.writeln('7-day trend: ${parts.join(', ')}');
  }
  if (summary.averageBedtimeMinutes != null) {
    summaryText.writeln(
      'Avg bedtime: ${_formatSummaryMinutes(summary.averageBedtimeMinutes!.round())}',
    );
  }
  if (summary.averageWakeMinutes != null) {
    summaryText.writeln(
      'Avg wake: ${_formatSummaryMinutes(summary.averageWakeMinutes!.round())}',
    );
  }
  if (summary.averageDuration != null && summary.averageQuality != null) {
    final score = calculateSleepScore(
      averageDuration: summary.averageDuration!,
      averageQuality: summary.averageQuality!,
      goalDuration: goalDuration,
      bedtimeConsistency: summary.bedtimeConsistency,
    );
    summaryText.writeln('Sleep score: $score / 100');
  }

  await Share.share(
    summaryText.toString(),
    subject: 'NightBuddy weekly summary',
  );
}

class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({
    super.key,
    required this.entries,
    required this.sleepGoalMinutes,
    required this.onShare,
    required this.isPremium,
    required this.onUpgrade,
  });

  final List<SleepJournalEntry> entries;
  final int sleepGoalMinutes;
  final VoidCallback onShare;
  final bool isPremium;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = calculateWeeklySummary(entries, now, sleepGoalMinutes);
    final goalDuration = Duration(minutes: sleepGoalMinutes);
    final averageDuration = summary.averageDuration;
    final averageQuality = summary.averageQuality;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_outlined),
                const SizedBox(width: 8),
                Text(
                  'Weekly summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: entries.isEmpty || !isPremium ? null : onShare,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isPremium)
              _LockedInsights(onUpgrade: onUpgrade)
            else if (entries.isEmpty)
              Text(
                'Log a few nights to see your weekly summary.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              )
            else ...[
              Text(
                'Avg sleep: ${averageDuration == null ? '--' : _formatDuration(averageDuration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                averageQuality == null
                    ? 'Avg quality: --'
                    : 'Avg quality: ${averageQuality.toStringAsFixed(1)}/5',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              Text(
                'Streak: ${summary.streak} night${summary.streak == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              Text(
                'Logged ${summary.loggedNights} / 7 nights',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (summary.recentEntries > 0)
                Text(
                  'Goal hits: ${summary.goalHitCount} / ${summary.recentEntries} '
                  '(${_formatRate(summary.goalHitCount, summary.recentEntries)})',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (summary.bedtimeConsistency != null)
                Text(
                  'Bedtime consistency: ${_formatVarianceMinutes(summary.bedtimeConsistency!)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (summary.consistencyScore != null)
                Text(
                  'Consistency score: ${summary.consistencyScore} / 100',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (summary.durationTrend != null || summary.qualityTrend != null)
                Text(
                  _formatTrendLine(summary.durationTrend, summary.qualityTrend),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              const SizedBox(height: 6),
              Text(
                averageDuration == null
                    ? 'Goal: ${_formatDuration(goalDuration)}'
                    : _formatGoalDelta(averageDuration, goalDuration),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (summary.averageBedtimeMinutes != null)
                Text(
                  'Avg bedtime: ${_formatMinutesOfDay(summary.averageBedtimeMinutes!.round())}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (summary.averageWakeMinutes != null)
                Text(
                  'Avg wake: ${_formatMinutesOfDay(summary.averageWakeMinutes!.round())}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (averageDuration != null && averageQuality != null)
                Text(
                  'Sleep score: ${calculateSleepScore(
                    averageDuration: averageDuration,
                    averageQuality: averageQuality,
                    goalDuration: goalDuration,
                    bedtimeConsistency: summary.bedtimeConsistency,
                  )} / 100',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class SleepJournalCard extends ConsumerWidget {
  const SleepJournalCard({
    super.key,
    required this.activeStart,
    required this.entries,
    required this.sleepGoalMinutes,
    required this.isPremium,
    required this.onUpgrade,
  });

  final DateTime? activeStart;
  final List<SleepJournalEntry> entries;
  final int sleepGoalMinutes;
  final bool isPremium;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appStateProvider.notifier);
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(minutes: 1), (tick) => tick),
      builder: (context, _) => _buildCard(context, notifier),
    );
  }

  Widget _buildCard(BuildContext context, AppStateNotifier notifier) {
    final now = DateTime.now();
    final activeDuration = activeStart == null
        ? null
        : now.difference(activeStart!).isNegative
            ? Duration.zero
            : now.difference(activeStart!);
    final lastEntry = entries.isNotEmpty ? entries.first : null;
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final recent = entries.where((entry) => entry.endedAt.isAfter(weekAgo)).toList();
    final previous = entries
        .where(
          (entry) =>
              entry.endedAt.isAfter(twoWeeksAgo) &&
              entry.endedAt.isBefore(weekAgo),
        )
        .toList();

    Duration? averageDuration;
    double? averageQuality;
    Duration? previousAverageDuration;
    double? previousAverageQuality;
    final goalDuration = Duration(minutes: sleepGoalMinutes);
    final bedtimeMinutes =
        recent.map((entry) => _normalizeLateNightMinutes(entry.startedAt)).toList();
    final wakeMinutes =
        recent.map((entry) => _normalizeLateNightMinutes(entry.endedAt)).toList();
    final averageBedtimeMinutes = _averageMinutes(bedtimeMinutes);
    final averageWakeMinutes = _averageMinutes(wakeMinutes);
    final bedtimeConsistency =
        averageBedtimeMinutes == null || bedtimeMinutes.length < 3
            ? null
            : _meanAbsoluteDeviation(bedtimeMinutes, averageBedtimeMinutes);
    final loggedNights = _countLoggedNights(entries, now, 7);
    final logStreak = _calculateLogStreak(entries, now);

    if (recent.isNotEmpty) {
      final totalMinutes = recent
          .map((entry) => entry.duration.inMinutes)
          .fold<int>(0, (sum, value) => sum + value);
      averageDuration = Duration(minutes: (totalMinutes / recent.length).round());
      final totalQuality = recent
          .map((entry) => entry.quality)
          .fold<int>(0, (sum, value) => sum + value);
      averageQuality = totalQuality / recent.length;
    }
    if (previous.isNotEmpty) {
      final totalMinutes = previous
          .map((entry) => entry.duration.inMinutes)
          .fold<int>(0, (sum, value) => sum + value);
      previousAverageDuration =
          Duration(minutes: (totalMinutes / previous.length).round());
      final totalQuality = previous
          .map((entry) => entry.quality)
          .fold<int>(0, (sum, value) => sum + value);
      previousAverageQuality = totalQuality / previous.length;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_outlined),
                const SizedBox(width: 8),
                Text(
                  'Sleep journal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (activeStart != null)
              Text(
                'Sleeping for ${_formatDuration(activeDuration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (lastEntry != null)
              Text(
                'Last sleep: ${_formatDuration(lastEntry.duration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Text(
                'Track your sleep with a simple manual log.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (lastEntry != null && activeStart == null) ...[
              const SizedBox(height: 4),
              Text(
                'Ended at ${_formatDateTime(lastEntry.endedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (lastEntry.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: lastEntry.tags
                        .map((tag) => _TagChip(label: tag))
                        .toList(),
                  ),
                ),
              if (lastEntry.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    lastEntry.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: _mutedColor(context)),
                  ),
                ),
            ],
            if (isPremium && averageDuration != null) ...[
              const SizedBox(height: 8),
              Text(
                '7-day avg: ${_formatDuration(averageDuration)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                averageQuality == null
                    ? 'No quality average yet'
                    : 'Avg quality: ${averageQuality.toStringAsFixed(1)}/5',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
              if (previousAverageDuration != null)
                Text(
                  'Trend: ${_formatDurationTrend(averageDuration, previousAverageDuration)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              if (previousAverageQuality != null && averageQuality != null)
                Text(
                  'Quality trend: ${_formatQualityTrend(averageQuality, previousAverageQuality)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
            ] else if (!isPremium && entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              PremiumInlineNotice(
                title: 'Unlock deeper sleep insights',
                subtitle:
                    'Premium adds weekly trends, sleep score, and CSV export.',
                onTap: onUpgrade,
                actionLabel: 'View premium',
              ),
            ],
            if (loggedNights > 0)
              Text(
                'Logged $loggedNights of last 7 nights',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (logStreak > 0)
              Text(
                'Logging streak: $logStreak night${logStreak == 1 ? '' : 's'}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            const SizedBox(height: 8),
            Text(
              'Goal: ${_formatDuration(goalDuration)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              averageDuration == null
                  ? 'Log sleep to compare with your goal'
                  : _formatGoalDelta(averageDuration, goalDuration),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            if (averageBedtimeMinutes != null)
              Text(
                'Avg bedtime: ${_formatMinutesOfDay(averageBedtimeMinutes.round())}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (averageWakeMinutes != null)
              Text(
                'Avg wake: ${_formatMinutesOfDay(averageWakeMinutes.round())}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (isPremium && averageDuration != null && averageQuality != null)
              Text(
                'Sleep score: ${calculateSleepScore(
                  averageDuration: averageDuration,
                  averageQuality: averageQuality,
                  goalDuration: goalDuration,
                  bedtimeConsistency: bedtimeConsistency,
                )} / 100',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              )
            else if (isPremium)
              Text(
                'Sleep score: log more nights to calculate',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            if (bedtimeConsistency == null && bedtimeMinutes.isNotEmpty)
              Text(
                'Consistency needs 3+ logs',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _mutedColor(context)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: activeStart == null
                      ? () => notifier.startSleepJournal()
                      : null,
                  child: const Text('Start sleep'),
                ),
                OutlinedButton(
                  onPressed: activeStart != null
                      ? () async {
                          final result = await _showSleepJournalEndSheet(context);
                          if (!context.mounted || result == null) return;
                          await notifier.endSleepJournal(
                            quality: result.quality,
                            notes: result.notes,
                            tags: result.tags,
                          );
                        }
                      : null,
                  child: const Text('End sleep'),
                ),
                TextButton(
                  onPressed: entries.isEmpty
                      ? null
                      : () => _showSleepJournalHistory(context, entries),
                  child: const Text('View history'),
                ),
                TextButton(
                  onPressed: lastEntry != null && activeStart == null
                      ? () async {
                          final updated = await _showSleepJournalEditSheet(
                            context,
                            lastEntry,
                          );
                          if (!context.mounted || updated == null) return;
                          await notifier.updateSleepJournalEntry(0, updated);
                        }
                      : null,
                  child: const Text('Edit last'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<SleepJournalResult?> _showSleepJournalEndSheet(
    BuildContext context,
  ) async {
    return Navigator.of(context).push<SleepJournalResult>(
      MaterialPageRoute(
        builder: (_) => const SleepJournalEndScreen(tagOptions: sleepJournalTagOptions),
      ),
    );
  }

  void _showSleepJournalHistory(
    BuildContext context,
    List<SleepJournalEntry> entries,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SleepJournalHistoryScreen(entries: entries),
      ),
    );
  }

  Future<SleepJournalEntry?> _showSleepJournalEditSheet(
    BuildContext context,
    SleepJournalEntry entry,
  ) async {
    return Navigator.of(context).push<SleepJournalEntry>(
      MaterialPageRoute(
        builder: (_) => SleepJournalEditScreen(
          entry: entry,
          tagOptions: sleepJournalTagOptions,
        ),
      ),
    );
  }
}

class MorningCheckInCard extends ConsumerWidget {
  const MorningCheckInCard({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final entries = state.sleepJournalEntries;
    final lastEntry = entries.isNotEmpty ? entries.first : null;
    final loggedToday = lastEntry != null && _isSameDay(lastEntry.endedAt.toLocal(), now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny_outlined),
                const SizedBox(width: 8),
                Text(
                  'Morning check-in',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              loggedToday
                  ? 'You already logged sleep for today.'
                  : 'Quickly log last night without starting a sleep session.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: loggedToday
                    ? null
                    : () async {
                        final result = await _showQuickLogScreen(context, state);
                        if (!context.mounted || result == null) return;
                        await ref
                            .read(appStateProvider.notifier)
                            .addSleepJournalEntry(result);
                      },
                child: const Text('Quick log'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<SleepJournalEntry?> _showQuickLogScreen(
    BuildContext context,
    AppState state,
  ) async {
    final schedule = state.schedule;
    final now = DateTime.now();
    final defaultStart =
        _effectiveStartTime(schedule, now) ?? const TimeOfDay(hour: 23, minute: 0);
    final defaultEnd =
        _effectiveEndTime(schedule, now) ?? const TimeOfDay(hour: 7, minute: 0);

    return Navigator.of(context).push<SleepJournalEntry>(
      MaterialPageRoute(
        builder: (_) => SleepJournalQuickLogScreen(
          defaultStart: defaultStart,
          defaultEnd: defaultEnd,
          tagOptions: sleepJournalTagOptions,
        ),
      ),
    );
  }
}

class SleepJournalResult {
  const SleepJournalResult({
    required this.quality,
    required this.notes,
    required this.tags,
  });

  final int quality;
  final String notes;
  final List<String> tags;
}

class SleepJournalHistoryScreen extends StatelessWidget {
  const SleepJournalHistoryScreen({super.key, required this.entries});

  final List<SleepJournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sleep history')),
      body: entries.isEmpty
          ? const Center(child: Text('No sleep entries yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final subtitleParts = [
                  'Ended at ${_formatEntryDateTime(entry.endedAt)}',
                  'Quality ${entry.quality}/5',
                ];
                if (entry.tags.isNotEmpty) {
                  subtitleParts.add('Tags: ${entry.tags.join(', ')}');
                }
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Sleep ${_formatEntryDuration(entry.duration)}'),
                  subtitle: Text(subtitleParts.join(' - ')),
                  trailing: entry.notes.isNotEmpty
                      ? const Icon(Icons.notes_outlined)
                      : null,
                  onTap: entry.notes.isEmpty
                      ? null
                      : () => _showEntryNotes(context, entry),
                );
              },
            ),
    );
  }

  void _showEntryNotes(BuildContext context, SleepJournalEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sleep notes'),
        content: Text(entry.notes),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class SleepJournalEndScreen extends StatefulWidget {
  const SleepJournalEndScreen({
    super.key,
    required this.tagOptions,
  });

  final List<String> tagOptions;

  @override
  State<SleepJournalEndScreen> createState() => _SleepJournalEndScreenState();
}

class _SleepJournalEndScreenState extends State<SleepJournalEndScreen> {
  double _quality = 3.0;
  String _notes = '';
  final Set<String> _selectedTags = {};

  void _submit() {
    Navigator.of(context).pop(
      SleepJournalResult(
        quality: _quality.round(),
        notes: _notes,
        tags: _selectedTags.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('End sleep'),
        actions: [
          TextButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: padding,
        children: [
          Text('Sleep quality: ${_quality.round()} / 5'),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: _quality,
            label: '${_quality.round()}',
            onChanged: (value) => setState(() => _quality = value),
          ),
          TextField(
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _notes = value,
          ),
          const SizedBox(height: 12),
          Text('Tags', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.tagOptions.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return ChoiceChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: _submit, child: const Text('Save')),
          ),
        ],
      ),
    );
  }
}

class SleepJournalEditScreen extends StatefulWidget {
  const SleepJournalEditScreen({
    super.key,
    required this.entry,
    required this.tagOptions,
  });

  final SleepJournalEntry entry;
  final List<String> tagOptions;

  @override
  State<SleepJournalEditScreen> createState() => _SleepJournalEditScreenState();
}

class _SleepJournalEditScreenState extends State<SleepJournalEditScreen> {
  late double _quality;
  late String _notes;
  late Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _quality = widget.entry.quality.toDouble();
    _notes = widget.entry.notes;
    _selectedTags = widget.entry.tags.toSet();
  }

  void _submit() {
    Navigator.of(context).pop(
      SleepJournalEntry(
        startedAt: widget.entry.startedAt,
        endedAt: widget.entry.endedAt,
        quality: _quality.round(),
        notes: _notes.trim(),
        tags: _selectedTags.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit sleep entry'),
        actions: [
          TextButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: padding,
        children: [
          Text('Sleep quality: ${_quality.round()} / 5'),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: _quality,
            label: '${_quality.round()}',
            onChanged: (value) => setState(() => _quality = value),
          ),
          TextField(
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _notes = value,
          ),
          const SizedBox(height: 12),
          Text('Tags', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.tagOptions.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return ChoiceChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: _submit, child: const Text('Save')),
          ),
        ],
      ),
    );
  }
}

class SleepJournalQuickLogScreen extends StatefulWidget {
  const SleepJournalQuickLogScreen({
    super.key,
    required this.defaultStart,
    required this.defaultEnd,
    required this.tagOptions,
  });

  final TimeOfDay defaultStart;
  final TimeOfDay defaultEnd;
  final List<String> tagOptions;

  @override
  State<SleepJournalQuickLogScreen> createState() =>
      _SleepJournalQuickLogScreenState();
}

class _SleepJournalQuickLogScreenState
    extends State<SleepJournalQuickLogScreen> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  double _quality = 3.0;
  String _notes = '';
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _startTime = widget.defaultStart;
    _endTime = widget.defaultEnd;
  }

  void _submit() {
    final entry = _buildEntry(
      now: DateTime.now(),
      start: _startTime,
      end: _endTime,
      quality: _quality.round(),
      notes: _notes,
      tags: _selectedTags.toList(),
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.only(
      left: 16,
      right: 16,
      top: 16,
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Morning check-in'),
        actions: [
          TextButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: padding,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (picked == null) return;
                    setState(() => _startTime = picked);
                  },
                  child: Text('Bedtime: ${_formatTimeOfDay(_startTime)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (picked == null) return;
                    setState(() => _endTime = picked);
                  },
                  child: Text('Wake: ${_formatTimeOfDay(_endTime)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Sleep quality: ${_quality.round()} / 5'),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: _quality,
            label: '${_quality.round()}',
            onChanged: (value) => setState(() => _quality = value),
          ),
          TextField(
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _notes = value,
          ),
          const SizedBox(height: 12),
          Text('Tags', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.tagOptions.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return ChoiceChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: _submit, child: const Text('Save')),
          ),
        ],
      ),
    );
  }

  SleepJournalEntry _buildEntry({
    required DateTime now,
    required TimeOfDay start,
    required TimeOfDay end,
    required int quality,
    required String notes,
    required List<String> tags,
  }) {
    var endedAt = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    if (endedAt.isAfter(now)) {
      endedAt = endedAt.subtract(const Duration(days: 1));
    }
    var startedAt =
        DateTime(endedAt.year, endedAt.month, endedAt.day, start.hour, start.minute);
    if (startedAt.isAfter(endedAt)) {
      startedAt = startedAt.subtract(const Duration(days: 1));
    }
    return SleepJournalEntry(
      startedAt: startedAt,
      endedAt: endedAt,
      quality: quality.clamp(1, 5),
      notes: notes.trim(),
      tags: tags,
    );
  }
}

class _LockedInsights extends StatelessWidget {
  const _LockedInsights({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return PremiumInlineNotice(
      title: 'Unlock weekly trends',
      subtitle: 'Premium adds weekly trends and CSV export.',
      onTap: onUpgrade,
      actionLabel: 'View premium',
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

String _formatDuration(Duration? duration) {
  if (duration == null) return '--';
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatGoalDelta(Duration average, Duration goal) {
  final diffMinutes = average.inMinutes - goal.inMinutes;
  if (diffMinutes == 0) return 'On goal this week';
  final direction = diffMinutes > 0 ? 'above' : 'below';
  final diff = Duration(minutes: diffMinutes.abs());
  return 'Avg ${_formatDuration(diff)} $direction goal';
}

String _formatVarianceMinutes(double minutes) {
  final rounded = minutes.round();
  if (rounded < 60) return '+/-${rounded}m';
  final hours = rounded ~/ 60;
  final mins = rounded % 60;
  if (mins == 0) return '+/-${hours}h';
  return '+/-${hours}h ${mins}m';
}

String _formatMinutesOfDay(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour:${minute.toString().padLeft(2, '0')} $period';
}

String _formatRate(int hits, int total) {
  if (total == 0) return '--';
  final rate = (hits / total * 100).round();
  return '$rate%';
}

String _formatTrendLine(Duration? durationTrend, double? qualityTrend) {
  final pieces = <String>[];
  if (durationTrend != null) {
    final minutes = durationTrend.inMinutes;
    final direction = minutes >= 0 ? '+' : '-';
    final diff = Duration(minutes: minutes.abs());
    pieces.add('$direction${_formatDuration(diff)} sleep');
  }
  if (qualityTrend != null) {
    final direction = qualityTrend >= 0 ? '+' : '-';
    pieces.add('$direction${qualityTrend.abs().toStringAsFixed(1)} quality');
  }
  if (pieces.isEmpty) return '7-day trend: --';
  return '7-day trend: ${pieces.join(', ')}';
}

String _formatDurationTrend(Duration? current, Duration? previous) {
  if (current == null || previous == null) return '--';
  final diff = current.inMinutes - previous.inMinutes;
  if (diff == 0) return 'flat vs last week';
  final sign = diff > 0 ? '+' : '-';
  final value = diff.abs();
  final hours = value ~/ 60;
  final minutes = value % 60;
  final formatted = hours > 0
      ? (minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m')
      : '${minutes}m';
  return '$sign$formatted vs last week';
}

String _formatQualityTrend(double current, double previous) {
  final diff = current - previous;
  if (diff.abs() < 0.05) return 'flat vs last week';
  final sign = diff > 0 ? '+' : '-';
  return '$sign${diff.abs().toStringAsFixed(1)} vs last week';
}

String _formatDateTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatEntryDateTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatEntryDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

int _normalizeLateNightMinutes(DateTime time) {
  final minutes = time.hour * 60 + time.minute;
  if (minutes < 12 * 60) {
    return minutes + 24 * 60;
  }
  return minutes;
}

double? _averageMinutes(List<int> values) {
  if (values.isEmpty) return null;
  final total = values.fold<int>(0, (sum, value) => sum + value);
  return total / values.length;
}

double? _meanAbsoluteDeviation(List<int> values, double mean) {
  if (values.isEmpty) return null;
  final totalDeviation = values.fold<double>(
    0,
    (sum, value) => sum + (value - mean).abs(),
  );
  return totalDeviation / values.length;
}

int _countLoggedNights(
  List<SleepJournalEntry> entries,
  DateTime now,
  int days,
) {
  if (entries.isEmpty || days <= 0) return 0;
  final today = _dateOnly(now.toLocal());
  final cutoff = today.subtract(Duration(days: days - 1));
  final daysLogged = <DateTime>{};
  for (final entry in entries) {
    final date = _dateOnly(entry.endedAt.toLocal());
    if (date.isBefore(cutoff) || date.isAfter(today)) continue;
    daysLogged.add(date);
  }
  return daysLogged.length;
}

int _calculateLogStreak(List<SleepJournalEntry> entries, DateTime now) {
  if (entries.isEmpty) return 0;
  final daySet = <DateTime>{};
  for (final entry in entries) {
    daySet.add(_dateOnly(entry.endedAt.toLocal()));
  }
  var day = _dateOnly(now.toLocal());
  if (!daySet.contains(day)) {
    final yesterday = day.subtract(const Duration(days: 1));
    if (daySet.contains(yesterday)) {
      day = yesterday;
    } else {
      return 0;
    }
  }
  var streak = 0;
  while (daySet.contains(day)) {
    streak += 1;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _dateOnly(DateTime time) {
  return DateTime(time.year, time.month, time.day);
}

TimeOfDay? _effectiveStartTime(ScheduleConfig schedule, DateTime now) {
  if (!schedule.weekendDifferent) return schedule.startTime;
  final isWeekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (!isWeekend) return schedule.startTime;
  return schedule.weekendStartTime ?? schedule.startTime;
}

TimeOfDay? _effectiveEndTime(ScheduleConfig schedule, DateTime now) {
  if (!schedule.weekendDifferent) return schedule.endTime;
  final isWeekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (!isWeekend) return schedule.endTime;
  return schedule.weekendEndTime ?? schedule.endTime;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _consistencyScoreFromVariance(double varianceMinutes) {
  const maxVariance = 120.0;
  final normalized = (1 - (varianceMinutes / maxVariance)).clamp(0.0, 1.0);
  return (normalized * 100).round();
}

int _summaryNormalizeLateNightMinutes(DateTime time) {
  final minutes = time.hour * 60 + time.minute;
  if (minutes < 12 * 60) {
    return minutes + 24 * 60;
  }
  return minutes;
}

double? _summaryAverageMinutes(List<int> values) {
  if (values.isEmpty) return null;
  final total = values.fold<int>(0, (sum, value) => sum + value);
  return total / values.length;
}

double? _summaryMeanAbsoluteDeviation(List<int> values, double mean) {
  if (values.isEmpty) return null;
  final totalDeviation = values.fold<double>(
    0,
    (sum, value) => sum + (value - mean).abs(),
  );
  return totalDeviation / values.length;
}

int _summaryMinutesOfDay(DateTime time) => time.hour * 60 + time.minute;

int _summaryCountLoggedNights(
  List<SleepJournalEntry> entries,
  DateTime now,
  int days,
) {
  if (entries.isEmpty || days <= 0) return 0;
  final today = _summaryDateOnly(now.toLocal());
  final cutoff = today.subtract(Duration(days: days - 1));
  final daysLogged = <DateTime>{};
  for (final entry in entries) {
    final date = _summaryDateOnly(entry.endedAt.toLocal());
    if (date.isBefore(cutoff) || date.isAfter(today)) continue;
    daysLogged.add(date);
  }
  return daysLogged.length;
}

int _summaryCalculateLogStreak(List<SleepJournalEntry> entries, DateTime now) {
  if (entries.isEmpty) return 0;
  final daySet = <DateTime>{};
  for (final entry in entries) {
    daySet.add(_summaryDateOnly(entry.endedAt.toLocal()));
  }
  var day = _summaryDateOnly(now.toLocal());
  if (!daySet.contains(day)) {
    final yesterday = day.subtract(const Duration(days: 1));
    if (daySet.contains(yesterday)) {
      day = yesterday;
    } else {
      return 0;
    }
  }
  var streak = 0;
  while (daySet.contains(day)) {
    streak += 1;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _summaryDateOnly(DateTime time) {
  return DateTime(time.year, time.month, time.day);
}

String _formatSummaryDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatSummaryVariance(double minutes) {
  final rounded = minutes.round();
  if (rounded < 60) return '+/-${rounded}m';
  final hours = rounded ~/ 60;
  final mins = rounded % 60;
  if (mins == 0) return '+/-${hours}h';
  return '+/-${hours}h ${mins}m';
}

String _formatSummaryMinutes(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour24 = normalized ~/ 60;
  final minute = normalized % 60;
  final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  return '$hour:${minute.toString().padLeft(2, '0')} $period';
}
