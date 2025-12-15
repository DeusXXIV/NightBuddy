// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/filter_models.dart';
import '../../state/app_notifier.dart';
import '../../state/app_state.dart';
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
    _weekendDifferent = schedule.weekendDifferent;
    _weekendStart = schedule.weekendStartTime;
    _weekendEnd = schedule.weekendEndTime;
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
                final navigator = Navigator.of(context);
                final config = ScheduleConfig(
                  mode: _mode,
                  startTime: _startTime,
                  endTime: _endTime,
                  weekendDifferent: _weekendDifferent && state.isPremium,
                  weekendStartTime: _weekendDifferent ? _weekendStart : null,
                  weekendEndTime: _weekendDifferent ? _weekendEnd : null,
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
      onChanged: (value) => setState(() => _mode = value!),
      title: Text(label),
    );
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
