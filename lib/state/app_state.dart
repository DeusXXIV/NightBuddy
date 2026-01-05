import 'package:flutter/material.dart';

import '../models/filter_models.dart';
import '../models/sleep_journal.dart';

class AppState {
  static const Object _unset = Object();

  const AppState({
    required this.presets,
    required this.activePresetId,
    required this.schedule,
    required this.isPremium,
    required this.filterEnabled,
    required this.flashlightEnabled,
    required this.snoozeUntil,
    required this.sleepJournalActiveStart,
    required this.sleepJournalEntries,
    required this.sleepGoalMinutes,
    required this.windDownChecklistDate,
    required this.windDownChecklist,
    required this.sleepCheckInEnabled,
    required this.sleepCheckInTime,
    required this.bedtimeReminderEnabled,
    required this.bedtimeReminderMinutes,
    required this.caffeineCutoffHours,
    required this.onboardingComplete,
    required this.notificationShortcutEnabled,
    required this.startOnBootReminder,
    required this.screenOffUntil,
    required this.blueLightGoalMinutes,
    required this.screenOffGoalMinutes,
    required this.bedtimeModePresetId,
    required this.bedtimeModeStartScreenOff,
    required this.bedtimeModeAutoOffMinutes,
    required this.bedtimeModeAutoOffUntil,
    required this.sunsetSyncEnabled,
    required this.sunsetTime,
    required this.sunsetUpdatedAt,
    required this.screenOffNotificationsEnabled,
    required this.windDownItems,
    required this.highContrastEnabled,
  });

  final List<FilterPreset> presets;
  final String activePresetId;
  final ScheduleConfig schedule;
  final bool isPremium;
  final bool filterEnabled;
  final bool flashlightEnabled;
  final DateTime? snoozeUntil;
  final DateTime? sleepJournalActiveStart;
  final List<SleepJournalEntry> sleepJournalEntries;
  final int sleepGoalMinutes;
  final DateTime? windDownChecklistDate;
  final Map<String, bool> windDownChecklist;
  final bool sleepCheckInEnabled;
  final TimeOfDay sleepCheckInTime;
  final bool bedtimeReminderEnabled;
  final int bedtimeReminderMinutes;
  final int caffeineCutoffHours;
  final bool onboardingComplete;
  final bool notificationShortcutEnabled;
  final bool startOnBootReminder;
  final DateTime? screenOffUntil;
  final int blueLightGoalMinutes;
  final int screenOffGoalMinutes;
  final String? bedtimeModePresetId;
  final bool bedtimeModeStartScreenOff;
  final int bedtimeModeAutoOffMinutes;
  final DateTime? bedtimeModeAutoOffUntil;
  final bool sunsetSyncEnabled;
  final TimeOfDay? sunsetTime;
  final DateTime? sunsetUpdatedAt;
  final bool screenOffNotificationsEnabled;
  final List<WindDownItem> windDownItems;
  final bool highContrastEnabled;

  FilterPreset get activePreset => presets.firstWhere(
    (p) => p.id == activePresetId,
    orElse: () => presets.first,
  );

  FilterPreset get scheduledPreset {
    if (schedule.mode != FilterMode.scheduled) return activePreset;
    final targetId = schedule.targetPresetId;
    if (targetId == null) return activePreset;
    final preset = presets.firstWhere(
      (p) => p.id == targetId,
      orElse: () => activePreset,
    );
    if (preset.isPremium && !isPremium) return activePreset;
    return preset;
  }

  FilterPreset effectivePreset(DateTime now) {
    if (schedule.mode != FilterMode.scheduled) return activePreset;
    final blend = _scheduleBlend(now);
    if (blend == null) return activePreset;
    if (blend >= 1) return scheduledPreset;
    return _lerpPreset(_neutralPreset, scheduledPreset, blend);
  }

  Duration get sleepGoal => Duration(minutes: sleepGoalMinutes);

  bool isWindDownChecklistCurrent(DateTime now) {
    final date = windDownChecklistDate;
    if (date == null) return false;
    return _isSameDay(date, now);
  }

  Map<String, bool> windDownChecklistFor(DateTime now) {
    if (!isWindDownChecklistCurrent(now)) return const {};
    return windDownChecklist;
  }

  AppState copyWith({
    List<FilterPreset>? presets,
    String? activePresetId,
    ScheduleConfig? schedule,
    bool? isPremium,
    bool? filterEnabled,
    bool? flashlightEnabled,
    Object? snoozeUntil = _unset,
    Object? sleepJournalActiveStart = _unset,
    List<SleepJournalEntry>? sleepJournalEntries,
    int? sleepGoalMinutes,
    Object? windDownChecklistDate = _unset,
    Map<String, bool>? windDownChecklist,
    bool? sleepCheckInEnabled,
    TimeOfDay? sleepCheckInTime,
    bool? bedtimeReminderEnabled,
    int? bedtimeReminderMinutes,
    int? caffeineCutoffHours,
    bool? onboardingComplete,
    bool? notificationShortcutEnabled,
    bool? startOnBootReminder,
    Object? screenOffUntil = _unset,
    int? blueLightGoalMinutes,
    int? screenOffGoalMinutes,
    Object? bedtimeModePresetId = _unset,
    bool? bedtimeModeStartScreenOff,
    int? bedtimeModeAutoOffMinutes,
    Object? bedtimeModeAutoOffUntil = _unset,
    bool? sunsetSyncEnabled,
    Object? sunsetTime = _unset,
    Object? sunsetUpdatedAt = _unset,
    bool? screenOffNotificationsEnabled,
    List<WindDownItem>? windDownItems,
    bool? highContrastEnabled,
  }) {
    return AppState(
      presets: presets ?? this.presets,
      activePresetId: activePresetId ?? this.activePresetId,
      schedule: schedule ?? this.schedule,
      isPremium: isPremium ?? this.isPremium,
      filterEnabled: filterEnabled ?? this.filterEnabled,
      flashlightEnabled: flashlightEnabled ?? this.flashlightEnabled,
      snoozeUntil: identical(snoozeUntil, _unset)
          ? this.snoozeUntil
          : snoozeUntil as DateTime?,
      sleepJournalActiveStart: identical(sleepJournalActiveStart, _unset)
          ? this.sleepJournalActiveStart
          : sleepJournalActiveStart as DateTime?,
      sleepJournalEntries: sleepJournalEntries ?? this.sleepJournalEntries,
      sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
      windDownChecklistDate: identical(windDownChecklistDate, _unset)
          ? this.windDownChecklistDate
          : windDownChecklistDate as DateTime?,
      windDownChecklist: windDownChecklist ?? this.windDownChecklist,
      sleepCheckInEnabled: sleepCheckInEnabled ?? this.sleepCheckInEnabled,
      sleepCheckInTime: sleepCheckInTime ?? this.sleepCheckInTime,
      bedtimeReminderEnabled:
          bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      bedtimeReminderMinutes:
          bedtimeReminderMinutes ?? this.bedtimeReminderMinutes,
      caffeineCutoffHours: caffeineCutoffHours ?? this.caffeineCutoffHours,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      notificationShortcutEnabled:
          notificationShortcutEnabled ?? this.notificationShortcutEnabled,
      startOnBootReminder: startOnBootReminder ?? this.startOnBootReminder,
      screenOffUntil: identical(screenOffUntil, _unset)
          ? this.screenOffUntil
          : screenOffUntil as DateTime?,
      blueLightGoalMinutes: blueLightGoalMinutes ?? this.blueLightGoalMinutes,
      screenOffGoalMinutes:
          screenOffGoalMinutes ?? this.screenOffGoalMinutes,
      bedtimeModePresetId: identical(bedtimeModePresetId, _unset)
          ? this.bedtimeModePresetId
          : bedtimeModePresetId as String?,
      bedtimeModeStartScreenOff:
          bedtimeModeStartScreenOff ?? this.bedtimeModeStartScreenOff,
      bedtimeModeAutoOffMinutes:
          bedtimeModeAutoOffMinutes ?? this.bedtimeModeAutoOffMinutes,
      bedtimeModeAutoOffUntil: identical(bedtimeModeAutoOffUntil, _unset)
          ? this.bedtimeModeAutoOffUntil
          : bedtimeModeAutoOffUntil as DateTime?,
      sunsetSyncEnabled: sunsetSyncEnabled ?? this.sunsetSyncEnabled,
      sunsetTime: identical(sunsetTime, _unset)
          ? this.sunsetTime
          : sunsetTime as TimeOfDay?,
      sunsetUpdatedAt: identical(sunsetUpdatedAt, _unset)
          ? this.sunsetUpdatedAt
          : sunsetUpdatedAt as DateTime?,
      screenOffNotificationsEnabled:
          screenOffNotificationsEnabled ?? this.screenOffNotificationsEnabled,
      windDownItems: windDownItems ?? this.windDownItems,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
    );
  }

  bool isFilterActive(DateTime now) {
    if (!filterEnabled) return false;
    if (isSnoozed(now)) return false;
    return true;
  }

  bool isScheduleActive(DateTime now) {
    switch (schedule.mode) {
      case FilterMode.off:
        return false;
      case FilterMode.alwaysOn:
        return true;
      case FilterMode.scheduled:
        return _scheduleBlend(now) != null;
    }
  }

  bool _isWeekend(DateTime now) =>
      now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

  int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  int _minutesFromDate(DateTime now) => now.hour * 60 + now.minute;

  bool isWindDownActive(DateTime now) => _windDownProgress(now) != null;

  double windDownProgress(DateTime now) => _windDownProgress(now) ?? 0;

  bool isFadeOutActive(DateTime now) => _fadeOutProgress(now) != null;

  double fadeOutProgress(DateTime now) => _fadeOutProgress(now) ?? 0;

  bool get isSleepJournalActive => sleepJournalActiveStart != null;

  Duration? sleepJournalElapsed(DateTime now) {
    final start = sleepJournalActiveStart;
    if (start == null) return null;
    final diff = now.difference(start);
    return diff.isNegative ? Duration.zero : diff;
  }

  double? _windDownProgress(DateTime now) {
    final window = _scheduleWindow(now);
    if (window == null) return null;
    if (window.startMinutes == window.endMinutes) return null;
    final rampMinutes = schedule.windDownMinutes;
    if (rampMinutes <= 0) return null;
    final nowMinutes = _minutesFromDate(now);
    final isActive =
        _isWithinWindow(window.startMinutes, window.endMinutes, nowMinutes);
    if (isActive) return null;
    final rampStart = _wrapMinutes(window.startMinutes - rampMinutes);
    if (!_isWithinWindow(rampStart, window.startMinutes, nowMinutes)) {
      return null;
    }
    final elapsed = _minutesBetween(rampStart, nowMinutes);
    return (elapsed / rampMinutes).clamp(0.0, 1.0);
  }

  double? _fadeOutProgress(DateTime now) {
    final window = _scheduleWindow(now);
    if (window == null) return null;
    if (window.startMinutes == window.endMinutes) return null;
    final fadeMinutes = schedule.fadeOutMinutes;
    if (fadeMinutes <= 0) return null;
    final nowMinutes = _minutesFromDate(now);
    final isActive =
        _isWithinWindow(window.startMinutes, window.endMinutes, nowMinutes);
    if (isActive) return null;
    final rampEnd = _wrapMinutes(window.endMinutes + fadeMinutes);
    if (!_isWithinWindow(window.endMinutes, rampEnd, nowMinutes)) {
      return null;
    }
    final elapsed = _minutesBetween(window.endMinutes, nowMinutes);
    return (elapsed / fadeMinutes).clamp(0.0, 1.0);
  }

  double? _scheduleBlend(DateTime now) {
    if (schedule.mode != FilterMode.scheduled) return null;
    final window = _scheduleWindow(now);
    if (window == null) return null;
    if (window.startMinutes == window.endMinutes) return 1.0;
    final nowMinutes = _minutesFromDate(now);
    if (_isWithinWindow(
      window.startMinutes,
      window.endMinutes,
      nowMinutes,
    )) {
      return 1.0;
    }
    final windDown = _windDownProgress(now);
    if (windDown != null) return windDown;
    final fadeOut = _fadeOutProgress(now);
    if (fadeOut != null) return (1 - fadeOut).clamp(0.0, 1.0);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'presets': presets.map((p) => p.toJson()).toList(),
      'activePresetId': activePresetId,
      'schedule': schedule.toJson(),
      'isPremium': isPremium,
      'filterEnabled': filterEnabled,
      'flashlightEnabled': flashlightEnabled,
      'snoozeUntil': snoozeUntil?.toIso8601String(),
      'sleepJournalActiveStart': sleepJournalActiveStart?.toIso8601String(),
      'sleepJournalEntries':
          sleepJournalEntries.map((entry) => entry.toJson()).toList(),
      'sleepGoalMinutes': sleepGoalMinutes,
      'windDownChecklistDate': windDownChecklistDate?.toIso8601String(),
      'windDownChecklist': windDownChecklist,
      'sleepCheckInEnabled': sleepCheckInEnabled,
      'sleepCheckInTime': _encodeTime(sleepCheckInTime),
      'bedtimeReminderEnabled': bedtimeReminderEnabled,
      'bedtimeReminderMinutes': bedtimeReminderMinutes,
      'caffeineCutoffHours': caffeineCutoffHours,
      'onboardingComplete': onboardingComplete,
      'notificationShortcutEnabled': notificationShortcutEnabled,
      'startOnBootReminder': startOnBootReminder,
      'screenOffUntil': screenOffUntil?.toIso8601String(),
      'blueLightGoalMinutes': blueLightGoalMinutes,
      'screenOffGoalMinutes': screenOffGoalMinutes,
      'bedtimeModePresetId': bedtimeModePresetId,
      'bedtimeModeStartScreenOff': bedtimeModeStartScreenOff,
      'bedtimeModeAutoOffMinutes': bedtimeModeAutoOffMinutes,
      'bedtimeModeAutoOffUntil': bedtimeModeAutoOffUntil?.toIso8601String(),
      'sunsetSyncEnabled': sunsetSyncEnabled,
      'sunsetTime': _encodeTime(sunsetTime),
      'sunsetUpdatedAt': sunsetUpdatedAt?.toIso8601String(),
      'screenOffNotificationsEnabled': screenOffNotificationsEnabled,
      'windDownItems': windDownItems.map((item) => item.toJson()).toList(),
      'highContrastEnabled': highContrastEnabled,
    };
  }

  factory AppState.fromJson(Map<String, dynamic> json) {
    final presetList = (json['presets'] as List<dynamic>)
        .map((item) => FilterPreset.fromJson(item as Map<String, dynamic>))
        .toList();
    final scheduleJson = json['schedule'];
    final schedule = scheduleJson is Map
        ? ScheduleConfig.fromJson(
            Map<String, dynamic>.from(scheduleJson as Map),
          )
        : AppState.initial().schedule;
    return AppState(
      presets: presetList,
      activePresetId: json['activePresetId'] as String? ?? presetList.first.id,
      schedule: schedule,
      isPremium: json['isPremium'] as bool? ?? false,
      filterEnabled: json['filterEnabled'] as bool? ??
          json['overlayEnabled'] as bool? ??
          false,
      flashlightEnabled: json['flashlightEnabled'] as bool? ?? false,
      snoozeUntil: _decodeDateTime(json['snoozeUntil'] as String?),
      sleepJournalActiveStart:
          _decodeDateTime(json['sleepJournalActiveStart'] as String?),
      sleepJournalEntries: _decodeSleepJournalEntries(
        json['sleepJournalEntries'],
      ),
      sleepGoalMinutes: json['sleepGoalMinutes'] as int? ?? 480,
      windDownChecklistDate:
          _decodeDateTime(json['windDownChecklistDate'] as String?),
      windDownChecklist: _decodeChecklist(json['windDownChecklist']),
      sleepCheckInEnabled: json['sleepCheckInEnabled'] as bool? ?? false,
      sleepCheckInTime: _decodeTime(json['sleepCheckInTime']) ??
          const TimeOfDay(hour: 8, minute: 0),
      bedtimeReminderEnabled:
          json['bedtimeReminderEnabled'] as bool? ?? false,
      bedtimeReminderMinutes:
          json['bedtimeReminderMinutes'] as int? ?? 30,
      caffeineCutoffHours: json['caffeineCutoffHours'] as int? ?? 6,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      notificationShortcutEnabled:
          json['notificationShortcutEnabled'] as bool? ?? false,
      startOnBootReminder: json['startOnBootReminder'] as bool? ?? false,
      screenOffUntil: _decodeDateTime(json['screenOffUntil'] as String?),
      blueLightGoalMinutes: json['blueLightGoalMinutes'] as int? ?? 120,
      screenOffGoalMinutes: json['screenOffGoalMinutes'] as int? ?? 60,
      bedtimeModePresetId: json['bedtimeModePresetId'] as String?,
      bedtimeModeStartScreenOff:
          json['bedtimeModeStartScreenOff'] as bool? ?? true,
      bedtimeModeAutoOffMinutes:
          json['bedtimeModeAutoOffMinutes'] as int? ?? 0,
      bedtimeModeAutoOffUntil:
          _decodeDateTime(json['bedtimeModeAutoOffUntil'] as String?),
      sunsetSyncEnabled: json['sunsetSyncEnabled'] as bool? ?? false,
      sunsetTime: _decodeTime(json['sunsetTime']),
      sunsetUpdatedAt: _decodeDateTime(json['sunsetUpdatedAt'] as String?),
      screenOffNotificationsEnabled:
          json['screenOffNotificationsEnabled'] as bool? ?? true,
      windDownItems: _decodeWindDownItems(json['windDownItems']) ??
          _defaultWindDownItems(),
      highContrastEnabled: json['highContrastEnabled'] as bool? ?? false,
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
        windDownMinutes: 30,
        fadeOutMinutes: 15,
      ),
      isPremium: false,
      filterEnabled: true,
      flashlightEnabled: false,
      snoozeUntil: null,
      sleepJournalActiveStart: null,
      sleepJournalEntries: const [],
      sleepGoalMinutes: 480,
      windDownChecklistDate: null,
      windDownChecklist: const {},
      sleepCheckInEnabled: false,
      sleepCheckInTime: const TimeOfDay(hour: 8, minute: 0),
      bedtimeReminderEnabled: false,
      bedtimeReminderMinutes: 30,
      caffeineCutoffHours: 6,
      onboardingComplete: false,
      notificationShortcutEnabled: true,
      startOnBootReminder: false,
      screenOffUntil: null,
      blueLightGoalMinutes: 120,
      screenOffGoalMinutes: 60,
      bedtimeModePresetId: null,
      bedtimeModeStartScreenOff: true,
      bedtimeModeAutoOffMinutes: 0,
      bedtimeModeAutoOffUntil: null,
      sunsetSyncEnabled: false,
      sunsetTime: null,
      sunsetUpdatedAt: null,
      screenOffNotificationsEnabled: true,
      windDownItems: _defaultWindDownItems(),
      highContrastEnabled: false,
    );
  }

  bool isSnoozed(DateTime now) =>
      snoozeUntil != null && now.isBefore(snoozeUntil!);

  /// Returns the next time the filter state should change based on snooze or schedule.
  /// Null means no upcoming change (always on/off or manual off).
  DateTime? nextScheduleChange(DateTime now) {
    if (isSnoozed(now) && snoozeUntil != null) return snoozeUntil;

    switch (schedule.mode) {
      case FilterMode.off:
        return null;
      case FilterMode.alwaysOn:
        return null;
      case FilterMode.scheduled:
        final window = _scheduleWindow(now);
        if (window == null) return null;
        if (window.startMinutes == window.endMinutes) return null;
        final nowMinutes = _minutesFromDate(now);
        final windDownMinutes = schedule.windDownMinutes;
        final fadeOutMinutes = schedule.fadeOutMinutes;
        final rampStart = windDownMinutes > 0
            ? _wrapMinutes(window.startMinutes - windDownMinutes)
            : window.startMinutes;
        final rampEnd = fadeOutMinutes > 0
            ? _wrapMinutes(window.endMinutes + fadeOutMinutes)
            : window.endMinutes;
        final inWindDown = windDownMinutes > 0 &&
            _isWithinWindow(rampStart, window.startMinutes, nowMinutes) &&
            !_isWithinWindow(
              window.startMinutes,
              window.endMinutes,
              nowMinutes,
            );
        if (inWindDown) {
          return _nextOccurrence(now, window.startMinutes);
        }
        final inActive =
            _isWithinWindow(window.startMinutes, window.endMinutes, nowMinutes);
        if (inActive) {
          return _nextOccurrence(now, window.endMinutes);
        }
        final inFadeOut = fadeOutMinutes > 0 &&
            _isWithinWindow(window.endMinutes, rampEnd, nowMinutes);
        if (inFadeOut) {
          return _nextOccurrence(now, rampEnd);
        }
        final nextStart =
            windDownMinutes > 0 ? rampStart : window.startMinutes;
        return _nextOccurrence(now, nextStart);
    }
  }

  ScheduleEvent? nextScheduleEvent(DateTime now) {
    if (schedule.mode != FilterMode.scheduled) return null;
    final window = _scheduleWindow(now);
    if (window == null) return null;
    if (window.startMinutes == window.endMinutes) return null;
    final nowMinutes = _minutesFromDate(now);
    final windDownMinutes = schedule.windDownMinutes;
    final fadeOutMinutes = schedule.fadeOutMinutes;
    final rampStart = windDownMinutes > 0
        ? _wrapMinutes(window.startMinutes - windDownMinutes)
        : window.startMinutes;
    final rampEnd = fadeOutMinutes > 0
        ? _wrapMinutes(window.endMinutes + fadeOutMinutes)
        : window.endMinutes;
    final inWindow = _isWithinWindow(rampStart, rampEnd, nowMinutes);
    final targetMinutes = inWindow ? rampEnd : rampStart;
    final eventTime = _nextOccurrence(now, targetMinutes);
    return ScheduleEvent(time: eventTime, enable: !inWindow);
  }

  static DateTime? _decodeDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static List<SleepJournalEntry> _decodeSleepJournalEntries(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) => SleepJournalEntry.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static Map<String, bool> _decodeChecklist(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, entry) => MapEntry(key.toString(), entry == true),
    );
  }

  static Map<String, dynamic>? _encodeTime(TimeOfDay? time) {
    if (time == null) return null;
    return {'hour': time.hour, 'minute': time.minute};
  }

  static TimeOfDay? _decodeTime(dynamic value) {
    if (value == null || value is! Map) return null;
    final hour = value['hour'];
    final minute = value['minute'];
    if (hour is! int || minute is! int) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static List<WindDownItem>? _decodeWindDownItems(dynamic value) {
    if (value is! List) return null;
    return value
        .whereType<Map>()
        .map(
          (item) => WindDownItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  _ScheduleWindow? _scheduleWindow(DateTime now) {
    final useWeekend = schedule.weekendDifferent && _isWeekend(now);
    final start = useWeekend
        ? (schedule.weekendStartTime ?? schedule.startTime)
        : schedule.startTime;
    final end = useWeekend
        ? (schedule.weekendEndTime ?? schedule.endTime)
        : schedule.endTime;
    if (start == null || end == null) return null;
    return _ScheduleWindow(
      startMinutes: _minutesOfDay(start),
      endMinutes: _minutesOfDay(end),
    );
  }

  bool _isWithinWindow(int startMinutes, int endMinutes, int nowMinutes) {
    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  int _wrapMinutes(int minutes) {
    final value = minutes % _minutesPerDay;
    return value < 0 ? value + _minutesPerDay : value;
  }

  int _minutesBetween(int startMinutes, int endMinutes) {
    if (endMinutes >= startMinutes) return endMinutes - startMinutes;
    return _minutesPerDay - startMinutes + endMinutes;
  }

  FilterPreset _lerpPreset(
    FilterPreset from,
    FilterPreset to,
    double t,
  ) {
    final eased = _smoothstep(t);
    return FilterPreset(
      id: to.id,
      name: to.name,
      temperature: _lerpDouble(from.temperature, to.temperature, eased),
      opacity: _lerpDouble(from.opacity, to.opacity, eased),
      brightness: _lerpDouble(from.brightness, to.brightness, eased),
      isPremium: to.isPremium,
      isCustom: to.isCustom,
    );
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  double _smoothstep(double t) => t * t * (3 - 2 * t);

  FilterPreset get _neutralPreset => const FilterPreset(
        id: 'neutral',
        name: 'Neutral',
        temperature: 0,
        opacity: 0,
        brightness: 100,
      );

  DateTime _nextOccurrence(DateTime now, int targetMinutes) {
    final nowMinutes = _minutesFromDate(now);
    final dayOffset = targetMinutes <= nowMinutes ? 1 : 0;
    return _todayWithMinutes(now, targetMinutes, dayOffset);
  }

  DateTime _todayWithMinutes(DateTime now, int minutes, int dayOffset) {
    final base = DateTime(now.year, now.month, now.day)
        .add(Duration(days: dayOffset, minutes: minutes));
    return base;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static const int _minutesPerDay = 24 * 60;
}

class WindDownItem {
  const WindDownItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
    };
  }

  factory WindDownItem.fromJson(Map<String, dynamic> json) {
    return WindDownItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

List<WindDownItem> _defaultWindDownItems() {
  return const [
    WindDownItem(id: 'lights', label: 'Dim the lights'),
    WindDownItem(id: 'screens', label: 'Silence notifications'),
    WindDownItem(id: 'stretch', label: 'Stretch or breathe for 2 minutes'),
    WindDownItem(id: 'notes', label: 'Write tomorrow\'s top priority'),
    WindDownItem(id: 'hydrate', label: 'Sip water and avoid caffeine'),
  ];
}

class _ScheduleWindow {
  const _ScheduleWindow({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;
}

class ScheduleEvent {
  const ScheduleEvent({
    required this.time,
    required this.enable,
  });

  final DateTime time;
  final bool enable;
}
