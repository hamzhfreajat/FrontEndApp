import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_manager.dart';

class InlineBannerAd extends StatefulWidget {
  const InlineBannerAd({super.key});

  @override
  State<InlineBannerAd> createState() => _InlineBannerAdState();
}

class _InlineBannerAdState extends State<InlineBannerAd> with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  bool get wantKeepAlive => true; // Keep ad alive when scrolling

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoaded && _bannerAd == null) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    // Get screen width to pass to AdManager
    final double width = MediaQuery.of(context).size.width;
    
    // Get preloaded ad from manager (or it will create a new one instantly)
    final BannerAd ad = await AdManager.instance.getAd(width);
    
    if (mounted) {
      setState(() {
        _bannerAd = ad;
        _isLoaded = true;
      });
    } else {
      ad.dispose();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_bannerAd != null && _isLoaded) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        margin: const EdgeInsets.symmetric(vertical: 16.0),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}
