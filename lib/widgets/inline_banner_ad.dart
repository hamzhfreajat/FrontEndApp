import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InlineBannerAd extends StatefulWidget {
  const InlineBannerAd({super.key});

  @override
  State<InlineBannerAd> createState() => _InlineBannerAdState();
}

class _InlineBannerAdState extends State<InlineBannerAd> with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoadingAd = false;
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2993417564924380/9310381325'
      : 'ca-app-pub-2993417564924380/8456156193';

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded && _bannerAd == null && !_isLoadingAd) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    _isLoadingAd = true;
    final double width = MediaQuery.of(context).size.width;
    final AdSize size = (await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width.truncate())) ?? AdSize.banner;
    
    final BannerAd ad = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (mounted) {
            setState(() {
              _bannerAd = loadedAd as BannerAd;
              _isLoaded = true;
              _isLoadingAd = false;
            });
          } else {
            loadedAd.dispose();
          }
        },
        onAdFailedToLoad: (failedAd, err) {
          debugPrint('InlineBannerAd failed to load: $err');
          failedAd.dispose();
          if (mounted) {
            setState(() {
              _isLoadingAd = false;
            });
          }
        },
      ),
    );
    
    try {
      await ad.load();
    } catch (e) {
      debugPrint('InlineBannerAd load exception: $e');
      if (mounted) {
        setState(() {
          _isLoadingAd = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_bannerAd != null && _isLoaded) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return const SizedBox.shrink();
  }
}
