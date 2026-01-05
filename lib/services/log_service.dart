import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final logServiceProvider = Provider<LogService>((ref) {
  return LogService();
});

class LogService {
  static const _key = 'nightbuddy_logs';
  static const _maxEntries = 50;

  final StreamController<List<AppLogEntry>> _controller =
      StreamController<List<AppLogEntry>>.broadcast();

  List<AppLogEntry> _entries = [];
  bool _initialized = false;

  Stream<List<AppLogEntry>> get entries => _controller.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as List<dynamic>;
        _entries = data
            .whereType<Map>()
            .map((item) => AppLogEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (_) {
        _entries = [];
      }
    }
    _controller.add(List.unmodifiable(_entries));
    _initialized = true;
  }

  Future<void> logEvent({
    required String type,
    required String message,
    Map<String, dynamic>? details,
  }) async {
    await initialize();
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      type: type,
      message: message,
      details: details,
    );
    _entries = [entry, ..._entries].take(_maxEntries).toList();
    _controller.add(List.unmodifiable(_entries));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    this.details,
  });

  final DateTime timestamp;
  final String type;
  final String message;
  final Map<String, dynamic>? details;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'message': message,
      'details': details,
    };
  }

  factory AppLogEntry.fromJson(Map<String, dynamic> json) {
    return AppLogEntry(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      type: json['type'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : null,
    );
  }
}
