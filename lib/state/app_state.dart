import 'package:flutter/material.dart';

import '../models/filter_models.dart';

class AppState {
  const AppState({
    required this.presets,
    required this.activePresetId,
    required this.schedule,
    required this.isPremium,
    required this.overlayEnabled,
    required this.onboardingComplete,
    required this.notificationShortcutEnabled,
    required this.startOnBootReminder,
  });

  final List<FilterPreset> presets;
  final String activePresetId;
  final ScheduleConfig schedule;
  final bool isPremium;
  final bool overlayEnabled;
  final bool onboardingComplete;
  final bool notificationShortcutEnabled;
  final bool startOnBootReminder;

  FilterPreset get activePreset => presets.firstWhere(
    (p) => p.id == activePresetId,
    orElse: () => presets.first,
  );

  AppState copyWith({
    List<FilterPreset>? presets,
    String? activePresetId,
    ScheduleConfig? schedule,
    bool? isPremium,
    bool? overlayEnabled,
    bool? onboardingComplete,
    bool? notificationShortcutEnabled,
    bool? startOnBootReminder,
  }) {
    return AppState(
      presets: presets ?? this.presets,
      activePresetId: activePresetId ?? this.activePresetId,
      schedule: schedule ?? this.schedule,
      isPremium: isPremium ?? this.isPremium,
      overlayEnabled: overlayEnabled ?? this.overlayEnabled,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      notificationShortcutEnabled:
          notificationShortcutEnabled ?? this.notificationShortcutEnabled,
      startOnBootReminder: startOnBootReminder ?? this.startOnBootReminder,
    );
  }

  bool isFilterActive(DateTime now) {
    // Manual toggle is the single source of truth for activation.
    return overlayEnabled;
  }

  Map<String, dynamic> toJson() {
    return {
      'presets': presets.map((p) => p.toJson()).toList(),
      'activePresetId': activePresetId,
      'schedule': schedule.toJson(),
      'isPremium': isPremium,
      'overlayEnabled': overlayEnabled,
      'onboardingComplete': onboardingComplete,
      'notificationShortcutEnabled': notificationShortcutEnabled,
      'startOnBootReminder': startOnBootReminder,
    };
  }

  factory AppState.fromJson(Map<String, dynamic> json) {
    final presetList = (json['presets'] as List<dynamic>)
        .map((item) => FilterPreset.fromJson(item as Map<String, dynamic>))
        .toList();
    return AppState(
      presets: presetList,
      activePresetId: json['activePresetId'] as String? ?? presetList.first.id,
      schedule: ScheduleConfig.fromJson(
        json['schedule'] as Map<String, dynamic>,
      ),
      isPremium: json['isPremium'] as bool? ?? false,
      overlayEnabled: json['overlayEnabled'] as bool? ?? false,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      notificationShortcutEnabled:
          json['notificationShortcutEnabled'] as bool? ?? false,
      startOnBootReminder: json['startOnBootReminder'] as bool? ?? false,
    );
  }

  static AppState initial() {
    const presets = [
      FilterPreset(
        id: 'soft',
        name: 'Soft Warm',
        temperature: 25,
        opacity: 28,
        brightness: 96,
      ),
      FilterPreset(
        id: 'medium',
        name: 'Medium Warm',
        temperature: 50,
        opacity: 42,
        brightness: 92,
      ),
      FilterPreset(
        id: 'strong',
        name: 'Strong Warm',
        temperature: 65,
        opacity: 58,
        brightness: 88,
      ),
      FilterPreset(
        id: 'ultra',
        name: 'Ultra Warm',
        temperature: 82,
        opacity: 68,
        brightness: 82,
        isPremium: true,
      ),
      FilterPreset(
        id: 'reading',
        name: 'Reading Mode',
        temperature: 72,
        opacity: 50,
        brightness: 78,
        isPremium: true,
      ),
      FilterPreset(
        id: 'custom',
        name: 'Custom',
        temperature: 60,
        opacity: 48,
        brightness: 86,
        isCustom: true,
      ),
    ];

    return AppState(
      presets: presets,
      activePresetId: 'soft',
      schedule: ScheduleConfig(
        mode: FilterMode.alwaysOn,
        startTime: const TimeOfDay(hour: 22, minute: 0),
        endTime: const TimeOfDay(hour: 6, minute: 0),
      ),
      isPremium: false,
      overlayEnabled: true,
      onboardingComplete: false,
      notificationShortcutEnabled: true,
      startOnBootReminder: false,
    );
  }
}
