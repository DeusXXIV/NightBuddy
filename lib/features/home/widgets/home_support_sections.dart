import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/filter_models.dart';
import '../../../models/mind_unload_entry.dart';
import '../../../services/ads_service.dart';
import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';
import '../../../widgets/ads_banner.dart';
import '../../../widgets/premium_ui.dart';
import '../../schedule/schedule_screen.dart';
import 'mind_unload_card.dart';

class HomeMindUnloadCarryOverCard extends ConsumerWidget {
  const HomeMindUnloadCarryOverCard({super.key, required this.entry});

  final MindUnloadEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  'Carry into today',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You left one mind-unload item unresolved from an earlier night.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.category,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MindUnloadScreen(),
                      ),
                    );
                  },
                  child: const Text('Open mind unload'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    await ref
                        .read(appStateProvider.notifier)
                        .toggleMindUnloadResolved(entry.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Carry-over item marked done'),
                      ),
                    );
                  },
                  child: const Text('Mark done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HomeNavigationGuideCard extends StatelessWidget {
  const HomeNavigationGuideCard({
    super.key,
    required this.audioSummary,
    required this.trackingSummary,
    required this.extrasSummary,
    required this.isReadyForTonight,
  });

  final String audioSummary;
  final String trackingSummary;
  final String extrasSummary;
  final bool isReadyForTonight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReadyForTonight) ...[
              Row(
                children: [
                  Icon(
                    Icons.bedtime_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You are set for tonight. These sections stay here for quick review or small changes.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _mutedColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _HomeNavigationGuideRow(
              icon: Icons.auto_graph_outlined,
              title: 'Journal',
              subtitle: trackingSummary,
            ),
            const SizedBox(height: 10),
            _HomeNavigationGuideRow(
              icon: Icons.graphic_eq_outlined,
              title: 'Audio',
              subtitle: audioSummary,
            ),
            const SizedBox(height: 10),
            _HomeNavigationGuideRow(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: extrasSummary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeNavigationGuideRow extends StatelessWidget {
  const _HomeNavigationGuideRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomeOverlayDebugCard extends StatelessWidget {
  const HomeOverlayDebugCard({super.key, required this.info});

  final AsyncValue<HomeOverlayDebugInfo> info;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: info.when(
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug: Overlay service',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text('Permission: ${data.hasPermission ? 'granted' : 'missing'}'),
              Text(
                'Native enabled: ${data.isEnabled == null ? 'unknown' : (data.isEnabled! ? 'true' : 'false')}',
              ),
            ],
          ),
          loading: () => const Text('Debug: Checking overlay status...'),
          error: (_, stackTrace) =>
              const Text('Debug: Overlay status unavailable'),
        ),
      ),
    );
  }
}

class HomeOverlayDebugInfo {
  const HomeOverlayDebugInfo({
    required this.hasPermission,
    required this.isEnabled,
  });

  final bool hasPermission;
  final bool? isEnabled;
}

class HomeScheduleCard extends StatelessWidget {
  const HomeScheduleCard({
    super.key,
    required this.state,
    required this.onOpen,
  });

  final AppState state;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final nextChange = state.nextScheduleChange(now);
    final scheduleLabel = _subtitle(schedule);
    final nextLabel = nextChange == null
        ? null
        : (state.isFilterActive(now)
              ? 'On until ${_formatDateTime(nextChange)}'
              : 'Starts at ${_formatDateTime(nextChange)}');
    final subtitle = nextLabel == null
        ? scheduleLabel
        : '$scheduleLabel\n$nextLabel';

    return Card(
      child: ListTile(
        title: const Text('Schedule'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final navigator = Navigator.of(context);
          await onOpen();
          navigator.push(
            MaterialPageRoute(builder: (_) => const ScheduleScreen()),
          );
        },
      ),
    );
  }

  String _subtitle(ScheduleConfig schedule) {
    switch (schedule.mode) {
      case FilterMode.off:
        return 'Off';
      case FilterMode.alwaysOn:
        return 'Always on';
      case FilterMode.scheduled:
        final start = _format(schedule.startTime);
        final end = _format(schedule.endTime);
        return '$start - $end';
    }
  }

  String _format(TimeOfDay? time) {
    if (time == null) return '--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: _mutedColor(context),
          ),
        ),
      ],
    );
  }
}

class HomeRemindersCard extends StatelessWidget {
  const HomeRemindersCard({
    super.key,
    required this.state,
    required this.onSnooze,
    required this.onResume,
  });

  final AppState state;
  final VoidCallback onSnooze;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final snoozed = state.isReminderSnoozed(now);
    final snoozedUntil = state.remindersSnoozedUntil;
    final nextBedtime = _nextBedtimeReminder(state, now);
    final nextCheckIn = _nextCheckInReminder(state, now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_outlined),
                const SizedBox(width: 8),
                Text(
                  'Reminders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snoozed && snoozedUntil != null)
              Text(
                'Snoozed until ${_formatDateTime(snoozedUntil)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
              ),
            Text(
              state.bedtimeReminderEnabled && nextBedtime != null
                  ? 'Bedtime reminder: ${_formatDateTime(nextBedtime)}'
                  : 'Bedtime reminder: Off',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            Text(
              state.sleepCheckInEnabled && nextCheckIn != null
                  ? 'Morning check-in: ${_formatDateTime(nextCheckIn)}'
                  : 'Morning check-in: Off',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: snoozed ? onResume : onSnooze,
                child: Text(snoozed ? 'Resume reminders' : 'Snooze 1 day'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _nextBedtimeReminder(AppState state, DateTime now) {
    if (!state.bedtimeReminderEnabled ||
        state.schedule.mode != FilterMode.scheduled ||
        state.schedule.startTime == null) {
      return null;
    }
    final startToday = _scheduleStartForDay(state.schedule, now);
    if (startToday == null) return null;
    final lead = Duration(minutes: state.bedtimeReminderMinutes);
    final todayReminder = startToday.subtract(lead);
    if (todayReminder.isAfter(now)) {
      return todayReminder;
    }
    final tomorrow = now.add(const Duration(days: 1));
    final startTomorrow = _scheduleStartForDay(state.schedule, tomorrow);
    if (startTomorrow == null) return null;
    return startTomorrow.subtract(lead);
  }

  DateTime? _scheduleStartForDay(ScheduleConfig schedule, DateTime day) {
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final start = schedule.weekendDifferent && isWeekend
        ? (schedule.weekendStartTime ?? schedule.startTime)
        : schedule.startTime;
    if (start == null) return null;
    return DateTime(day.year, day.month, day.day, start.hour, start.minute);
  }

  DateTime? _nextCheckInReminder(AppState state, DateTime now) {
    if (!state.sleepCheckInEnabled) return null;
    final time = state.sleepCheckInTime;
    final today = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (today.isAfter(now)) return today;
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      time.hour,
      time.minute,
    );
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class HomeScheduleTimelineCard extends StatelessWidget {
  const HomeScheduleTimelineCard({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final start = _effectiveScheduleStart(schedule, now);
    final end = _effectiveScheduleEnd(schedule, now);
    if (schedule.mode != FilterMode.scheduled || start == null || end == null) {
      return const SizedBox.shrink();
    }

    final nextStart = _nextStartTime(now, start);
    final nextEnd = _nextEnd(now, start, end);
    final windDownMinutes = schedule.windDownMinutes;
    final fadeOutMinutes = schedule.fadeOutMinutes;
    final activeMinutes = _activeWindowMinutes(start, end);
    final totalMinutes = windDownMinutes + activeMinutes + fadeOutMinutes;
    final windDownFlex = windDownMinutes > 0 ? windDownMinutes : null;
    final activeFlex = activeMinutes > 0 ? activeMinutes : 1;
    final fadeOutFlex = fadeOutMinutes > 0 ? fadeOutMinutes : null;
    final windDownStart = windDownMinutes > 0
        ? nextStart.subtract(Duration(minutes: windDownMinutes))
        : null;
    final fadeOutEnd = fadeOutMinutes > 0
        ? nextEnd.add(Duration(minutes: fadeOutMinutes))
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_outlined),
                const SizedBox(width: 8),
                Text(
                  'Tonight\'s timeline',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Start ${_formatDateTime(nextStart)} - End ${_formatDateTime(nextEnd)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (windDownFlex != null)
                  Expanded(
                    flex: windDownFlex,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (windDownFlex != null) const SizedBox(width: 4),
                Expanded(
                  flex: activeFlex,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                if (fadeOutFlex != null) const SizedBox(width: 4),
                if (fadeOutFlex != null)
                  Expanded(
                    flex: fadeOutFlex,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (windDownStart != null)
              Text(
                'Wind-down begins at ${_formatDateTime(windDownStart)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
              ),
            Text(
              'Filter active from ${_formatDateTime(nextStart)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            if (fadeOutEnd != null)
              Text(
                'Fade-out ends at ${_formatDateTime(fadeOutEnd)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
              ),
            const SizedBox(height: 6),
            Text(
              'Total window: ${_formatDuration(Duration(minutes: totalMinutes))}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _nextEnd(DateTime now, TimeOfDay start, TimeOfDay end) {
    final startDate = _nextStartTime(now, start);
    var endDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      end.hour,
      end.minute,
    );
    if (!endDate.isAfter(startDate)) {
      endDate = endDate.add(const Duration(days: 1));
    }
    return endDate;
  }

  int _activeWindowMinutes(TimeOfDay start, TimeOfDay end) {
    final startMinutes = _minutesOfDay(start);
    final endMinutes = _minutesOfDay(end);
    if (startMinutes == endMinutes) return 24 * 60;
    if (endMinutes > startMinutes) return endMinutes - startMinutes;
    return (24 * 60) - startMinutes + endMinutes;
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class HomePremiumCta extends StatelessWidget {
  const HomePremiumCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumUpsellCard(
      title: 'Unlock premium',
      subtitle: 'Unlimited custom presets, deeper insights, and extra audio.',
      onTap: onTap,
    );
  }
}

class HomeAdArea extends ConsumerWidget {
  const HomeAdArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.read(adsServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sponsored', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Center(child: AdsBanner(adUnitId: ads.bannerAdUnitId)),
          ],
        ),
      ),
    );
  }
}

TimeOfDay? _effectiveScheduleStart(ScheduleConfig schedule, DateTime now) {
  if (!schedule.weekendDifferent) return schedule.startTime;
  final isWeekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (!isWeekend) return schedule.startTime;
  return schedule.weekendStartTime ?? schedule.startTime;
}

TimeOfDay? _effectiveScheduleEnd(ScheduleConfig schedule, DateTime now) {
  if (!schedule.weekendDifferent) return schedule.endTime;
  final isWeekend =
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
  if (!isWeekend) return schedule.endTime;
  return schedule.weekendEndTime ?? schedule.endTime;
}

int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

DateTime _nextStartTime(DateTime now, TimeOfDay start) {
  final candidate = DateTime(
    now.year,
    now.month,
    now.day,
    start.hour,
    start.minute,
  );
  if (candidate.isAfter(now)) return candidate;
  return candidate.add(const Duration(days: 1));
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
