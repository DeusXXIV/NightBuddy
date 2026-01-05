import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/filter_models.dart';

final overlayServiceProvider = Provider<OverlayService>((ref) {
  return OverlayService();
});

final flashlightAvailableProvider = FutureProvider.autoDispose<bool>((ref) async {
  final service = ref.read(overlayServiceProvider);
  return service.hasFlashlight();
});

class OverlayService {
  OverlayService();

  static const _channel = MethodChannel('nightbuddy/overlay');
  static const _eventChannel = EventChannel('nightbuddy/overlay_events');
  final StreamController<void> _toggleRequests =
      StreamController<void>.broadcast();
  bool _handlerAttached = false;

  Future<void> initialize() async {
    if (!_supportsNative) return;
    if (_handlerAttached) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'toggleFilter') {
        _toggleRequests.add(null);
      }
    });
  }

  Stream<bool> get overlayStatusStream {
    if (!_supportsNative) return Stream<bool>.empty();
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event == true)
        .distinct();
  }

  Stream<void> get toggleRequests {
    if (!_supportsNative) return Stream<void>.empty();
    return _toggleRequests.stream;
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

  Future<bool> hasFlashlight() async {
    if (!_supportsNative) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasFlashlight');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> getFlashlightStatus() async {
    if (!_supportsNative) return null;
    final hasFlash = await hasFlashlight();
    if (!hasFlash) return null;
    final hasPermission = await hasFlashlightPermission();
    if (!hasPermission) return false;
    try {
      return await _channel.invokeMethod<bool>('getFlashlightStatus');
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasFlashlightPermission() async {
    if (!_supportsNative) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('hasFlashlightPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestFlashlightPermission() async {
    if (!_supportsNative) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('requestFlashlightPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setFlashlight(bool enabled) async {
    if (!_supportsNative) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'setFlashlight',
        {'enabled': enabled},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
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
