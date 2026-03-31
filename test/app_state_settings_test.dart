import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nightbuddy/models/filter_models.dart';
import 'package:nightbuddy/models/mind_unload_entry.dart';
import 'package:nightbuddy/models/sleep_journal.dart';
import 'package:nightbuddy/state/app_state.dart';

void main() {
  test('AppState persists new settings and wind-down items', () {
    final base = AppState.initial();
    final updated = base.copyWith(
      screenOffUntil: DateTime(2025, 1, 1, 22, 0),
      blueLightGoalMinutes: 150,
      screenOffGoalMinutes: 90,
      caffeineCutoffHours: 8,
      favoritePresetId: 'medium',
      bedtimeModePresetId: 'soft',
      favoriteSleepTrackId: 'drift',
      preferredSleepTimerMinutes: 60,
      bedtimeModeStartScreenOff: false,
      bedtimeModeAutoOffMinutes: 45,
      bedtimeModeAutoOffUntil: DateTime(2025, 1, 2, 2, 0),
      sunsetSyncEnabled: true,
      sunsetTime: const TimeOfDay(hour: 18, minute: 12),
      sunsetUpdatedAt: DateTime(2025, 1, 1),
      screenOffNotificationsEnabled: false,
      remindersSnoozedUntil: DateTime(2025, 1, 3, 8, 0),
      windDownCompletedDates: const ['2025-01-01'],
      windDownItems: const [
        WindDownItem(id: 'tea', label: 'Make herbal tea'),
      ],
      showDebugTools: true,
    );

    final roundTrip = AppState.fromJson(updated.toJson());
    expect(roundTrip.blueLightGoalMinutes, 150);
    expect(roundTrip.screenOffGoalMinutes, 90);
    expect(roundTrip.caffeineCutoffHours, 8);
    expect(roundTrip.favoritePresetId, 'medium');
    expect(roundTrip.bedtimeModePresetId, 'soft');
    expect(roundTrip.favoriteSleepTrackId, 'drift');
    expect(roundTrip.preferredSleepTimerMinutes, 60);
    expect(roundTrip.bedtimeModeStartScreenOff, isFalse);
    expect(roundTrip.bedtimeModeAutoOffMinutes, 45);
    expect(roundTrip.bedtimeModeAutoOffUntil?.day, 2);
    expect(roundTrip.sunsetSyncEnabled, isTrue);
    expect(roundTrip.sunsetTime?.hour, 18);
    expect(roundTrip.screenOffNotificationsEnabled, isFalse);
    expect(roundTrip.remindersSnoozedUntil?.day, 3);
    expect(roundTrip.windDownCompletedDates.length, 1);
    expect(roundTrip.windDownItems.length, 1);
    expect(roundTrip.windDownItems.first.label, 'Make herbal tea');
    expect(roundTrip.showDebugTools, isTrue);
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

  test('SleepJournalEntry persists tags', () {
    final entry = SleepJournalEntry(
      startedAt: DateTime(2025, 1, 1, 22, 0),
      endedAt: DateTime(2025, 1, 2, 6, 0),
      quality: 4,
      notes: 'Fell asleep quickly',
      tags: const ['Caffeine', 'Late screen'],
    );
    final roundTrip = SleepJournalEntry.fromJson(entry.toJson());
    expect(roundTrip.tags.length, 2);
    expect(roundTrip.tags.first, 'Caffeine');
  });

  test('MindUnloadEntry persists through AppState', () {
    final state = AppState.initial().copyWith(
      mindUnloadEntries: [
        MindUnloadEntry(
          id: 'mind_1',
          createdAt: DateTime(2025, 1, 1, 21, 30),
          text: 'Pack charger for tomorrow.',
          category: 'Reminder',
        ),
      ],
    );

    final roundTrip = AppState.fromJson(state.toJson());
    expect(roundTrip.mindUnloadEntries.length, 1);
    expect(roundTrip.mindUnloadEntries.first.category, 'Reminder');
    expect(roundTrip.mindUnloadEntries.first.text, 'Pack charger for tomorrow.');
  });

  test('Environment checklist persists through AppState', () {
    final state = AppState.initial().copyWith(
      environmentChecklistDate: DateTime(2025, 1, 1),
      environmentChecklist: const {
        'lights': true,
        'alarm': true,
      },
    );

    final roundTrip = AppState.fromJson(state.toJson());
    expect(roundTrip.environmentChecklistDate?.year, 2025);
    expect(roundTrip.environmentChecklist['lights'], isTrue);
    expect(roundTrip.environmentChecklist['alarm'], isTrue);
  });
}
