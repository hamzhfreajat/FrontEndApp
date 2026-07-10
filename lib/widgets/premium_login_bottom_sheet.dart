import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../services/analytics_engine.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../providers/notification_provider.dart';

class PremiumLoginBottomSheet extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final String title;
  final String subtitle;

  const PremiumLoginBottomSheet({
    super.key,
    required this.onLoginSuccess,
    this.title = 'تسجيل الدخول',
    this.subtitle = 'سجل الدخول للمتابعة واستخدام الميزات الكاملة',
  });

  static void show(BuildContext context, {required VoidCallback onLoginSuccess, String? title, String? subtitle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumLoginBottomSheet(
        onLoginSuccess: onLoginSuccess,
        title: title ?? 'تسجيل الدخول',
        subtitle: subtitle ?? 'سجل الدخول للمتابعة واستخدام الميزات الكاملة',
      ),
    );
  }

  @override
  State<PremiumLoginBottomSheet> createState() => _PremiumLoginBottomSheetState();
}

class _PremiumLoginBottomSheetState extends State<PremiumLoginBottomSheet> {
  bool _isLoadingGoogle = false;
  bool _isLoadingFacebook = false;
  bool _isLoadingApple = false;
  String? _errorMessage;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _handleSuccess(String token) async {
    if (!mounted) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.login(token);
    
    if (mounted) {
      final userId = auth.userData?['sub'];
      if (userId != null) {
        final uid = int.tryParse(userId.toString());
        if (uid != null) {
          final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
          notifProvider.connect(uid);
          notifProvider.loadUnreadCount();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدخول بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Close the bottom sheet
    }
    
    widget.onLoginSuccess(); // Trigger original action
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoadingGoogle = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) throw Exception('Failed to get ID token from Google.');

      final response = await ApiService().loginWithGoogle(idToken);
      await _handleSuccess(response['token']);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      await _googleSignIn.signOut();
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() {
      _isLoadingFacebook = true;
      _errorMessage = null;
    });

    try {
      final LoginResult result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
      
      if (result.status == LoginStatus.success) {
        final accessToken = result.accessToken?.tokenString;
        if (accessToken == null) throw Exception('Failed to get access token from Facebook.');

        final response = await ApiService().loginWithFacebook(accessToken);
        await _handleSuccess(response['token']);
      } else if (result.status == LoginStatus.cancelled) {
        // User canceled
      } else {
        throw Exception(result.message ?? 'Facebook login failed');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      await FacebookAuth.instance.logOut();
    } finally {
      if (mounted) setState(() => _isLoadingFacebook = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoadingApple = true;
      _errorMessage = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.sooqcom.app.service',
          redirectUri: Uri.parse('https://api.sooq-com.com/api/auth/apple/callback'),
        ),
      );

      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('Failed to get ID token from Apple.');

      final response = await ApiService().loginWithApple(
        idToken,
        firstName: credential.givenName,
        lastName: credential.familyName,
      );
      await _handleSuccess(response['token']);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingApple = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1A73E8);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: brandBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded, size: 48, color: brandBlue),
              ),
            ),
            const SizedBox(height: 16),
            
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Text(
                widget.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 8),
            
            FadeInUp(
              duration: const Duration(milliseconds: 700),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
              ),
            ),
            const SizedBox(height: 32),

            if (_errorMessage != null)
              FadeIn(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                    ],
                  ),
                ),
              ),

            // Google
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isLoadingGoogle || _isLoadingFacebook || _isLoadingApple) ? null : _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                    elevation: 0,
                  ),
                  child: _isLoadingGoogle
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: brandBlue, strokeWidth: 3))
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/google_logo.png', height: 24, width: 24),
                              const SizedBox(width: 12),
                              const Text('المتابعة باستخدام Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            // Apple
              FadeInUp(
                duration: const Duration(milliseconds: 1000),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_isLoadingGoogle || _isLoadingFacebook || _isLoadingApple) ? null : _handleAppleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoadingApple
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const FaIcon(FontAwesomeIcons.apple, size: 24, color: Colors.white),
                                const SizedBox(width: 12),
                                const Text('المتابعة باستخدام Apple', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
