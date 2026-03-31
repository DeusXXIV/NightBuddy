import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nightbuddy/services/sleep_audio_service.dart';
import 'package:nightbuddy/services/storage_service.dart';
import 'package:nightbuddy/state/app_notifier.dart';
import 'package:nightbuddy/state/app_state.dart';

class _TestAppStateNotifier extends AppStateNotifier {
  _TestAppStateNotifier(this._state);

  final AppState _state;

  @override
  Future<AppState> build() async => _state;
}

class _FakeSleepAudioPlayer implements SleepAudioPlayer {
  bool disposed = false;
  bool stopped = false;
  bool loopingEnabled = false;
  Uint8List? lastPlayedBytes;

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<void> playBytes(Uint8List bytes) async {
    lastPlayedBytes = bytes;
  }

  @override
  Future<void> setLooping() async {
    loopingEnabled = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class _FakeStorageService extends StorageService {
  AppState? storedState;

  @override
  Future<AppState?> loadState() async => storedState;

  @override
  Future<void> saveState(AppState state) async {
    storedState = state;
  }
}

void main() {
  test(
    'playFavoriteTrack falls back to Rainbound and starts playback',
    () async {
      final player = _FakeSleepAudioPlayer();
      final storage = _FakeStorageService();
      final container = ProviderContainer(
        overrides: [
          appStateProvider.overrideWith(
            () => _TestAppStateNotifier(AppState.initial()),
          ),
          storageServiceProvider.overrideWithValue(storage),
          sleepAudioPlayerFactoryProvider.overrideWithValue(() => player),
          sleepAudioAssetLoaderProvider.overrideWithValue(
            (asset) async => Uint8List.fromList([1, 2, 3]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appStateProvider.future);
      final controller = container.read(sleepAudioControllerProvider);
      final result = await controller.playFavoriteTrack();

      expect(result, SleepAudioResult.playing);
      expect(player.loopingEnabled, isTrue);
      expect(player.stopped, isTrue);
      expect(player.lastPlayedBytes, isNotNull);
      expect(controller.activeTrackId, 'drift');
      expect(controller.isPlaying, isTrue);
    },
  );

  test(
    'playTrack returns unavailable when asset bytes cannot be loaded',
    () async {
      final player = _FakeSleepAudioPlayer();
      final storage = _FakeStorageService();
      final container = ProviderContainer(
        overrides: [
          appStateProvider.overrideWith(
            () => _TestAppStateNotifier(AppState.initial()),
          ),
          storageServiceProvider.overrideWithValue(storage),
          sleepAudioPlayerFactoryProvider.overrideWithValue(() => player),
          sleepAudioAssetLoaderProvider.overrideWithValue(
            (asset) async => null,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appStateProvider.future);
      final controller = container.read(sleepAudioControllerProvider);
      final result = await controller.playTrack('drift');

      expect(result, SleepAudioResult.unavailable);
      expect(controller.activeTrackId, isNull);
      expect(player.lastPlayedBytes, isNull);
    },
  );

  test(
    'playTrack returns premiumLocked for locked tracks on free state',
    () async {
      final player = _FakeSleepAudioPlayer();
      final storage = _FakeStorageService();
      final container = ProviderContainer(
        overrides: [
          appStateProvider.overrideWith(
            () => _TestAppStateNotifier(
              AppState.initial().copyWith(isPremium: false),
            ),
          ),
          storageServiceProvider.overrideWithValue(storage),
          sleepAudioPlayerFactoryProvider.overrideWithValue(() => player),
          sleepAudioAssetLoaderProvider.overrideWithValue(
            (asset) async => Uint8List.fromList([4, 5, 6]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appStateProvider.future);
      final controller = container.read(sleepAudioControllerProvider);
      final result = await controller.playTrack('fan');

      expect(result, SleepAudioResult.premiumLocked);
      expect(controller.activeTrackId, isNull);
      expect(player.lastPlayedBytes, isNull);
    },
  );

  test('startTimer persists preferred minutes to app state', () async {
    final player = _FakeSleepAudioPlayer();
    final storage = _FakeStorageService();
    final container = ProviderContainer(
      overrides: [
        appStateProvider.overrideWith(
          () => _TestAppStateNotifier(AppState.initial()),
        ),
        storageServiceProvider.overrideWithValue(storage),
        sleepAudioPlayerFactoryProvider.overrideWithValue(() => player),
        sleepAudioAssetLoaderProvider.overrideWithValue(
          (asset) async => Uint8List.fromList([7, 8, 9]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appStateProvider.future);
    final controller = container.read(sleepAudioControllerProvider);

    await controller.startTimer(const Duration(minutes: 45));

    final updated = container.read(appStateProvider).valueOrNull;
    expect(updated?.preferredSleepTimerMinutes, 45);
    expect(controller.endTime, isNotNull);
  });
}
