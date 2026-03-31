import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/filter_models.dart';
import '../../../state/app_notifier.dart';
import '../../../state/app_state.dart';
import 'environment_check_card.dart';
import 'mind_unload_card.dart';
import 'wind_down_routine_screen.dart';

class TonightFlowScreen extends ConsumerStatefulWidget {
  const TonightFlowScreen({super.key});

  @override
  ConsumerState<TonightFlowScreen> createState() => _TonightFlowScreenState();
}

class _TonightFlowScreenState extends ConsumerState<TonightFlowScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _currentStepKey = GlobalKey();
  String? _lastFocusedStep;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider).valueOrNull ?? AppState.initial();
    final notifier = ref.read(appStateProvider.notifier);
    final now = DateTime.now();
    final isFilterActive = state.isFilterActive(now);
    final screenOffUntil = state.screenOffUntil;
    final environmentChecklist = state.environmentChecklistFor(now);
    final environmentDone = environmentCheckItems
        .where((item) => environmentChecklist[item.id] == true)
        .length;
    final mindPending = state.mindUnloadEntries
        .where((entry) => !entry.resolved)
        .length;
    final routineChecklist = state.windDownChecklistFor(now);
    final routineDone = state.windDownItems
        .where((item) => routineChecklist[item.id] == true)
        .length;
    final startTime = _plannerStartTime(state, now);
    final bedtimeLabel = startTime == null ? null : _formatTimeOfDay(startTime);
    final bedtimeCountdown = startTime == null
        ? null
        : _formatCountdown(_nextStartTime(now, startTime).difference(now));
    final routineTotal = state.windDownItems.length;
    final roomDone = environmentDone == environmentCheckItems.length;
    final mindDone = mindPending == 0;
    final routineDoneCompletely = routineTotal == 0
        ? isFilterActive
        : routineDone == routineTotal;
    final phoneDownStarted = screenOffUntil != null;
    final steps = [
      _TonightStepData(
        step: '1',
        title: 'Set the room',
        subtitle: roomDone
            ? 'Room ready.'
            : 'Finish the practical checks so you are not interrupted later.',
        status: '$environmentDone/${environmentCheckItems.length} done',
        actionLabel: 'Review room',
        secondaryActionLabel: null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EnvironmentCheckScreen()),
          );
        },
        onSecondaryTap: null,
        isComplete: roomDone,
        completionLabel: 'Room ready',
      ),
      _TonightStepData(
        step: '2',
        title: 'Clear your mind',
        subtitle: mindDone
            ? 'Nothing is left hanging right now.'
            : '$mindPending thought${mindPending == 1 ? '' : 's'} still unresolved.',
        status: mindDone ? 'Ready' : '$mindPending pending',
        actionLabel: 'Clear my mind',
        secondaryActionLabel: null,
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MindUnloadScreen()));
        },
        onSecondaryTap: null,
        isComplete: mindDone,
        completionLabel: 'Mind cleared',
      ),
      _TonightStepData(
        step: '3',
        title: 'Start wind-down',
        subtitle: routineDoneCompletely
            ? 'Wind-down is active for tonight.'
            : 'Warm the screen, slow down, and move through your routine.',
        status: routineTotal == 0
            ? (isFilterActive ? 'Active' : 'Not started')
            : '$routineDone/$routineTotal done',
        actionLabel: isFilterActive ? 'Wind-down active' : 'Start wind-down',
        secondaryActionLabel: routineTotal == 0 ? null : 'Edit routine',
        onTap: isFilterActive
            ? null
            : () async {
                await notifier.toggleOverlay(true);
                if (state.bedtimeModeStartScreenOff) {
                  await notifier.startScreenOffGoal(
                    Duration(minutes: state.screenOffGoalMinutes),
                  );
                }
                if (state.bedtimeModeAutoOffMinutes > 0) {
                  await notifier.startBedtimeModeAutoOff(
                    Duration(minutes: state.bedtimeModeAutoOffMinutes),
                  );
                }
              },
        onSecondaryTap: routineTotal == 0
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WindDownRoutineScreen(),
                  ),
                );
              },
        isComplete: routineDoneCompletely,
        completionLabel: 'Wind-down active',
      ),
      _TonightStepData(
        step: '4',
        title: 'Put the phone down',
        subtitle: screenOffUntil == null
            ? 'Start a no-phone window to protect the last stretch before sleep.'
            : 'Phone-down time is active until ${screenOffUntil.clockLabel()}.',
        status: screenOffUntil == null ? 'Not started' : 'In progress',
        actionLabel: screenOffUntil == null
            ? 'Start phone-down time'
            : 'Active',
        secondaryActionLabel: null,
        onTap: screenOffUntil == null
            ? () async {
                await notifier.startScreenOffGoal(
                  Duration(minutes: state.screenOffGoalMinutes),
                );
              }
            : null,
        onSecondaryTap: null,
        isComplete: phoneDownStarted,
        completionLabel: 'Phone-down started',
      ),
    ];
    final nextStep = steps.where((step) => !step.isComplete).isEmpty
        ? null
        : steps.where((step) => !step.isComplete).first;
    final remainingSteps = steps.where((step) => !step.isComplete).toList();
    final upcomingSteps = remainingSteps.length > 1
        ? remainingSteps.skip(1).toList()
        : const <_TonightStepData>[];
    final completedSteps = steps.where((step) => step.isComplete).toList();
    _scheduleStepFocus(nextStep?.title);

    return Scaffold(
      appBar: AppBar(title: const Text('Tonight')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            bedtimeLabel == null
                ? 'A calmer night starts with a few deliberate steps.'
                : 'Bedtime around $bedtimeLabel. Move through the essentials in order.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedColor(context)),
          ),
          if (bedtimeCountdown != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Time until bed: $bedtimeCountdown',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
              ),
            ),
          const SizedBox(height: 16),
          _TonightSummaryCard(
            nextStepLabel: nextStep == null
                ? 'Tonight routine complete'
                : 'Next: ${nextStep.title}',
            helperText: nextStep == null
                ? 'Everything important for tonight is already in place. You can stop managing and start settling.'
                : 'Take one step at a time and keep the night simple.',
            completedCount: completedSteps.length,
            totalCount: steps.length,
            focusLabel: nextStep == null ? 'Everything ready' : 'Current focus',
            upNextLabel: upcomingSteps.isEmpty
                ? null
                : 'After that: ${upcomingSteps.first.title}',
          ),
          const SizedBox(height: 16),
          if (nextStep != null) ...[
            Text('Do this now', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _currentStepKey,
              child: _TonightStepCard(
                step: nextStep.step,
                title: nextStep.title,
                subtitle: nextStep.subtitle,
                status: nextStep.status,
                actionLabel: nextStep.actionLabel,
                secondaryActionLabel: nextStep.secondaryActionLabel,
                onTap: nextStep.onTap,
                onSecondaryTap: nextStep.onSecondaryTap,
                emphasized: true,
                helperLabel: 'Current focus',
              ),
            ),
          ],
          if (upcomingSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TonightUpcomingCard(steps: upcomingSteps),
          ],
          if (completedSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Already done',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...completedSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CompletedTonightStepCard(step: step),
              ),
            ),
          ],
          if (nextStep == null) ...[
            const SizedBox(height: 16),
            _TonightCompleteCard(
              bedtimeLabel: bedtimeLabel,
              phoneDownUntil: screenOffUntil,
            ),
          ],
        ],
      ),
    );
  }

  void _scheduleStepFocus(String? stepTitle) {
    if (stepTitle == null || _lastFocusedStep == stepTitle) return;
    _lastFocusedStep = stepTitle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _currentStepKey.currentContext;
      if (!mounted || context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.18,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _TonightStepData {
  const _TonightStepData({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.actionLabel,
    required this.secondaryActionLabel,
    required this.onTap,
    required this.onSecondaryTap,
    required this.isComplete,
    required this.completionLabel,
  });

  final String step;
  final String title;
  final String subtitle;
  final String status;
  final String actionLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final bool isComplete;
  final String completionLabel;
}

class _TonightSummaryCard extends StatelessWidget {
  const _TonightSummaryCard({
    required this.nextStepLabel,
    required this.helperText,
    required this.completedCount,
    required this.totalCount,
    required this.focusLabel,
    required this.upNextLabel,
  });

  final String nextStepLabel;
  final String helperText;
  final int completedCount;
  final int totalCount;
  final String focusLabel;
  final String? upNextLabel;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final progressLabel = completedCount == totalCount
        ? 'Tonight is fully ready'
        : '$completedCount of $totalCount steps ready';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                focusLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              nextStepLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              helperText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              progressLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            if (upNextLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                upNextLabel!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mutedColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TonightUpcomingCard extends StatelessWidget {
  const _TonightUpcomingCard({required this.steps});

  final List<_TonightStepData> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'After this',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'You do not need to think through the rest right now. These come next.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            ...steps.take(2).map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 12, child: Text(step.step)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.status,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: _mutedColor(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TonightCompleteCard extends StatelessWidget {
  const _TonightCompleteCard({
    required this.bedtimeLabel,
    required this.phoneDownUntil,
  });

  final String? bedtimeLabel;
  final DateTime? phoneDownUntil;

  @override
  Widget build(BuildContext context) {
    final helper = phoneDownUntil == null
        ? 'The essentials are done. Keep the phone out of the way and let the night stay quiet.'
        : 'Phone-down time is active until ${phoneDownUntil!.clockLabel()}. Let the rest of the night stay simple.';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Everything is set for tonight.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              bedtimeLabel == null
                  ? helper
                  : 'Bedtime around $bedtimeLabel. $helper',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TonightStepCard extends StatelessWidget {
  const _TonightStepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.actionLabel,
    required this.secondaryActionLabel,
    required this.onTap,
    required this.onSecondaryTap,
    this.helperLabel,
    this.emphasized = false,
  });

  final String step;
  final String title;
  final String subtitle;
  final String status;
  final String actionLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final String? helperLabel;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: emphasized
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text(step)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: emphasized
                        ? Theme.of(context).colorScheme.primary
                        : _mutedColor(context),
                    fontWeight: emphasized ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
            if (helperLabel != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  helperLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  if (secondaryActionLabel != null)
                    TextButton(
                      onPressed: onSecondaryTap,
                      child: Text(secondaryActionLabel!),
                    ),
                  ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedTonightStepCard extends StatelessWidget {
  const _CompletedTonightStepCard({required this.step});

  final _TonightStepData step;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.check, size: 16),
        ),
        title: Text(step.title),
        subtitle: Text(step.completionLabel),
        trailing: Text(
          step.status,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: _mutedColor(context)),
        ),
      ),
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

String _formatTimeOfDay(TimeOfDay time) {
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

extension _DateTimeClockLabel on DateTime {
  String clockLabel() {
    final local = toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
