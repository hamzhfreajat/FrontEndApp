// frontend/lib/features/chat/presentation/widgets/chat_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatTheme {
  static const Color accentColLight = Color(0xFF0075FF); 
  static const Color accentColDark = Color(0xFF0A84FF);
  
  static const Color bubbleOtherLight = Color(0xFFF0F2F5);
  static const Color bubbleOtherDark = Color(0xFF242526);

  static const double borderRadius = 24.0;

  // Premium Chat Bubble Gradient
  static LinearGradient primaryGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark 
        ? [const Color(0xFF0A84FF), const Color(0xFF005FCC)]
        : [const Color(0xFF0075FF), const Color(0xFF005FCC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Premium Scaffold Background
  static BoxDecoration scaffoldBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF0B141A) : Colors.white,
    );
  }

  static TextStyle font(BuildContext context, {double size = 15, FontWeight weight = FontWeight.w600, Color? color, double? height, double? letterSpacing}) {
    return GoogleFonts.tajawal(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF141414).withOpacity(0.65) : Colors.white.withOpacity(0.75),
      border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.04))),
    );
  }

  static List<BoxShadow> ultraSoftShadows() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 24,
        spreadRadius: 0,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF0075FF).withOpacity(0.03),
        blurRadius: 32,
        spreadRadius: 4,
        offset: const Offset(0, 12),
      )
    ];
  }
}
