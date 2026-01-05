import 'package:flutter/material.dart';

enum FilterMode { off, alwaysOn, scheduled }

class FilterPreset {
  const FilterPreset({
    required this.id,
    required this.name,
    required this.temperature,
    required this.opacity,
    required this.brightness,
    this.isPremium = false,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final double temperature; // 0-100
  final double opacity; // 0-100
  final double brightness; // 0-100
  final bool isPremium;
  final bool isCustom;

  FilterPreset copyWith({
    String? id,
    String? name,
    double? temperature,
    double? opacity,
    double? brightness,
    bool? isPremium,
    bool? isCustom,
  }) {
    return FilterPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      temperature: temperature ?? this.temperature,
      opacity: opacity ?? this.opacity,
      brightness: brightness ?? this.brightness,
      isPremium: isPremium ?? this.isPremium,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'temperature': temperature,
      'opacity': opacity,
      'brightness': brightness,
      'isPremium': isPremium,
      'isCustom': isCustom,
    };
  }

  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      opacity: (json['opacity'] as num).toDouble(),
      brightness: (json['brightness'] as num).toDouble(),
      isPremium: json['isPremium'] as bool? ?? false,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }
}

class ScheduleConfig {
  const ScheduleConfig({
    required this.mode,
    required this.startTime,
    required this.endTime,
    this.windDownMinutes = 0,
    this.fadeOutMinutes = 0,
    this.targetPresetId,
    this.weekendDifferent = false,
    this.weekendStartTime,
    this.weekendEndTime,
  });

  final FilterMode mode;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final int windDownMinutes;
  final int fadeOutMinutes;
  final String? targetPresetId;
  final bool weekendDifferent;
  final TimeOfDay? weekendStartTime;
  final TimeOfDay? weekendEndTime;

  ScheduleConfig copyWith({
    FilterMode? mode,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? windDownMinutes,
    int? fadeOutMinutes,
    String? targetPresetId,
    bool? weekendDifferent,
    TimeOfDay? weekendStartTime,
    TimeOfDay? weekendEndTime,
  }) {
    return ScheduleConfig(
      mode: mode ?? this.mode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      windDownMinutes: windDownMinutes ?? this.windDownMinutes,
      fadeOutMinutes: fadeOutMinutes ?? this.fadeOutMinutes,
      targetPresetId: targetPresetId ?? this.targetPresetId,
      weekendDifferent: weekendDifferent ?? this.weekendDifferent,
      weekendStartTime: weekendStartTime ?? this.weekendStartTime,
      weekendEndTime: weekendEndTime ?? this.weekendEndTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'startTime': _encodeTime(startTime),
      'endTime': _encodeTime(endTime),
      'windDownMinutes': windDownMinutes,
      'fadeOutMinutes': fadeOutMinutes,
      'targetPresetId': targetPresetId,
      'weekendDifferent': weekendDifferent,
      'weekendStartTime': _encodeTime(weekendStartTime),
      'weekendEndTime': _encodeTime(weekendEndTime),
    };
  }

  factory ScheduleConfig.fromJson(Map<String, dynamic> json) {
    final modeName = json['mode'] as String?;
    final parsedMode = FilterMode.values.firstWhere(
      (mode) => mode.name == modeName,
      orElse: () => FilterMode.off,
    );
    return ScheduleConfig(
      mode: parsedMode,
      startTime: _decodeTime(json['startTime']),
      endTime: _decodeTime(json['endTime']),
      windDownMinutes: json['windDownMinutes'] as int? ?? 0,
      fadeOutMinutes: json['fadeOutMinutes'] as int? ?? 0,
      targetPresetId: json['targetPresetId'] as String?,
      weekendDifferent: json['weekendDifferent'] as bool? ?? false,
      weekendStartTime: _decodeTime(json['weekendStartTime']),
      weekendEndTime: _decodeTime(json['weekendEndTime']),
    );
  }

  static Map<String, dynamic>? _encodeTime(TimeOfDay? time) {
    if (time == null) return null;
    return {'hour': time.hour, 'minute': time.minute};
  }

  static TimeOfDay? _decodeTime(dynamic value) {
    if (value == null) return null;
    final data = value as Map<String, dynamic>;
    return TimeOfDay(hour: data['hour'] as int, minute: data['minute'] as int);
  }
}
