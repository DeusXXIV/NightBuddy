// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/filter_models.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
import '../../widgets/preset_chip.dart';
import '../root/root_shell.dart';
import '../premium/premium_screen.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late FilterMode _mode;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _windDownMinutes = 0;
  int _fadeOutMinutes = 0;
  String? _targetPresetId;
  bool _weekendDifferent = false;
  TimeOfDay? _weekendStart;
  TimeOfDay? _weekendEnd;
  late final ProviderSubscription<AsyncValue<AppState>> _subscription;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateProvider).value ?? AppState.initial();
    _hydrate(state.schedule);
    _subscription = ref.listenManual<AsyncValue<AppState>>(appStateProvider, (
      previous,
      next,
    ) {
      if (next.hasValue && mounted) {
        setState(() {
          _hydrate(next.value!.schedule);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }

  void _hydrate(ScheduleConfig schedule) {
    _mode = schedule.mode;
    _startTime = schedule.startTime;
    _endTime = schedule.endTime;
    _windDownMinutes = schedule.windDownMinutes;
    _fadeOutMinutes = schedule.fadeOutMinutes;
    _targetPresetId = schedule.targetPresetId;
    _weekendDifferent = schedule.weekendDifferent;
    _weekendStart = schedule.weekendStartTime;
    _weekendEnd = schedule.weekendEndTime;
    if (_mode == FilterMode.scheduled) {
      _startTime ??= const TimeOfDay(hour: 22, minute: 0);
      _endTime ??= const TimeOfDay(hour: 6, minute: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    return appState.when(
      data: (state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Schedule')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_mode == FilterMode.scheduled)
                  _scheduleSummaryCard(state),
                _modeTile(FilterMode.off, 'Off'),
                _modeTile(FilterMode.alwaysOn, 'Always on'),
                _modeTile(FilterMode.scheduled, 'Custom schedule'),
                if (_mode == FilterMode.scheduled) ...[
                  const SizedBox(height: 12),
                  _timeRow(
                    context,
                    label: 'Start',
                    time: _startTime,
                    onPick: (value) => setState(() => _startTime = value),
                  ),
                  _timeRow(
                    context,
                    label: 'End',
                    time: _endTime,
                    onPick: (value) => setState(() => _endTime = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If end time is earlier than start time, it counts as next day.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Wind-down',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Gradually ramp the filter before the start time.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    min: 0,
                    max: 180,
                    divisions: 12,
                    value: _windDownMinutes.toDouble(),
                    label: _windDownMinutes == 0
                        ? 'Off'
                        : '$_windDownMinutes min',
                    onChanged: (value) {
                      setState(() => _windDownMinutes = value.round());
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fade-out',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Gently ease the filter off after the end time.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Slider(
                    min: 0,
                    max: 120,
                    divisions: 8,
                    value: _fadeOutMinutes.toDouble(),
                    label: _fadeOutMinutes == 0
                        ? 'Off'
                        : '$_fadeOutMinutes min',
                    onChanged: (value) {
                      setState(() => _fadeOutMinutes = value.round());
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Night preset',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Pick a preset to use during the schedule and wind-down.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Use current preset'),
                            selected: _targetPresetId == null,
                            onSelected: (_) {
                              setState(() => _targetPresetId = null);
                            },
                          ),
                        ),
                        ...state.presets.map((preset) {
                          final selected = _targetPresetId == preset.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: PresetChip(
                              preset: preset,
                              selected: selected,
                              isPremiumLocked: !state.isPremium,
                              onSelected: () {
                                if (preset.isPremium && !state.isPremium) {
                                  _promptPremium(context);
                                  return;
                                }
                                setState(() => _targetPresetId = preset.id);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _weekendDifferent && state.isPremium,
                    onChanged: (value) {
                      if (!state.isPremium) {
                        _promptPremium(context);
                        return;
                      }
                      setState(() => _weekendDifferent = value);
                    },
                    title: const Text('Different weekend schedule (Premium)'),
                    subtitle: !_weekendDifferent
                        ? null
                        : Text(
                            _weekendDifferent
                                ? 'Weekend times shown below'
                                : 'Enable to set weekend times',
                          ),
                  ),
                  if (_weekendDifferent)
                    Column(
                      children: [
                        _timeRow(
                          context,
                          label: 'Weekend start',
                          time: _weekendStart,
                          onPick: (value) =>
                              setState(() => _weekendStart = value),
                        ),
                        _timeRow(
                          context,
                          label: 'Weekend end',
                          time: _weekendEnd,
                          onPick: (value) =>
                              setState(() => _weekendEnd = value),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                if (_mode == FilterMode.scheduled &&
                    (_startTime == null || _endTime == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select a start and end time to continue'),
                    ),
                  );
                  return;
                }
                final navigator = Navigator.of(context);
                final weekendStart =
                    _weekendDifferent ? (_weekendStart ?? _startTime) : null;
                final weekendEnd =
                    _weekendDifferent ? (_weekendEnd ?? _endTime) : null;
                final config = ScheduleConfig(
                  mode: _mode,
                  startTime: _startTime,
                  endTime: _endTime,
                  windDownMinutes: _windDownMinutes,
                  fadeOutMinutes: _fadeOutMinutes,
                  targetPresetId: _targetPresetId,
                  weekendDifferent: _weekendDifferent && state.isPremium,
                  weekendStartTime: weekendStart,
                  weekendEndTime: weekendEnd,
                );
                await ref
                    .read(appStateProvider.notifier)
                    .updateSchedule(config);
                if (navigator.canPop()) {
                  navigator.pop();
                } else {
                  navigator.pushReplacement(
                    MaterialPageRoute(builder: (_) => const RootShell()),
                  );
                }
              },
              child: const Text('Save schedule'),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }

  Widget _modeTile(FilterMode mode, String label) {
    return RadioListTile<FilterMode>(
      value: mode,
      groupValue: _mode,
      onChanged: (value) {
        if (value == null) return;
        _setMode(value);
      },
      title: Text(label),
    );
  }

  Widget _scheduleSummaryCard(AppState state) {
    final start = _startTime;
    final end = _endTime;
    final presetLabel = _targetPresetId == null
        ? '${state.activePreset.name} (current)'
        : state.presets
            .firstWhere(
              (preset) => preset.id == _targetPresetId,
              orElse: () => state.activePreset,
            )
            .name;

    if (start == null || end == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.schedule),
          title: Text('Schedule preview'),
          subtitle: Text('Pick a start and end time to see the preview.'),
        ),
      );
    }

    final now = DateTime.now();
    final nextStart = _nextStart(now, start);
    final nextEnd = _nextEnd(now, start, end);
    final windDownStart = _windDownMinutes > 0
        ? nextStart.subtract(Duration(minutes: _windDownMinutes))
        : null;
    final fadeOutEnd = _fadeOutMinutes > 0
        ? nextEnd.add(Duration(minutes: _fadeOutMinutes))
        : null;
    final summaryLines = [
      'Next start: ${_formatDateTime(nextStart)}',
      'Next end: ${_formatDateTime(nextEnd)}',
      if (windDownStart != null)
        'Wind-down starts: ${_formatDateTime(windDownStart)}',
      if (fadeOutEnd != null)
        'Fade-out ends: ${_formatDateTime(fadeOutEnd)}',
      'Preset: $presetLabel',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule preview',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...summaryLines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  line,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _mutedColor(context)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setMode(FilterMode mode) {
    setState(() {
      _mode = mode;
      if (_mode == FilterMode.scheduled) {
        _startTime ??= const TimeOfDay(hour: 22, minute: 0);
        _endTime ??= const TimeOfDay(hour: 6, minute: 0);
      }
    });
  }

  Widget _timeRow(
    BuildContext context, {
    required String label,
    required TimeOfDay? time,
    required ValueChanged<TimeOfDay> onPick,
  }) {
    return ListTile(
      title: Text(label),
      subtitle: Text(_format(time)),
      trailing: const Icon(Icons.access_time),
      onTap: () async {
        final result = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 22, minute: 0),
        );
        if (!context.mounted) return;
        if (result != null) {
          onPick(result);
        }
      },
    );
  }

  String _format(TimeOfDay? time) {
    if (time == null) return '--';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  DateTime _nextStart(DateTime now, TimeOfDay start) {
    final candidate =
        DateTime(now.year, now.month, now.day, start.hour, start.minute);
    if (candidate.isAfter(now)) return candidate;
    return candidate.add(const Duration(days: 1));
  }

  DateTime _nextEnd(DateTime now, TimeOfDay start, TimeOfDay end) {
    final startDate = _nextStart(now, start);
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

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _promptPremium(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Premium feature - unlock to use advanced schedules'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }
}

Color _mutedColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
