import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  AdManager._privateConstructor();
  static final AdManager instance = AdManager._privateConstructor();

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2993417564924380/9310381325'
      : 'ca-app-pub-2993417564924380/8456156193';

  // A queue of preloaded ads
  final List<BannerAd> _preloadedAds = [];
  bool _isLoading = false;
  
  // Maintain max 2-3 ads in queue
  final int _maxCacheSize = 2;

  Future<void> preloadAds(double width) async {
    if (_preloadedAds.length >= _maxCacheSize || _isLoading) return;
    _isLoading = true;

    try {
      final AdSize size = AdSize.mediumRectangle;

      final BannerAd ad = BannerAd(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('AdManager: BannerAd loaded and cached.');
            _preloadedAds.add(ad as BannerAd);
            _isLoading = false;
            // Check if we need to load another one
            preloadAds(width);
          },
          onAdFailedToLoad: (ad, err) {
            debugPrint('AdManager: BannerAd failed to load: $err');
            ad.dispose();
            _isLoading = false;
            // Retry after delay
            Future.delayed(const Duration(seconds: 10), () => preloadAds(width));
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
    // Top up the queue in the background
    preloadAds(width);
    
    if (_preloadedAds.isNotEmpty) {
      return _preloadedAds.removeAt(0);
    }
    
    // If no ad is ready, we have to create one on the spot
    final AdSize size = AdSize.mediumRectangle;
    
    final completer = Completer<BannerAd?>();
    final BannerAd ad = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
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
