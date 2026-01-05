import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/filter_models.dart';
import '../models/sleep_journal.dart';
import '../services/overlay_service.dart';
import '../services/premium_service.dart';
import '../services/ads_service.dart';
import '../services/bedtime_reminder_service.dart';
import '../services/sunset_service.dart';
import '../services/log_service.dart';
import '../services/storage_service.dart';
import 'app_state.dart';

final appStateProvider = AsyncNotifierProvider<AppStateNotifier, AppState>(
  AppStateNotifier.new,
);

final bedtimeReminderServiceProvider = Provider<BedtimeReminderService>((ref) {
  return BedtimeReminderService();
});

class AppStateNotifier extends AsyncNotifier<AppState> {
  late final StorageService _storage = ref.read(storageServiceProvider);
  late final OverlayService _overlayService = ref.read(overlayServiceProvider);
  late final PremiumService _premiumService = ref.read(premiumServiceProvider);
  late final AdsService _adsService = ref.read(adsServiceProvider);
  late final BedtimeReminderService _bedtimeReminderService =
      ref.read(bedtimeReminderServiceProvider);
  late final SunsetService _sunsetService = ref.read(sunsetServiceProvider);
  late final LogService _logService = ref.read(logServiceProvider);
  Timer? _scheduleTimer;
  Timer? _refreshTimer;
  Timer? _snoozeTimer;
  Timer? _screenOffTimer;
  Timer? _bedtimeModeTimer;
  DateTime? _lastOverlayWatchdogAt;
  bool _overlayWatchdogRunning = false;
  StreamSubscription<bool>? _premiumStatusSubscription;
  StreamSubscription<bool>? _overlayStatusSubscription;
  StreamSubscription<void>? _toggleRequestSubscription;
  ScheduleEvent? _pendingScheduleEvent;
  static const int _maxSleepJournalEntries = 60;
  static const String _customPresetPrefix = 'custom_';
  static const Duration _overlayWatchdogInterval = Duration(minutes: 5);

  @override
  Future<AppState> build() async {
    await _overlayService.initialize();
    await _premiumService.initialize();
    await _adsService.initialize();
    await _logService.initialize();
    _premiumStatusSubscription ??=
        _premiumService.statusStream.listen(_handlePremiumStatus);
    final stored = await _storage.loadState();
    final premiumOverride = _premiumService.isPremium;
    var baseState = (stored ?? AppState.initial()).copyWith(
      isPremium: premiumOverride,
    );
    final flashlightStatus = await _overlayService.getFlashlightStatus();
    if (flashlightStatus != null) {
      baseState = baseState.copyWith(flashlightEnabled: flashlightStatus);
      if (stored != null && flashlightStatus != stored.flashlightEnabled) {
        await _persist(baseState);
      }
    }
    final refreshedChecklist =
        _ensureWindDownChecklistFresh(baseState, DateTime.now());
    if (!identical(refreshedChecklist, baseState)) {
      baseState = refreshedChecklist;
      await _persist(baseState);
    }
    ref.onDispose(() {
      _scheduleTimer?.cancel();
      _refreshTimer?.cancel();
      _snoozeTimer?.cancel();
      _screenOffTimer?.cancel();
      _bedtimeModeTimer?.cancel();
      _premiumStatusSubscription?.cancel();
      _premiumService.dispose();
      _logService.dispose();
      _overlayStatusSubscription?.cancel();
      _toggleRequestSubscription?.cancel();
    });
    _startOverlayStatusListener();
    _startToggleRequestListener();
    if (baseState.bedtimeReminderEnabled) {
      await _syncBedtimeReminder(baseState);
    }
    if (baseState.sleepCheckInEnabled) {
      await _syncCheckInReminder(baseState);
    }
    baseState = await _reconcileOverlayState(baseState);
    baseState = await _refreshSunsetTime(baseState);
    await _syncOverlay(baseState);
    _armScheduleTimer(baseState);
    _armSnoozeTimer(baseState);
    _armScreenOffTimer(baseState);
    _armBedtimeModeAutoOff(baseState);
    _startRefreshTimer();
    return baseState;
  }

  Future<void> setOnboardingComplete() async {
    await _update((state) => state.copyWith(onboardingComplete: true));
  }

  Future<bool> selectPreset(String id) async {
    final current = state.value;
    if (current == null) return false;
    final presetIndex = current.presets.indexWhere((p) => p.id == id);
    if (presetIndex == -1) return false;
    final preset = current.presets[presetIndex];
    if (preset.isPremium && !current.isPremium) {
      return false;
    }
    final updated = current.copyWith(activePresetId: id);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
    return true;
  }

  Future<void> updateActivePreset({
    double? temperature,
    double? opacity,
    double? brightness,
  }) async {
    final current = state.value;
    if (current == null) return;
    final active = current.activePreset;
    final nextTemperature = temperature ?? active.temperature;
    final nextOpacity = opacity ?? active.opacity;
    final nextBrightness = brightness ?? active.brightness;
    if (!active.isCustom) {
      final name = _nextCustomPresetName(current.presets);
      final customPreset = FilterPreset(
        id: _makeCustomPresetId(),
        name: name,
        temperature: nextTemperature,
        opacity: nextOpacity,
        brightness: nextBrightness,
        isCustom: true,
      );
      final updated = current.copyWith(
        presets: [...current.presets, customPreset],
        activePresetId: customPreset.id,
      );
      state = AsyncData(updated);
      await _persist(updated);
      await _syncOverlay(updated);
      return;
    }
    final updatedPresets = current.presets.map((preset) {
      if (preset.id != active.id) return preset;
      return preset.copyWith(
        temperature: nextTemperature,
        opacity: nextOpacity,
        brightness: nextBrightness,
      );
    }).toList();
    final updated = current.copyWith(
      presets: updatedPresets,
      activePresetId: active.id,
    );
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
  }

  Future<bool> toggleOverlay(bool enabled) async {
    final current = state.value;
    if (current == null) return false;
    return _requestFilterEnabled(
      enabled,
      clearSnooze: true,
    );
  }

  Future<void> updateSchedule(ScheduleConfig schedule) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(schedule: schedule, snoozeUntil: null);
    state = AsyncData(updated);
    await _persist(updated);
    if (updated.bedtimeReminderEnabled) {
      await _syncBedtimeReminder(updated);
    }
    await _syncOverlay(updated);
    _armScheduleTimer(updated);
  }

  Future<void> setPremium(bool isPremium) async {
    final current = state.value;
    if (current == null) return;
    await _premiumService.setPremium(isPremium);
    final updated = current.copyWith(isPremium: isPremium);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> toggleNotificationShortcut(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(notificationShortcutEnabled: enabled);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
  }

  Future<void> toggleBedtimeReminder(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(bedtimeReminderEnabled: enabled);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncBedtimeReminder(updated);
  }

  Future<void> toggleSleepCheckInReminder(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(sleepCheckInEnabled: enabled);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncCheckInReminder(updated);
  }

  Future<void> setSleepCheckInTime(TimeOfDay time) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(sleepCheckInTime: time);
    state = AsyncData(updated);
    await _persist(updated);
    if (updated.sleepCheckInEnabled) {
      await _syncCheckInReminder(updated);
    }
  }

  Future<void> setBedtimeReminderLeadMinutes(int minutes) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(bedtimeReminderMinutes: minutes);
    state = AsyncData(updated);
    await _persist(updated);
    if (updated.bedtimeReminderEnabled) {
      await _syncBedtimeReminder(updated);
    }
  }

  Future<void> setSleepGoalMinutes(int minutes) async {
    final current = state.value;
    if (current == null) return;
    final clamped = minutes.clamp(240, 720) as int;
    final updated = current.copyWith(sleepGoalMinutes: clamped);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setScreenOffGoalMinutes(int minutes) async {
    final current = state.value;
    if (current == null) return;
    final clamped = minutes.clamp(15, 180) as int;
    final updated = current.copyWith(screenOffGoalMinutes: clamped);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setCaffeineCutoffHours(int hours) async {
    final current = state.value;
    if (current == null) return;
    final clamped = hours.clamp(2, 12) as int;
    final updated = current.copyWith(caffeineCutoffHours: clamped);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setBlueLightGoalMinutes(int minutes) async {
    final current = state.value;
    if (current == null) return;
    final clamped = minutes.clamp(30, 240) as int;
    final updated = current.copyWith(blueLightGoalMinutes: clamped);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> setBedtimeModePresetId(String? presetId) async {
    await _update((state) => state.copyWith(bedtimeModePresetId: presetId));
  }

  Future<void> toggleBedtimeModeStartScreenOff(bool enabled) async {
    await _update(
      (state) => state.copyWith(bedtimeModeStartScreenOff: enabled),
    );
  }

  Future<void> setBedtimeModeAutoOffMinutes(int minutes) async {
    final current = state.value;
    if (current == null) return;
    final clamped = minutes.clamp(0, 180) as int;
    final updated = current.copyWith(
      bedtimeModeAutoOffMinutes: clamped,
      bedtimeModeAutoOffUntil: clamped == 0 ? null : current.bedtimeModeAutoOffUntil,
    );
    state = AsyncData(updated);
    await _persist(updated);
    _armBedtimeModeAutoOff(updated);
  }

  Future<void> toggleSunsetSync(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(sunsetSyncEnabled: enabled);
    state = AsyncData(updated);
    await _persist(updated);
    if (enabled) {
      final refreshed = await _refreshSunsetTime(updated);
      if (!identical(refreshed, updated)) {
        state = AsyncData(refreshed);
      }
    }
  }

  Future<void> toggleScreenOffNotifications(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final updated =
        current.copyWith(screenOffNotificationsEnabled: enabled);
    state = AsyncData(updated);
    await _persist(updated);
    if (!enabled) {
      await _bedtimeReminderService.cancelScreenOffNotifications();
    } else if (updated.screenOffUntil != null) {
      await _bedtimeReminderService
          .scheduleScreenOffNotifications(updated.screenOffUntil!);
    }
  }

  Future<void> toggleHighContrast(bool enabled) async {
    await _update((state) => state.copyWith(highContrastEnabled: enabled));
  }

  Future<void> addWindDownItem(String label) async {
    final current = state.value;
    if (current == null) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final updated = current.copyWith(
      windDownItems: [...current.windDownItems, WindDownItem(id: id, label: trimmed)],
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> addCustomPreset({
    required String name,
    required FilterPreset basePreset,
  }) async {
    final current = state.value;
    if (current == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final preset = FilterPreset(
      id: _makeCustomPresetId(),
      name: trimmed,
      temperature: basePreset.temperature,
      opacity: basePreset.opacity,
      brightness: basePreset.brightness,
      isCustom: true,
    );
    final updated = current.copyWith(
      presets: [...current.presets, preset],
      activePresetId: preset.id,
    );
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
  }

  Future<void> renameCustomPreset(String id, String name) async {
    final current = state.value;
    if (current == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final updatedPresets = current.presets.map((preset) {
      if (preset.id != id || !preset.isCustom) return preset;
      return preset.copyWith(name: trimmed);
    }).toList();
    final updated = current.copyWith(presets: updatedPresets);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> deleteCustomPreset(String id) async {
    final current = state.value;
    if (current == null) return;
    final preset = current.presets.firstWhere(
      (item) => item.id == id,
      orElse: () => current.activePreset,
    );
    if (!preset.isCustom) return;
    final remaining = current.presets.where((item) => item.id != id).toList();
    final fallback = remaining.firstWhere(
      (item) => !item.isPremium,
      orElse: () => remaining.isNotEmpty ? remaining.first : current.activePreset,
    );
    var updated = current.copyWith(
      presets: remaining,
      activePresetId: current.activePresetId == id ? fallback.id : current.activePresetId,
    );
    if (updated.bedtimeModePresetId == id) {
      updated = updated.copyWith(bedtimeModePresetId: null);
    }
    if (updated.schedule.targetPresetId == id) {
      updated = updated.copyWith(
        schedule: updated.schedule.copyWith(targetPresetId: null),
      );
    }
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
  }

  Future<void> removeWindDownItem(String id) async {
    final current = state.value;
    if (current == null) return;
    final updatedItems =
        current.windDownItems.where((item) => item.id != id).toList();
    final updatedChecklist = Map<String, bool>.from(current.windDownChecklist);
    updatedChecklist.remove(id);
    final updated = current.copyWith(
      windDownItems: updatedItems,
      windDownChecklist: updatedChecklist,
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> reorderWindDownItems(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;
    final items = [...current.windDownItems];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex >= items.length) {
      return;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    final updated = current.copyWith(windDownItems: items);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> toggleWindDownChecklistItem(String id, bool completed) async {
    final current = state.value;
    if (current == null) return;
    final refreshed = _ensureWindDownChecklistFresh(current, DateTime.now());
    final updatedChecklist = Map<String, bool>.from(
      refreshed.windDownChecklist,
    );
    if (completed) {
      updatedChecklist[id] = true;
    } else {
      updatedChecklist.remove(id);
    }
    final updated = refreshed.copyWith(
      windDownChecklist: updatedChecklist,
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> resetWindDownChecklist() async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(
      windDownChecklistDate: _todayDate(DateTime.now()),
      windDownChecklist: const {},
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> syncNow() async {
    final current = state.value;
    if (current == null) return;
    final reconciled = await _reconcileOverlayState(current);
    if (!identical(reconciled, current)) {
      state = AsyncData(reconciled);
      _armScheduleTimer(reconciled);
    }
    await _syncOverlay(reconciled);
    await _refreshFlashlightState(reconciled);
  }

  Future<bool> toggleFlashlight(bool enabled) async {
    final current = state.value;
    if (current == null) return false;
    final hasFlash = await _overlayService.hasFlashlight();
    if (hasFlash != true) return false;

    if (enabled) {
      final hasPermission = await _overlayService.hasFlashlightPermission();
      if (!hasPermission) {
        final granted = await _overlayService.requestFlashlightPermission();
        if (!granted) return false;
      }
    }

    final ok = await _overlayService.setFlashlight(enabled);
    if (!ok) return false;

    final updated = current.copyWith(flashlightEnabled: enabled);
    state = AsyncData(updated);
    await _persist(updated);
    return true;
  }

  Future<void> toggleStartOnBootReminder(bool enabled) async {
    await _update((state) => state.copyWith(startOnBootReminder: enabled));
  }

  Future<void> snoozeFor(Duration duration) async {
    final current = state.value;
    if (current == null) return;
    final until = DateTime.now().add(duration);
    final updated = current.copyWith(snoozeUntil: until);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
    _armSnoozeTimer(updated);
  }

  Future<bool> snoozeUntilNextChange() async {
    final current = state.value;
    if (current == null) return false;
    final now = DateTime.now();
    final next = current.nextScheduleChange(now);
    if (next == null) return false;
    if (!next.isAfter(now)) return false;
    final updated = current.copyWith(snoozeUntil: next);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
    _armSnoozeTimer(updated);
    return true;
  }

  Future<void> clearSnooze() async {
    final current = state.value;
    if (current == null) return;
    if (current.snoozeUntil == null) return;
    final updated = current.copyWith(snoozeUntil: null);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
    _armSnoozeTimer(updated);
    _armScheduleTimer(updated);
  }

  Future<void> startScreenOffGoal(Duration duration) async {
    final current = state.value;
    if (current == null) return;
    final until = DateTime.now().add(duration);
    final updated = current.copyWith(screenOffUntil: until);
    state = AsyncData(updated);
    await _persist(updated);
    _armScreenOffTimer(updated);
    if (updated.screenOffNotificationsEnabled) {
      await _bedtimeReminderService.scheduleScreenOffNotifications(until);
    }
  }

  Future<void> startBedtimeModeAutoOff(Duration duration) async {
    final current = state.value;
    if (current == null) return;
    final until = DateTime.now().add(duration);
    final updated = current.copyWith(bedtimeModeAutoOffUntil: until);
    state = AsyncData(updated);
    await _persist(updated);
    _armBedtimeModeAutoOff(updated);
  }

  Future<void> endScreenOffGoal() async {
    final current = state.value;
    if (current == null || current.screenOffUntil == null) return;
    final updated = current.copyWith(screenOffUntil: null);
    state = AsyncData(updated);
    await _persist(updated);
    _armScreenOffTimer(updated);
    await _bedtimeReminderService.cancelScreenOffNotifications();
  }

  Future<void> startSleepJournal() async {
    final current = state.value;
    if (current == null || current.sleepJournalActiveStart != null) return;
    final updated = current.copyWith(sleepJournalActiveStart: DateTime.now());
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> endSleepJournal({
    required int quality,
    String notes = '',
  }) async {
    final current = state.value;
    final startedAt = current?.sleepJournalActiveStart;
    if (current == null || startedAt == null) return;
    final endedAt = DateTime.now();
    final entry = SleepJournalEntry(
      startedAt: startedAt,
      endedAt: endedAt,
      quality: quality.clamp(1, 5),
      notes: notes.trim(),
    );
    final entries = [
      entry,
      ...current.sleepJournalEntries,
    ].take(_maxSleepJournalEntries).toList();
    final updated = current.copyWith(
      sleepJournalActiveStart: null,
      sleepJournalEntries: entries,
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> addSleepJournalEntry(SleepJournalEntry entry) async {
    final current = state.value;
    if (current == null || current.sleepJournalActiveStart != null) return;
    final entries = [
      entry,
      ...current.sleepJournalEntries,
    ].take(_maxSleepJournalEntries).toList();
    final updated = current.copyWith(sleepJournalEntries: entries);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> clearSleepJournal() async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(
      sleepJournalEntries: const [],
      sleepJournalActiveStart: null,
    );
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> _update(AppState Function(AppState) reducer) async {
    final current = state.value;
    if (current == null) return;
    final updated = reducer(current);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> _persist(AppState updated) async {
    await _storage.saveState(updated);
  }

  Future<bool> _requestFilterEnabled(
    bool enabled, {
    required bool clearSnooze,
    bool rearmSchedule = true,
  }) async {
    final current = state.value;
    if (current == null) return false;
    final updated = current.copyWith(
      filterEnabled: enabled,
      snoozeUntil: clearSnooze ? null : current.snoozeUntil,
    );
    final nativeEnabled = await _syncOverlay(updated);
    if (nativeEnabled == null || nativeEnabled != enabled) {
      return false;
    }
    state = AsyncData(updated);
    await _persist(updated);
    if (rearmSchedule) {
      _armScheduleTimer(updated);
    }
    return true;
  }

  Future<void> _syncBedtimeReminder(AppState state) async {
    await _bedtimeReminderService.updateReminders(
      schedule: state.schedule,
      enabled: state.bedtimeReminderEnabled,
      leadMinutes: state.bedtimeReminderMinutes,
    );
  }

  Future<void> _syncCheckInReminder(AppState state) async {
    await _bedtimeReminderService.updateCheckInReminder(
      enabled: state.sleepCheckInEnabled,
      time: state.sleepCheckInTime,
    );
  }

  void _startRefreshTimer() {
    _refreshTimer ??= Timer.periodic(const Duration(minutes: 1), (_) async {
      final current = state.value;
      if (current == null) return;
      await _refreshWindDownChecklist(current);
      await _refreshFlashlightState(current);
      if (_shouldRunOverlayWatchdog(DateTime.now())) {
        await _runOverlayWatchdog(current);
      }
      if (current.sunsetSyncEnabled) {
        final refreshed = await _refreshSunsetTime(current);
        if (!identical(refreshed, current)) {
          state = AsyncData(refreshed);
          await _persist(refreshed);
        }
      }
    });
  }

  void _startOverlayStatusListener() {
    _overlayStatusSubscription ??=
        _overlayService.overlayStatusStream.listen((enabled) async {
      final current = state.value;
      if (current == null || current.filterEnabled == enabled) return;
      final now = DateTime.now();
      if (current.isSnoozed(now)) {
        return;
      }
      final updated = current.copyWith(filterEnabled: enabled);
      state = AsyncData(updated);
      await _persist(updated);
      _armScheduleTimer(updated);
    });
  }

  void _startToggleRequestListener() {
    _toggleRequestSubscription ??=
        _overlayService.toggleRequests.listen((_) async {
      final current = state.value;
      if (current == null) return;
      await toggleOverlay(!current.filterEnabled);
    });
  }

  void _armScheduleTimer(AppState state) {
    _scheduleTimer?.cancel();
    _pendingScheduleEvent = null;
    final nextEvent = state.nextScheduleEvent(DateTime.now());
    if (nextEvent == null) return;
    _pendingScheduleEvent = nextEvent;
    final delay = nextEvent.time.difference(DateTime.now());
    _scheduleTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _handleScheduleEvent,
    );
  }

  Future<void> _handleScheduleEvent() async {
    final current = state.value;
    final pending = _pendingScheduleEvent;
    if (current == null || pending == null) return;
    if (current.isSnoozed(DateTime.now())) {
      _armScheduleTimer(current);
      return;
    }
    if (pending.enable && !current.filterEnabled) {
      await _requestFilterEnabled(
        true,
        clearSnooze: false,
        rearmSchedule: false,
      );
    } else if (!pending.enable && current.filterEnabled) {
      await _requestFilterEnabled(
        false,
        clearSnooze: false,
        rearmSchedule: false,
      );
    }
    _armScheduleTimer(state.value ?? current);
  }

  void _armSnoozeTimer(AppState state) {
    _snoozeTimer?.cancel();
    final until = state.snoozeUntil;
    if (until == null) return;
    final delay = until.difference(DateTime.now());
    if (delay.isNegative) {
      _clearExpiredSnooze();
      return;
    }
    _snoozeTimer = Timer(delay, _clearExpiredSnooze);
  }

  void _armScreenOffTimer(AppState state) {
    _screenOffTimer?.cancel();
    final until = state.screenOffUntil;
    if (until == null) return;
    final delay = until.difference(DateTime.now());
    if (delay.isNegative) {
      _clearExpiredScreenOffGoal();
      return;
    }
    _screenOffTimer = Timer(delay, _clearExpiredScreenOffGoal);
  }

  void _armBedtimeModeAutoOff(AppState state) {
    _bedtimeModeTimer?.cancel();
    final until = state.bedtimeModeAutoOffUntil;
    if (until == null) return;
    final delay = until.difference(DateTime.now());
    if (delay.isNegative) {
      _clearExpiredBedtimeModeAutoOff();
      return;
    }
    _bedtimeModeTimer = Timer(delay, _clearExpiredBedtimeModeAutoOff);
  }

  Future<void> _clearExpiredSnooze() async {
    final current = state.value;
    if (current == null || current.snoozeUntil == null) return;
    final updated = current.copyWith(snoozeUntil: null);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
    _armScheduleTimer(updated);
  }

  Future<void> _clearExpiredScreenOffGoal() async {
    final current = state.value;
    if (current == null || current.screenOffUntil == null) return;
    final updated = current.copyWith(screenOffUntil: null);
    state = AsyncData(updated);
    await _persist(updated);
    _armScreenOffTimer(updated);
  }

  Future<void> _clearExpiredBedtimeModeAutoOff() async {
    final current = state.value;
    if (current == null || current.bedtimeModeAutoOffUntil == null) return;
    await _requestFilterEnabled(
      false,
      clearSnooze: false,
    );
    final updated = (state.value ?? current)
        .copyWith(bedtimeModeAutoOffUntil: null);
    state = AsyncData(updated);
    await _persist(updated);
    _armBedtimeModeAutoOff(updated);
  }

  Future<bool?> _syncOverlay(AppState state) async {
    final now = DateTime.now();
    final shouldEnable = state.filterEnabled && !state.isSnoozed(now);
    final showNotification = state.notificationShortcutEnabled;
    bool? nativeEnabled;
    try {
      nativeEnabled = await _attemptOverlaySync(
        shouldEnable: shouldEnable,
        preset: state.effectivePreset(now),
        showNotification: showNotification,
      );
    } catch (_) {
      await _logService.logEvent(
        type: 'overlay_error',
        message: 'Overlay sync threw an exception.',
        details: {'shouldEnable': shouldEnable},
      );
      return null;
    }
    if (nativeEnabled != null && nativeEnabled != shouldEnable) {
      await _logService.logEvent(
        type: 'overlay_mismatch',
        message: 'Overlay status mismatch after sync.',
        details: {
          'expected': shouldEnable,
          'actual': nativeEnabled,
        },
      );
    }
    return nativeEnabled;
  }

  Future<bool?> _attemptOverlaySync({
    required bool shouldEnable,
    required FilterPreset preset,
    required bool showNotification,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (shouldEnable) {
        await _overlayService.startOverlay(
          preset: preset,
          showNotification: showNotification,
        );
      } else {
        await _overlayService.stopOverlay(showNotification: showNotification);
      }
      final status = await _overlayService.isOverlayEnabled();
      if (status == shouldEnable || attempt == 1) {
        return status;
      }
      await _logService.logEvent(
        type: 'overlay_retry',
        message: 'Retrying overlay sync.',
        details: {'attempt': attempt + 1, 'shouldEnable': shouldEnable},
      );
    }
    return null;
  }

  Future<AppState> _reconcileOverlayState(AppState current) async {
    final nativeEnabled = await _overlayService.isOverlayEnabled();
    if (nativeEnabled == null) return current;
    final now = DateTime.now();
    if (current.isSnoozed(now)) return current;
    if (nativeEnabled && !current.filterEnabled) {
      final updated = current.copyWith(filterEnabled: true);
      await _persist(updated);
      return updated;
    }
    return current;
  }

  Future<AppState> _refreshSunsetTime(AppState current) async {
    if (!current.sunsetSyncEnabled) return current;
    final now = DateTime.now();
    if (current.sunsetUpdatedAt != null &&
        _isSameDay(current.sunsetUpdatedAt!, now) &&
        current.sunsetTime != null) {
      return current;
    }
    final result = await _sunsetService.fetchSunsetTime(now);
    if (result == null) return current;
    final updated = current.copyWith(
      sunsetTime: result,
      sunsetUpdatedAt: now,
    );
    await _persist(updated);
    return updated;
  }

  Future<void> _refreshFlashlightState(AppState current) async {
    final flashlightStatus = await _overlayService.getFlashlightStatus();
    if (flashlightStatus == null ||
        flashlightStatus == current.flashlightEnabled) {
      return;
    }
    final updated = current.copyWith(flashlightEnabled: flashlightStatus);
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> _refreshWindDownChecklist(AppState current) async {
    final refreshed = _ensureWindDownChecklistFresh(current, DateTime.now());
    if (identical(refreshed, current)) return;
    state = AsyncData(refreshed);
    await _persist(refreshed);
  }

  AppState _ensureWindDownChecklistFresh(AppState state, DateTime now) {
    if (state.windDownChecklistDate != null &&
        _isSameDay(state.windDownChecklistDate!, now)) {
      return state;
    }
    return state.copyWith(
      windDownChecklistDate: _todayDate(now),
      windDownChecklist: const {},
    );
  }

  DateTime _todayDate(DateTime now) => DateTime(now.year, now.month, now.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handlePremiumStatus(bool isPremium) async {
    final current = state.value;
    if (current == null || current.isPremium == isPremium) return;
    var updated = current.copyWith(isPremium: isPremium);
    if (!isPremium) {
      final fallbackPreset = current.presets.firstWhere(
        (preset) => !preset.isPremium,
        orElse: () => current.presets.first,
      );
      if (current.activePreset.isPremium) {
        updated = updated.copyWith(activePresetId: fallbackPreset.id);
      }
      final bedtimePresetId = updated.bedtimeModePresetId;
      if (bedtimePresetId != null) {
        final bedtimePreset = current.presets.firstWhere(
          (preset) => preset.id == bedtimePresetId,
          orElse: () => fallbackPreset,
        );
        if (bedtimePreset.isPremium) {
          updated = updated.copyWith(bedtimeModePresetId: null);
        }
      }
      final targetPresetId = updated.schedule.targetPresetId;
      var schedule = updated.schedule;
      var scheduleChanged = false;
      if (targetPresetId != null) {
        final targetPreset = current.presets.firstWhere(
          (preset) => preset.id == targetPresetId,
          orElse: () => fallbackPreset,
        );
        if (targetPreset.isPremium) {
          schedule = schedule.copyWith(targetPresetId: null);
          scheduleChanged = true;
        }
      }
      if (schedule.weekendDifferent) {
        schedule = schedule.copyWith(
          weekendDifferent: false,
          weekendStartTime: null,
          weekendEndTime: null,
        );
        scheduleChanged = true;
      }
      if (scheduleChanged) {
        updated = updated.copyWith(schedule: schedule);
      }
    }
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
  }

  String _makeCustomPresetId() {
    return '$_customPresetPrefix${DateTime.now().millisecondsSinceEpoch}';
  }

  String _nextCustomPresetName(List<FilterPreset> presets) {
    final count = presets.where((preset) => preset.isCustom).length + 1;
    return 'Custom $count';
  }

  bool _shouldRunOverlayWatchdog(DateTime now) {
    final last = _lastOverlayWatchdogAt;
    if (last == null || now.difference(last) >= _overlayWatchdogInterval) {
      _lastOverlayWatchdogAt = now;
      return true;
    }
    return false;
  }

  Future<void> _runOverlayWatchdog(AppState current) async {
    if (_overlayWatchdogRunning) return;
    _overlayWatchdogRunning = true;
    try {
      final now = DateTime.now();
      final shouldEnable = current.filterEnabled && !current.isSnoozed(now);
      final hasPermission = await _overlayService.hasPermission();
      if (!hasPermission && shouldEnable) {
        await _logService.logEvent(
          type: 'overlay_watchdog_permission_missing',
          message: 'Overlay permission missing while filter enabled.',
        );
        return;
      }
      final nativeEnabled = await _overlayService.isOverlayEnabled();
      if (nativeEnabled == null) return;
      if (nativeEnabled != shouldEnable) {
        await _logService.logEvent(
          type: 'overlay_watchdog_mismatch',
          message: 'Overlay status mismatch during watchdog check.',
          details: {
            'expected': shouldEnable,
            'actual': nativeEnabled,
          },
        );
        await _syncOverlay(current);
      }
    } finally {
      _overlayWatchdogRunning = false;
    }
  }
}
