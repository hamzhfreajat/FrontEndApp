import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'root_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

import '../providers/notification_provider.dart';
import '../services/api_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isIOS) {
        try {
          await AppTrackingTransparency.requestTrackingAuthorization();
        } catch (e) {
          debugPrint('Error requesting ATT: $e');
        }
      }
      Future.delayed(const Duration(milliseconds: 3500), () {
        _navigateToNext();
      });
    });
  }

  void _navigateToNext() async {
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Wait explicitly if the auth provider is somehow still loading from SharedPreferences
    while (auth.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    // Check for updates
    try {
      final versionInfo = await ApiService().fetchAppVersionInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      String latestVersion = versionInfo['latest_ios'] ?? currentVersion;
      String testflightUrl = versionInfo['testflight_url'] ?? '';

      if (Platform.isIOS && _isVersionOlder(currentVersion, latestVersion)) {
        // Show update dialog
        bool shouldUpdate = await _showUpdateDialog(latestVersion, testflightUrl);
        if (shouldUpdate) {
          final uri = Uri.parse(testflightUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      print('Failed to check for updates: $e');
    }

    if (!mounted) return;

    Widget nextScreen;

    if (auth.isAuthenticated) {
      final userId = auth.userData?['sub'];
      if (userId != null) {
        final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
        if (!notifProvider.isConnected) {
          final uid = int.tryParse(userId.toString());
          if (uid != null) {
            notifProvider.connect(uid);
            notifProvider.loadUnreadCount();
          }
        }
      }
    }
    
    // Apple App Review (Guideline 5.1.1): Allow guests to browse without forcing login
    nextScreen = const RootScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  bool _isVersionOlder(String current, String latest) {
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int l = i < latestParts.length ? latestParts[i] : 0;
      if (c < l) return true;
      if (c > l) return false;
    }
    return false;
  }

  Future<bool> _showUpdateDialog(String latestVersion, String url) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تحديث جديد متاح 🎉', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text(
            'يتوفر إصدار جديد ($latestVersion) من التطبيق. يرجى التحديث من TestFlight للحصول على أحدث الميزات والإصلاحات.',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('لاحقاً', style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('تحديث الآن', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA), // App background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Elegant Zoom-in for the new premium logo
            ZoomIn(
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutBack,
              child: Image.asset(
                'assets/images/sooqcom_logo_v2.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            // Bold Arabic Name fading up
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              duration: const Duration(milliseconds: 800),
              child: Text(
                'سوقكم',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w900,
                  fontSize: 48,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Sleek Corporate English Name fading up
            FadeInUp(
              delay: const Duration(milliseconds: 900),
              duration: const Duration(milliseconds: 800),
              child: Text(
                'SOOQCOM',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  color: Color(0xFF1A73E8),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 3.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
