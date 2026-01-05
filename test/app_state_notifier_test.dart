import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nightbuddy/models/filter_models.dart';
import 'package:nightbuddy/services/ads_service.dart';
import 'package:nightbuddy/services/bedtime_reminder_service.dart';
import 'package:nightbuddy/services/overlay_service.dart';
import 'package:nightbuddy/services/premium_service.dart';
import 'package:nightbuddy/services/storage_service.dart';
import 'package:nightbuddy/services/log_service.dart';
import 'package:nightbuddy/state/app_notifier.dart';
import 'package:nightbuddy/state/app_state.dart';

class FakeOverlayService extends OverlayService {
  FakeOverlayService({this.nativeEnabled});

  bool? nativeEnabled;

  @override
  Future<void> initialize() async {}

  @override
  Stream<bool> get overlayStatusStream => const Stream<bool>.empty();

  @override
  Stream<void> get toggleRequests => const Stream<void>.empty();

  @override
  Future<bool?> isOverlayEnabled() async => nativeEnabled;

  @override
  Future<void> startOverlay({
    required FilterPreset preset,
    required bool showNotification,
  }) async {
    nativeEnabled = true;
  }

  @override
  Future<void> stopOverlay({required bool showNotification}) async {
    nativeEnabled = false;
  }

  @override
  Future<bool?> getFlashlightStatus() async => null;
}

class FakeStorageService extends StorageService {
  FakeStorageService({this.storedState});

  AppState? storedState;
  final List<AppState> savedStates = [];

  @override
  Future<AppState?> loadState() async => storedState;

  @override
  Future<void> saveState(AppState state) async {
    savedStates.add(state);
    storedState = state;
  }
}

class FakePremiumService extends PremiumService {
  FakePremiumService({bool isPremium = false}) : _isPremium = isPremium;

  bool _isPremium;

  @override
  Future<void> initialize() async {}

  @override
  bool get isPremium => _isPremium;

  @override
  Future<void> setPremium(bool value) async {
    _isPremium = value;
  }
}

class FakeAdsService extends AdsService {
  @override
  Future<void> initialize() async {}
}

class FakeBedtimeReminderService extends BedtimeReminderService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> updateReminders({
    required ScheduleConfig schedule,
    required bool enabled,
    required int leadMinutes,
  }) async {}

  @override
  Future<void> updateCheckInReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {}
}

class FakeLogService extends LogService {
  final List<AppLogEntry> events = [];

  @override
  Stream<List<AppLogEntry>> get entries => Stream.value(events);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent({
    required String type,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    events.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        type: type,
        message: message,
        details: details,
      ),
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('reconciles overlay state when native overlay is already running',
      () async {
    final stored = AppState.initial().copyWith(filterEnabled: false);
    final storage = FakeStorageService(storedState: stored);
    final overlay = FakeOverlayService(nativeEnabled: true);

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        overlayServiceProvider.overrideWithValue(overlay),
        premiumServiceProvider.overrideWithValue(FakePremiumService()),
        adsServiceProvider.overrideWithValue(FakeAdsService()),
        bedtimeReminderServiceProvider
            .overrideWithValue(FakeBedtimeReminderService()),
        logServiceProvider.overrideWithValue(FakeLogService()),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(appStateProvider.future);

    expect(state.filterEnabled, isTrue);
    expect(storage.savedStates.isNotEmpty, isTrue);
    expect(storage.savedStates.last.filterEnabled, isTrue);
  });

  test('snooze until next change uses upcoming schedule', () async {
    final now = DateTime.now();
    final start = TimeOfDay(
      hour: (now.hour + 1) % 24,
      minute: now.minute,
    );
    final end = TimeOfDay(
      hour: (now.hour + 2) % 24,
      minute: now.minute,
    );
    final schedule = ScheduleConfig(
      mode: FilterMode.scheduled,
      startTime: start,
      endTime: end,
      windDownMinutes: 0,
      fadeOutMinutes: 0,
    );
    final stored = AppState.initial().copyWith(schedule: schedule);
    final storage = FakeStorageService(storedState: stored);
    final overlay = FakeOverlayService(nativeEnabled: true);

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        overlayServiceProvider.overrideWithValue(overlay),
        premiumServiceProvider.overrideWithValue(FakePremiumService()),
        adsServiceProvider.overrideWithValue(FakeAdsService()),
        bedtimeReminderServiceProvider
            .overrideWithValue(FakeBedtimeReminderService()),
        logServiceProvider.overrideWithValue(FakeLogService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appStateProvider.future);
    final notifier = container.read(appStateProvider.notifier);
    final ok = await notifier.snoozeUntilNextChange();
    final updated = container.read(appStateProvider).value;

    expect(ok, isTrue);
    expect(updated?.snoozeUntil, isNotNull);
    expect(updated!.snoozeUntil!.isAfter(DateTime.now()), isTrue);
  });
}
