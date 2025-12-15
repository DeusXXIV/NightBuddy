import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsBanner extends StatefulWidget {
  const AdsBanner({
    super.key,
    required this.adUnitId,
  });

  final String adUnitId;

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  BannerAd? _banner;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {
          _banner = ad as BannerAd;
          _loading = false;
        }),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          setState(() {
            _banner = null;
            _loading = false;
          });
        },
      ),
    );
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_banner == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: _banner!.size.height.toDouble(),
      width: _banner!.size.width.toDouble(),
      child: AdWidget(ad: _banner!),
    );
  }
}
