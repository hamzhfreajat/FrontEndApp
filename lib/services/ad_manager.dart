import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A banner waiting in the queue, with the time it arrived.
class _Cached {
  _Cached(this.ad) : loadedAt = DateTime.now();
  final BannerAd ad;
  final DateTime loadedAt;
}

class AdManager {
  AdManager._privateConstructor();
  static final AdManager instance = AdManager._privateConstructor();

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2993417564924380/9310381325'
      : 'ca-app-pub-2993417564924380/8456156193';

  // A queue of preloaded ads
  final List<_Cached> _preloadedAds = [];
  bool _isLoading = false;

  // One ad ready in advance is enough. Ads loaded but never shown lower the
  // "show rate", and Google pays less for apps whose loaded ads go unseen.
  final int _maxCacheSize = 1;

  /// Google counts an impression only for ads shown within an hour of loading;
  /// older ones in the queue are thrown away before they are shown.
  static const Duration _maxAge = Duration(minutes: 50);

  /// After a failure, wait longer each time (10s, 20s, 40s … up to 5 minutes)
  /// instead of asking again every 10 seconds, which lowers the match rate.
  int _failures = 0;
  Timer? _retry;

  /// What the page is about. Advertisers bid more for a request they can match
  /// to their audience, so every request says it comes from a Jordanian real-estate app.
  static const List<String> _baseKeywords = ['عقارات', 'real estate', 'Jordan', 'الأردن', 'apartments', 'شقق'];
  static const String _contentUrl = 'https://sooq-com.com';

  AdRequest _request() => const AdRequest(keywords: _baseKeywords, contentUrl: _contentUrl);

  void _dropExpired() {
    final now = DateTime.now();
    _preloadedAds.removeWhere((cached) {
      final expired = now.difference(cached.loadedAt) > _maxAge;
      if (expired) cached.ad.dispose();
      return expired;
    });
  }

  Future<void> preloadAds(double width) async {
    _dropExpired();
    if (_preloadedAds.length >= _maxCacheSize || _isLoading || _retry?.isActive == true) return;
    _isLoading = true;

    try {
      final AdSize size = AdSize.mediumRectangle;

      final BannerAd ad = BannerAd(
        adUnitId: _adUnitId,
        request: _request(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('AdManager: BannerAd loaded and cached.');
            _preloadedAds.add(_Cached(ad as BannerAd));
            _isLoading = false;
            _failures = 0;
            // Check if we need to load another one
            preloadAds(width);
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint('AdManager: BannerAd failed to load: $err');
            ad.dispose();
            _isLoading = false;
            _failures++;
            final seconds = (10 * (1 << (_failures - 1).clamp(0, 5))).clamp(10, 300);
            _retry = Timer(Duration(seconds: seconds), () => preloadAds(width));
          },
        ),
      );

      await ad.load();
    } catch (e) {
      _isLoading = false;
      debugPrint('AdManager: Error preloading ad: $e');
    }
  }

  /// Returns a preloaded ad immediately if available, otherwise creates and loads a new one.
  Future<BannerAd?> getAd(double width) async {
    _dropExpired();
    // Top up the queue in the background
    preloadAds(width);

    if (_preloadedAds.isNotEmpty) {
      return _preloadedAds.removeAt(0).ad;
    }

    // If no ad is ready, we have to create one on the spot
    final AdSize size = AdSize.mediumRectangle;

    final completer = Completer<BannerAd?>();
    final BannerAd ad = BannerAd(
      adUnitId: _adUnitId,
      request: _request(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!completer.isCompleted) completer.complete(loadedAd as BannerAd);
        },
        onAdFailedToLoad: (failedAd, err) {
          debugPrint('AdManager (JIT): BannerAd failed to load: $err');
          failedAd.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    await ad.load();
    return completer.future;
  }
}
