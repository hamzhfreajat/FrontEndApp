import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'root_screen.dart';
import '../services/analytics_engine.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'Login');
  }

  bool _isLoadingGoogle = false;
  bool _isLoadingFacebook = false;
  bool _isLoadingApple = false;
  String? _errorMessage;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _isLoadingGoogle = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token from Google.');
      }

      // Send to backend
      final response = await ApiService().loginWithGoogle(idToken);
      final token = response['token'];

      if (!mounted) return;

      // Update auth provider
      await Provider.of<AuthProvider>(context, listen: false).login(token);

      // Navigate to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RootScreen()),
        (route) => false,
      );

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      // Optionally sign out from google if our backend rejected it to let them try another account easily
      await _googleSignIn.signOut();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGoogle = false;
        });
      }
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
        if (accessToken == null) {
          throw Exception('Failed to get access token from Facebook.');
        }

        // Send to backend
        final response = await ApiService().loginWithFacebook(accessToken);
        final token = response['token'];

        if (!mounted) return;

        // Update auth provider
        await Provider.of<AuthProvider>(context, listen: false).login(token);

        // Navigate to home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const RootScreen()),
          (route) => false,
        );
      } else if (result.status == LoginStatus.cancelled) {
        // User canceled
      } else {
        throw Exception(result.message ?? 'Facebook login failed');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      await FacebookAuth.instance.logOut();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFacebook = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoadingApple = true;
      _errorMessage = null;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          // Set your service ID here
          clientId: 'com.sooqcom.app.service',
          redirectUri: Uri.parse(
            'https://api.sooq-com.com/api/auth/apple/callback',
          ),
        ),
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Failed to get ID token from Apple.');
      }

      // Send to backend
      final response = await ApiService().loginWithApple(
        idToken,
        email: credential.email,
        firstName: credential.givenName,
        lastName: credential.familyName,
      );
      
      final token = response['token'];

      if (!mounted) return;

      // Update auth provider
      await Provider.of<AuthProvider>(context, listen: false).login(token);

      // Navigate to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RootScreen()),
        (route) => false,
      );

    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      setState(() {
        if (errorStr.contains('canceled') || errorStr.contains('cancelled') || errorStr.contains('1001')) {
          // User manually canceled the login flow
          _errorMessage = null; // Don't show a scary red error for cancellation
        } else if (errorStr.contains('invalid_client')) {
          _errorMessage = 'عذراً، ميزة تسجيل الدخول عبر آبل قيد المراجعة حالياً. يرجى المحاولة لاحقاً.';
        } else {
          _errorMessage = 'تعذر تسجيل الدخول بواسطة آبل. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingApple = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1A73E8);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Header Animation & Logo
                FadeInDown(
                  duration: const Duration(milliseconds: 800),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: brandBlue.withOpacity(0.12),
                            blurRadius: 30,
                            spreadRadius: 10,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: brandBlue.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/sooqcom_logo_v2.png',
                          height: 100,
                          width: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                
                // Greeting Texts
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 200),
                  child: const Text(
                    'تسجيل الدخول',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 300),
                  child: const Text(
                    'سجل دخولك باستخدام حساب جوجل للمتابعة بأمان',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Error Message
                if (_errorMessage != null) ...[
                  FadeIn(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Google Sign In Button
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 400),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isLoadingGoogle || _isLoadingFacebook || _isLoadingApple) ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF374151),
                        surfaceTintColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoadingGoogle
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: brandBlue, strokeWidth: 3))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Google Logo
                                Image.asset(
                                  'assets/images/google_logo.png',
                                  height: 24,
                                  width: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'المتابعة باستخدام Google',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                /*
                // Facebook Sign In Button
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 450),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1877F2).withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isLoadingGoogle || _isLoadingFacebook || _isLoadingApple) ? null : _handleFacebookSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1877F2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoadingFacebook
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.facebook, color: Colors.white, size: 26),
                                const SizedBox(width: 12),
                                const Text(
                                  'المتابعة باستخدام Facebook',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                */
                
                // Apple Sign In Button
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 470),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isLoadingGoogle || _isLoadingFacebook || _isLoadingApple) ? null : _handleAppleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoadingApple
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.apple, color: Colors.white, size: 28),
                                const SizedBox(width: 12),
                                const Text(
                                  'المتابعة باستخدام Apple',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 500),
                  child: const Text(
                    'بالاستمرار، أنت توافق على شروط الاستخدام وسياسة الخصوصية الخاصة بنا.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.6, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
