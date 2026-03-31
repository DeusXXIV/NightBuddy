import 'package:flutter/material.dart';

import '../../../models/filter_models.dart';
import '../../../state/app_state.dart';
import 'environment_check_card.dart';

enum _TonightSetupAction { schedule, defaults, routine }

class TonightPlanCard extends StatelessWidget {
  const TonightPlanCard({
    super.key,
    required this.state,
    required this.onOpenSchedule,
    required this.onApplyRoutineTemplate,
    required this.onOpenUsualNightSetup,
    required this.onOpenRoutineEditor,
    required this.onOpenTonightFlow,
    required this.onStartWindDown,
    required this.onStartUsualNight,
  });

  final AppState state;
  final Future<void> Function() onOpenSchedule;
  final Future<void> Function(List<String> labels) onApplyRoutineTemplate;
  final VoidCallback onOpenUsualNightSetup;
  final VoidCallback onOpenRoutineEditor;
  final VoidCallback onOpenTonightFlow;
  final Future<void> Function() onStartWindDown;
  final Future<void> Function() onStartUsualNight;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final now = DateTime.now();
    final startTime = _plannerStartTime(state, now);
    final endTime = _effectiveScheduleEnd(schedule, now);
    final hasSchedule =
        schedule.mode == FilterMode.scheduled &&
        startTime != null &&
        endTime != null;

    final items = state.windDownItems;
    final checklist = state.windDownChecklistFor(now);
    final completedCount = items
        .where((item) => checklist[item.id] == true)
        .length;
    final totalCount = items.length;
    final allDone = completedCount == totalCount && totalCount > 0;
    final streak = _calculateWindDownStreak(state.windDownCompletedDates, now);
    final summary = totalCount == 0
        ? 'Add your routine in Settings.'
        : allDone
        ? 'All done for tonight.'
        : 'Completed $completedCount of $totalCount tonight.';
    final nextStart = hasSchedule ? _nextStartTime(now, startTime) : null;
    final windDownMinutes = schedule.windDownMinutes > 0
        ? schedule.windDownMinutes
        : 30;
    final cutoffHours = state.caffeineCutoffHours > 0
        ? state.caffeineCutoffHours
        : 6;
    final steps = hasSchedule && nextStart != null
        ? [
            _PlannerStep(
              label: 'Caffeine cutoff',
              when: nextStart.subtract(Duration(hours: cutoffHours)),
              icon: Icons.local_cafe_outlined,
            ),
            _PlannerStep(
              label: 'Dim lights + slow down',
              when: nextStart.subtract(const Duration(hours: 2)),
              icon: Icons.lightbulb_outline,
            ),
            _PlannerStep(
              label: 'Start wind-down routine',
              when: nextStart.subtract(Duration(minutes: windDownMinutes)),
              icon: Icons.nightlight_outlined,
            ),
          ]
        : const <_PlannerStep>[];
    final nextStepIndex = steps.indexWhere((step) => step.when.isAfter(now));
    final nextStep = nextStepIndex == -1
        ? (steps.isNotEmpty ? steps.last : null)
        : steps[nextStepIndex];
    final bedtimeCountdown = nextStart?.difference(now);
    final windDownStart = nextStart?.subtract(
      Duration(minutes: windDownMinutes),
    );
    final windDownCountdown = windDownStart?.difference(now);
    final isFilterActive = state.isFilterActive(now);
    final screenOffUntil = state.screenOffUntil;
    final screenOffLabel = screenOffUntil == null
        ? 'Not started'
        : 'Until ${screenOffUntil.clockLabel()}';
    final canStartWindDown = !isFilterActive || screenOffUntil == null;
    final windDownLabel = canStartWindDown
        ? 'Start wind-down'
        : 'Wind-down active';
    final environmentChecklist = state.environmentChecklistFor(now);
    final environmentDone = environmentCheckItems
        .where((item) => environmentChecklist[item.id] == true)
        .length;
    final roomReady = environmentDone == environmentCheckItems.length;
    final mindPending = state.mindUnloadEntries
        .where((entry) => !entry.resolved)
        .length;
    final routineReady = totalCount > 0 && allDone;
    final bedtimeProgress = [
      roomReady,
      mindPending == 0,
      isFilterActive,
      screenOffUntil != null,
    ].where((done) => done).length;
    final nextAction = roomReady
        ? mindPending > 0
              ? 'Next: clear your mind'
              : !isFilterActive
              ? 'Next: start wind-down'
              : screenOffUntil == null
              ? 'Next: start phone-down time'
              : 'Tonight is ready'
        : 'Next: review your room';
    final nextActionDetail = roomReady
        ? mindPending > 0
              ? '$mindPending thought${mindPending == 1 ? '' : 's'} still need attention.'
              : !isFilterActive
              ? 'Warm the screen and begin your routine.'
              : screenOffUntil == null
              ? 'Protect the last stretch before bed from screen time.'
              : 'Filter and phone-down goals are already active.'
        : 'Finish the practical room checks before you settle in.';
    final readinessLabel = bedtimeProgress == 4
        ? 'Everything is set for tonight.'
        : '$bedtimeProgress of 4 bedtime steps ready';
    final continueLabel = roomReady
        ? mindPending > 0
              ? 'Continue with mind clear'
              : !isFilterActive
              ? 'Continue with wind-down'
              : screenOffUntil == null
              ? 'Continue with phone-down'
              : 'Review tonight'
        : 'Continue with room check';
    final quickStartLabel =
        state.favoritePresetId != null &&
            state.favoritePresetId != state.activePresetId &&
            canStartWindDown
        ? 'Start usual wind-down'
        : windDownLabel;
    const starterTemplates = <({String label, List<String> items})>[
      (
        label: 'Quick reset',
        items: [
          'Dim the lights',
          'Silence notifications',
          'Put the phone face down',
        ],
      ),
      (
        label: 'Gentle drift',
        items: [
          'Brush teeth and wash up',
          'Stretch or breathe for 2 minutes',
          'Write tomorrow\'s top priority',
          'Sip water and slow down',
        ],
      ),
      (
        label: 'Screen-off push',
        items: [
          'Plug in the phone away from bed',
          'Set alarm and check essentials',
          'Pick one calm audio track',
        ],
      ),
    ];

    return Card(
      color: bedtimeProgress == 4
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Theme.of(context).colorScheme.surfaceContainerLowest,
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
                  'Settle in',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasSchedule
                  ? 'Bedtime around ${_formatTimeOfDay(startTime)}'
                  : 'Set a schedule to anchor your night.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            if (bedtimeCountdown != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Bedtime in ${_formatCountdown(bedtimeCountdown)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
                ),
              ),
            if (windDownCountdown != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  windDownCountdown.isNegative
                      ? 'Wind-down is in progress now'
                      : 'Wind-down starts in ${_formatCountdown(windDownCountdown)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
                ),
              ),
            if (state.sunsetSyncEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sunset sync: ${_formatTimeOfDay(_sunsetLabel(state, now))}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nextAction,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nextActionDetail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _mutedColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: bedtimeProgress / 4),
                  const SizedBox(height: 6),
                  Text(
                    readinessLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _mutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: 'Room',
                  value: roomReady ? 'Ready' : '$environmentDone/4',
                  active: roomReady,
                ),
                _StatusChip(
                  label: 'Mind',
                  value: mindPending == 0 ? 'Clear' : '$mindPending open',
                  active: mindPending == 0,
                ),
                _StatusChip(
                  label: 'Wind-down',
                  value: isFilterActive
                      ? 'Active'
                      : routineReady
                      ? 'Ready'
                      : totalCount == 0
                      ? 'Not set'
                      : '$completedCount/$totalCount',
                  active: isFilterActive || routineReady,
                ),
                _StatusChip(
                  label: 'Phone-down',
                  value: screenOffLabel,
                  active: screenOffUntil != null,
                ),
              ],
            ),
            if (hasSchedule) ...[
              const SizedBox(height: 12),
              if (bedtimeProgress < 4)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coming up tonight',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...steps.map(
                        (step) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(step.icon, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(step.label)),
                              Text(
                                _formatStepTime(step, now, nextStep),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: _mutedColor(context)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tonight is already in a good place. You can put the phone down.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: _mutedColor(context)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(summary, style: Theme.of(context).textTheme.bodyMedium),
            if (totalCount == 0) ...[
              const SizedBox(height: 10),
              Text(
                'Start with a template',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: starterTemplates.map((template) {
                  return ActionChip(
                    label: Text(template.label),
                    onPressed: () => onApplyRoutineTemplate(template.items),
                  );
                }).toList(),
              ),
            ],
            if (streak > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Streak: $streak night${streak == 1 ? '' : 's'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: onOpenTonightFlow,
                  child: Text(continueLabel),
                ),
                FilledButton.tonal(
                  onPressed: onStartUsualNight,
                  child: const Text('Start usual night'),
                ),
                OutlinedButton(
                  onPressed: canStartWindDown ? onStartWindDown : null,
                  child: Text(quickStartLabel),
                ),
                PopupMenuButton<_TonightSetupAction>(
                  tooltip: 'Adjust setup',
                  onSelected: (value) {
                    if (value == _TonightSetupAction.schedule) {
                      onOpenSchedule();
                    } else if (value == _TonightSetupAction.defaults) {
                      onOpenUsualNightSetup();
                    } else if (value == _TonightSetupAction.routine) {
                      onOpenRoutineEditor();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _TonightSetupAction.schedule,
                      child: Text(
                        hasSchedule ? 'Adjust schedule' : 'Set schedule',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _TonightSetupAction.defaults,
                      child: Text('Usual night setup'),
                    ),
                    if (totalCount > 0)
                      const PopupMenuItem(
                        value: _TonightSetupAction.routine,
                        child: Text('Edit routine'),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Adjust setup'),
                        SizedBox(width: 6),
                        Icon(Icons.expand_more, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerStep {
  const _PlannerStep({
    required this.label,
    required this.when,
    required this.icon,
  });

  final String label;
  final DateTime when;
  final IconData icon;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.active = false,
  });

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = active
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surfaceContainerHighest;
    final textColor = active ? scheme.primary : scheme.onSurfaceVariant;

    return Chip(
      label: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: textColor),
      ),
      backgroundColor: background,
      side: BorderSide(
        color: active
            ? scheme.primary.withValues(alpha: 0.2)
            : Colors.transparent,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

TimeOfDay? _plannerStartTime(AppState state, DateTime now) {
  final schedule = state.schedule;
  final scheduled = _effectiveScheduleStart(schedule, now);
  if (!state.sunsetSyncEnabled) return scheduled;
  final sunset = state.sunsetTime ?? _approxSunsetTime(now);
  if (scheduled == null) return sunset;
  return _minutesOfDay(sunset) < _minutesOfDay(scheduled) ? sunset : scheduled;
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

TimeOfDay _sunsetLabel(AppState state, DateTime now) {
  return state.sunsetTime ?? _approxSunsetTime(now);
}

TimeOfDay _approxSunsetTime(DateTime now) {
  switch (now.month) {
    case 12:
    case 1:
      return const TimeOfDay(hour: 17, minute: 0);
    case 2:
      return const TimeOfDay(hour: 17, minute: 30);
    case 3:
      return const TimeOfDay(hour: 18, minute: 15);
    case 4:
      return const TimeOfDay(hour: 19, minute: 0);
    case 5:
      return const TimeOfDay(hour: 20, minute: 0);
    case 6:
      return const TimeOfDay(hour: 20, minute: 30);
    case 7:
      return const TimeOfDay(hour: 20, minute: 15);
    case 8:
      return const TimeOfDay(hour: 19, minute: 45);
    case 9:
      return const TimeOfDay(hour: 19, minute: 0);
    case 10:
      return const TimeOfDay(hour: 18, minute: 15);
    case 11:
      return const TimeOfDay(hour: 17, minute: 30);
    default:
      return const TimeOfDay(hour: 18, minute: 30);
  }
}

int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

String _formatTimeOfDay(TimeOfDay? time) {
  if (time == null) return '--';
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _formatCountdown(Duration duration) {
  if (duration.isNegative) return 'now';
  final minutes = duration.inMinutes;
  if (minutes < 1) return 'under 1m';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}

String _formatStepTime(
  _PlannerStep step,
  DateTime now,
  _PlannerStep? nextStep,
) {
  if (nextStep != null && step.label == nextStep.label) {
    return 'Next ${_formatDateTime(step.when)}';
  }
  if (step.when.isAfter(now)) return _formatDateTime(step.when);
  return 'Now';
}

String _formatDateTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

int _calculateWindDownStreak(List<String> completedDates, DateTime now) {
  if (completedDates.isEmpty) return 0;
  final dateSet = completedDates.toSet();
  var day = DateTime(now.year, now.month, now.day);
  final todayKey = _dateKey(day);
  if (!dateSet.contains(todayKey)) {
    day = day.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (dateSet.contains(_dateKey(day))) {
    streak += 1;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

extension on DateTime {
  String clockLabel() {
    final local = toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
