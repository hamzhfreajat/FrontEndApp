import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({Key? key}) : super(key: key);

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2993417564924380/4129879862'
      : 'ca-app-pub-2993417564924380/7271314451';

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
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('$NativeAd failed to load: $error');
          ad.dispose();
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
          backgroundColor: const Color(0xFF2E3B5C), // Premium deep blue
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black87,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey.shade600,
          style: NativeTemplateFontStyle.normal,
          size: 13.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey.shade500,
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
    if (!_isAdLoaded) {
      return const SizedBox(height: 0); // Hide until loaded
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 8.0, bottom: 2.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        'إعلان ممول',
                        style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 4.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 320,
                minHeight: 120, // Small template needs around 90-120dp height
                maxWidth: 400,
                maxHeight: 140,
              ),
              child: AdWidget(ad: _nativeAd!),
            ),
          ),
        ],
      ),
    );
  }
}
