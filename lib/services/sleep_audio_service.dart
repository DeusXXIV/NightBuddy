import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_notifier.dart';
import '../state/app_state.dart';

class SleepTrackOption {
  const SleepTrackOption({
    required this.id,
    required this.label,
    this.asset,
    this.isPremium = false,
  });

  final String id;
  final String label;
  final String? asset;
  final bool isPremium;
}

const sleepTrackOptions = <SleepTrackOption>[
  SleepTrackOption(
    id: 'drift',
    label: 'Rainbound Lullaby',
    asset: 'sounds/SoundScapes/Rain.aac',
  ),
  SleepTrackOption(id: 'fan', label: 'Velvet Fan Drift', isPremium: true),
  SleepTrackOption(id: 'ocean', label: 'Oceannight Repose', isPremium: true),
];

final sleepAudioControllerProvider =
    ChangeNotifierProvider<SleepAudioController>((ref) {
      return SleepAudioController(
        ref,
        player: ref.read(sleepAudioPlayerFactoryProvider)(),
        assetLoader: ref.read(sleepAudioAssetLoaderProvider),
      );
    });

final sleepAudioPlayerFactoryProvider = Provider<SleepAudioPlayer Function()>((
  ref,
) {
  return () => AudioplayersSleepAudioPlayer(AudioPlayer());
});

final sleepAudioAssetLoaderProvider = Provider<SleepAudioAssetLoader>((ref) {
  return _loadSleepAssetBytes;
});

typedef SleepAudioAssetLoader = Future<Uint8List?> Function(String asset);

abstract class SleepAudioPlayer {
  Future<void> setLooping();
  Future<void> stop();
  Future<void> playBytes(Uint8List bytes);
  Future<void> dispose();
}

class AudioplayersSleepAudioPlayer implements SleepAudioPlayer {
  AudioplayersSleepAudioPlayer(this._player);

  final AudioPlayer _player;

  @override
  Future<void> setLooping() => _player.setReleaseMode(ReleaseMode.loop);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> playBytes(Uint8List bytes) => _player.play(BytesSource(bytes));

  @override
  Future<void> dispose() => _player.dispose();
}

class SleepAudioController extends ChangeNotifier {
  SleepAudioController(
    this._ref, {
    required SleepAudioPlayer player,
    required SleepAudioAssetLoader assetLoader,
  }) : _player = player,
       _assetLoader = assetLoader {
    _player.setLooping();
  }

  final Ref _ref;
  final SleepAudioPlayer _player;
  final SleepAudioAssetLoader _assetLoader;
  String? _activeTrackId;
  DateTime? _endTime;
  Timer? _timer;

  String? get activeTrackId => _activeTrackId;
  DateTime? get endTime => _endTime;
  bool get isPlaying => _activeTrackId != null;

  Future<SleepAudioResult> playTrack(String trackId) async {
    final state = _ref.read(appStateProvider).valueOrNull ?? AppState.initial();
    final option = sleepTrackOptions.firstWhere(
      (item) => item.id == trackId,
      orElse: () => sleepTrackOptions.first,
    );
    if (option.isPremium && !state.isPremium) {
      return SleepAudioResult.premiumLocked;
    }
    if (option.asset == null) {
      return SleepAudioResult.unavailable;
    }
    _timer?.cancel();
    try {
      final bytes = await _assetLoader(option.asset!);
      if (bytes == null) return SleepAudioResult.unavailable;
      await _player.stop();
      await _player.playBytes(bytes);
      _activeTrackId = option.id;
      notifyListeners();
      return SleepAudioResult.playing;
    } catch (_) {
      return SleepAudioResult.unavailable;
    }
  }

  Future<SleepAudioResult> playFavoriteTrack() async {
    final state = _ref.read(appStateProvider).valueOrNull ?? AppState.initial();
    return playTrack(state.favoriteSleepTrackId ?? sleepTrackOptions.first.id);
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _player.stop();
    _activeTrackId = null;
    _endTime = null;
    notifyListeners();
  }

  Future<void> startTimer(Duration duration) async {
    _timer?.cancel();
    await _ref
        .read(appStateProvider.notifier)
        .setPreferredSleepTimerMinutes(duration.inMinutes);
    _endTime = DateTime.now().add(duration);
    notifyListeners();
    _timer = Timer(duration, () async {
      await stop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

enum SleepAudioResult { playing, unavailable, premiumLocked }

Future<Uint8List?> _loadSleepAssetBytes(String asset) async {
  final candidates = <String>[
    asset,
    if (!asset.startsWith('assets/')) 'assets/$asset',
    if (asset.startsWith('assets/')) asset.substring('assets/'.length),
  ];
  for (final candidate in candidates.toSet()) {
    try {
      final data = await rootBundle.load(candidate);
      return data.buffer.asUint8List();
    } catch (_) {
      continue;
    }
  }
  return null;
}
