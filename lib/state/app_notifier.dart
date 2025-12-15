import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/filter_models.dart';
import '../services/overlay_service.dart';
import '../services/premium_service.dart';
import '../services/ads_service.dart';
import '../services/storage_service.dart';
import 'app_state.dart';

final appStateProvider = AsyncNotifierProvider<AppStateNotifier, AppState>(
  AppStateNotifier.new,
);

class AppStateNotifier extends AsyncNotifier<AppState> {
  late final StorageService _storage = ref.read(storageServiceProvider);
  late final OverlayService _overlayService = ref.read(overlayServiceProvider);
  late final PremiumService _premiumService = ref.read(premiumServiceProvider);
  late final AdsService _adsService = ref.read(adsServiceProvider);
  Timer? _scheduleTimer;

  @override
  Future<AppState> build() async {
    await _overlayService.initialize();
    await _premiumService.initialize();
    await _adsService.initialize();
    final stored = await _storage.loadState();
    final premiumOverride = _premiumService.isPremium;
    var baseState = (stored ?? AppState.initial()).copyWith(
      isPremium: premiumOverride,
    );
    // Ensure we start with the overlay enabled by default.
    if (!baseState.overlayEnabled) {
      baseState = baseState.copyWith(overlayEnabled: true);
      await _persist(baseState);
    }
    ref.onDispose(() {
      _scheduleTimer?.cancel();
    });
    await _syncOverlay(baseState);
    _startScheduleTimer();
    return baseState;
  }

  Future<void> setOnboardingComplete() async {
    await _update((state) => state.copyWith(onboardingComplete: true));
  }

  Future<bool> selectPreset(String id) async {
    final current = state.value;
    if (current == null) return false;
    final preset = current.presets.firstWhere((p) => p.id == id);
    if (preset.isPremium && !current.isPremium) {
      return false;
    }
    final updated = current.copyWith(activePresetId: id);
    state = AsyncData(updated);
    await _persist(updated);
    await _overlayService.updateOverlay(
      preset: preset,
      enabled: updated.isFilterActive(DateTime.now()),
      showNotification: updated.notificationShortcutEnabled,
    );
    return true;
  }

  Future<void> updateActivePreset({
    double? temperature,
    double? opacity,
    double? brightness,
  }) async {
    final current = state.value;
    if (current == null) return;
    final updatedPresets = current.presets.map((preset) {
      if (preset.id != current.activePresetId) return preset;
      return preset.copyWith(
        temperature: temperature ?? preset.temperature,
        opacity: opacity ?? preset.opacity,
        brightness: brightness ?? preset.brightness,
      );
    }).toList();
    final updated = current.copyWith(presets: updatedPresets);
    state = AsyncData(updated);
    await _persist(updated);
    await _overlayService.updateOverlay(
      preset: updated.activePreset,
      enabled: updated.isFilterActive(DateTime.now()),
      showNotification: updated.notificationShortcutEnabled,
    );
  }

  Future<bool> toggleOverlay(bool enabled) async {
    final current = state.value;
    if (current == null) return false;

    if (enabled) {
      final hasPermission = await _overlayService.hasPermission();
      if (!hasPermission) {
        return false;
      }
    }

    final updated = current.copyWith(overlayEnabled: enabled);
    state = AsyncData(updated);
    await _persist(updated);
    await _syncOverlay(updated);
    return true;
  }

  Future<void> updateSchedule(ScheduleConfig schedule) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.copyWith(schedule: schedule);
    state = AsyncData(updated);
    await _persist(updated);
    if (updated.isFilterActive(DateTime.now())) {
      await _overlayService.startOverlay(
        preset: updated.activePreset,
        showNotification: updated.notificationShortcutEnabled,
      );
    } else {
      await _overlayService.stopOverlay(
        showNotification: updated.notificationShortcutEnabled,
      );
    }
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

  Future<void> toggleStartOnBootReminder(bool enabled) async {
    await _update((state) => state.copyWith(startOnBootReminder: enabled));
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

  void _startScheduleTimer() {
    _scheduleTimer ??= Timer.periodic(const Duration(minutes: 1), (_) async {
      final current = state.value;
      if (current == null) return;
      await _syncOverlay(current);
    });
  }

  Future<void> _syncOverlay(AppState state) async {
    var currentState = state;
    final nativeEnabled = await _overlayService.isOverlayEnabled();
    if (nativeEnabled == false && currentState.overlayEnabled) {
      final updatedState = currentState.copyWith(overlayEnabled: false);
      this.state = AsyncData(updatedState);
      await _persist(updatedState);
      currentState = updatedState;
    }

    final active = currentState.isFilterActive(DateTime.now());
    final showNotification = currentState.notificationShortcutEnabled;
    if (active) {
      await _overlayService.startOverlay(
        preset: currentState.activePreset,
        showNotification: showNotification,
      );
    } else {
      await _overlayService.stopOverlay(showNotification: showNotification);
    }
  }
}
