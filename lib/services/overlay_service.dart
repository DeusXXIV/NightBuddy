import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/filter_models.dart';

final overlayServiceProvider = Provider<OverlayService>((ref) {
  return OverlayService();
});

class OverlayService {
  OverlayService();

  static const _channel = MethodChannel('nightbuddy/overlay');

  Future<void> initialize() async {
    if (!_supportsNative) return;
    // Placeholder for permission checks or warm-up work.
  }

  Future<bool?> isOverlayEnabled() async {
    if (!_supportsNative) return false;
    try {
      final result = await _channel.invokeMethod<bool>('getOverlayStatus');
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasPermission() async {
    if (!_supportsNative) return true;
    final result = await _channel.invokeMethod<bool>('hasPermission');
    return result ?? false;
  }

  Future<bool> requestPermission() async {
    if (!_supportsNative) return true;
    final result = await _channel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  Future<void> startOverlay({
    required FilterPreset preset,
    required bool showNotification,
  }) async {
    if (!_supportsNative) return;
    await _channel.invokeMethod<void>(
      'startOverlay',
      _presetPayload(preset, showNotification),
    );
  }

  Future<void> updateOverlay({
    required FilterPreset preset,
    required bool enabled,
    required bool showNotification,
  }) async {
    if (!_supportsNative) return;
    if (!enabled) {
      await stopOverlay(showNotification: showNotification);
      return;
    }
    await _channel.invokeMethod<void>(
      'updateOverlay',
      _presetPayload(preset, showNotification),
    );
  }

  Future<void> stopOverlay({required bool showNotification}) async {
    if (!_supportsNative) return;
    await _channel.invokeMethod<void>('stopOverlay', {
      'showNotification': showNotification,
    });
  }

  Map<String, dynamic> _presetPayload(
    FilterPreset preset,
    bool showNotification,
  ) {
    return {
      'temperature': preset.temperature,
      'opacity': preset.opacity,
      'brightness': preset.brightness,
      'showNotification': showNotification,
    };
  }

  bool get _supportsNative => !kIsWeb && Platform.isAndroid;
}
