import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final adsServiceProvider = Provider<AdsService>((ref) {
  return AdsService();
});

class AdsService {
  AdsService();

  bool _initialized = false;
  InterstitialAd? _interstitial;

  Future<void> initialize() async {
    if (!_supportsAds) return;
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      await loadInterstitial();
    } catch (_) {
      _initialized = false;
    }
  }

  AdRequest get _adRequest =>
      const AdRequest(keywords: ['blue light filter', 'sleep', 'health']);

  String get bannerAdUnitId => 'ca-app-pub-3940256099942544/6300978111';

  String get interstitialAdUnitId => 'ca-app-pub-3940256099942544/1033173712';

  Future<void> loadInterstitial() async {
    if (!_supportsAds) return;
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: _adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) => _interstitial = null,
      ),
    );
  }

  Future<void> showInterstitialIfAvailable() async {
    if (!_supportsAds) return;
    final ad = _interstitial;
    if (ad == null) {
      await loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => loadInterstitial(),
      onAdFailedToShowFullScreenContent: (ad, error) => loadInterstitial(),
    );
    await ad.show();
    _interstitial = null;
  }

  bool get _supportsAds => !kIsWeb;
}
