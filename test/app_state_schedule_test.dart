import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightbuddy/models/filter_models.dart';
import 'package:nightbuddy/state/app_state.dart';

void main() {
  test('nextScheduleChange respects overnight schedules', () {
    final schedule = ScheduleConfig(
      mode: FilterMode.scheduled,
      startTime: const TimeOfDay(hour: 22, minute: 0),
      endTime: const TimeOfDay(hour: 6, minute: 0),
      windDownMinutes: 0,
      fadeOutMinutes: 0,
    );
    final state = AppState.initial().copyWith(schedule: schedule);

    final beforeStart = DateTime(2025, 1, 1, 21, 0);
    final nextBefore = state.nextScheduleChange(beforeStart);
    expect(nextBefore, DateTime(2025, 1, 1, 22, 0));

    final during = DateTime(2025, 1, 1, 23, 0);
    final nextDuring = state.nextScheduleChange(during);
    expect(nextDuring, DateTime(2025, 1, 2, 6, 0));
  });
}
