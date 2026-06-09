import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'root_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import '../providers/notification_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3500), () {
      _navigateToNext();
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
      nextScreen = const RootScreen();
    } else {
      nextScreen = const LoginPage();
    }

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
                style: GoogleFonts.cairo(
                  color: const Color(0xFF1A1A2E),
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
                style: GoogleFonts.montserrat(
                  color: const Color(0xFF1A73E8),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 6.0,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
