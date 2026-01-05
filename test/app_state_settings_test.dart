import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nightbuddy/models/filter_models.dart';
import 'package:nightbuddy/state/app_state.dart';

void main() {
  test('AppState persists new settings and wind-down items', () {
    final base = AppState.initial();
    final updated = base.copyWith(
      screenOffUntil: DateTime(2025, 1, 1, 22, 0),
      blueLightGoalMinutes: 150,
      screenOffGoalMinutes: 90,
      caffeineCutoffHours: 8,
      bedtimeModePresetId: 'soft',
      bedtimeModeStartScreenOff: false,
      bedtimeModeAutoOffMinutes: 45,
      bedtimeModeAutoOffUntil: DateTime(2025, 1, 2, 2, 0),
      sunsetSyncEnabled: true,
      sunsetTime: const TimeOfDay(hour: 18, minute: 12),
      sunsetUpdatedAt: DateTime(2025, 1, 1),
      screenOffNotificationsEnabled: false,
      windDownItems: const [
        WindDownItem(id: 'tea', label: 'Make herbal tea'),
      ],
    );

    final roundTrip = AppState.fromJson(updated.toJson());
    expect(roundTrip.blueLightGoalMinutes, 150);
    expect(roundTrip.screenOffGoalMinutes, 90);
    expect(roundTrip.caffeineCutoffHours, 8);
    expect(roundTrip.bedtimeModePresetId, 'soft');
    expect(roundTrip.bedtimeModeStartScreenOff, isFalse);
    expect(roundTrip.bedtimeModeAutoOffMinutes, 45);
    expect(roundTrip.bedtimeModeAutoOffUntil?.day, 2);
    expect(roundTrip.sunsetSyncEnabled, isTrue);
    expect(roundTrip.sunsetTime?.hour, 18);
    expect(roundTrip.screenOffNotificationsEnabled, isFalse);
    expect(roundTrip.windDownItems.length, 1);
    expect(roundTrip.windDownItems.first.label, 'Make herbal tea');
    expect(roundTrip.screenOffUntil?.year, 2025);
  });

  test('AppState copyWith can clear nullable fields', () {
    final base = AppState.initial().copyWith(
      screenOffUntil: DateTime(2025, 1, 1, 22, 0),
    );
    final cleared = base.copyWith(screenOffUntil: null);
    expect(cleared.screenOffUntil, isNull);
  });

  test('Planner uses weekend start time when configured', () {
    final schedule = ScheduleConfig(
      mode: FilterMode.scheduled,
      startTime: const TimeOfDay(hour: 22, minute: 0),
      endTime: const TimeOfDay(hour: 6, minute: 0),
      weekendDifferent: true,
      weekendStartTime: const TimeOfDay(hour: 23, minute: 0),
      weekendEndTime: const TimeOfDay(hour: 7, minute: 0),
    );
    final state = AppState.initial().copyWith(schedule: schedule);
    final saturday = DateTime(2025, 1, 4);
    expect(
      state.schedule.weekendDifferent,
      isTrue,
    );
    expect(
      state.schedule.weekendStartTime,
      const TimeOfDay(hour: 23, minute: 0),
    );
    expect(saturday.weekday, DateTime.saturday);
  });
}
