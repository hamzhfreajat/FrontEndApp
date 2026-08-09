import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({Key? key}) : super(key: key);

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> with AutomaticKeepAliveClientMixin {
  NativeAd? _nativeAd;
  AdWidget? _adWidget;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2993417564924380/4129879862'
      : 'ca-app-pub-2993417564924380/7271314451';

  @override
  bool get wantKeepAlive => true; // Prevent disposing when scrolling off-screen (fixes lag)

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: '', // Not needed when using NativeTemplateStyle
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('$NativeAd loaded.');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _isAdFailed = false;
              _adWidget = AdWidget(ad: _nativeAd!);
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('$NativeAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdFailed = true;
            });
          }
        },
      ),
      request: const AdRequest(),
      // Use the built-in NativeTemplateStyle (Small template) for a premium, non-intrusive look
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF25D366), // Matches app's Call/WhatsApp green
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1E1E2C), // Deeper premium text
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF64748B), // Slate gray
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF94A3B8), // Lighter slate
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isAdFailed) {
      return const SizedBox.shrink(); // Hide if failed
    }

    if (!_isAdLoaded || _adWidget == null) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      );
    }

    return Container(
      height: 120, // Standard exact height for small template
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _adWidget,
    );
  }
}
