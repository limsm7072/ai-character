import 'package:flutter/material.dart';

/// Toss-style color system
/// - Main: Teal/Mint
/// - Sub: Yellow/Gold (accent)
/// - Neutral: White / Grey / Black
/// - Semantic: Green(success), Red(error/danger), Orange→Gold(warning)
class AppColors {
  AppColors._();

  // ─── Main (Teal/Mint) ─────────────────────────
  static const Color primary = Color(0xFF009688);       // teal 500
  static const Color primaryLight = Color(0xFF4DB6AC);  // teal 300
  static const Color primaryDark = Color(0xFF00796B);   // teal 700
  static const Color primaryBg = Color(0xFFE0F2F1);     // teal 50

  // ─── Sub (Yellow/Gold) ────────────────────────
  static const Color accent = Color(0xFFFFC107);        // amber 500
  static const Color accentLight = Color(0xFFFFD54F);   // amber 300
  static const Color accentDark = Color(0xFFFFA000);    // amber 700
  static const Color accentBg = Color(0xFFFFF8E1);      // amber 50

  // ─── Neutral ──────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  static const Color black = Color(0xFF000000);
  static const Color black87 = Color(0xDD000000);

  // ─── Semantic ─────────────────────────────────
  static const Color success = Color(0xFF4CAF50);       // green 500
  static const Color successLight = Color(0xFFC8E6C9);  // green 100
  static const Color successMid = Color(0xFF66BB6A);    // green 400
  static const Color successDark = Color(0xFF388E3C);   // green 700
  static const Color successBg = Color(0xFFE8F5E9);     // green 50

  static const Color error = Color(0xFFF44336);         // red 500
  static const Color errorLight = Color(0xFFEF9A9A);    // red 200
  static const Color errorMid = Color(0xFFEF5350);      // red 400
  static const Color errorDark = Color(0xFFD32F2F);     // red 700
  static const Color errorBg = Color(0xFFFFEBEE);       // red 50

  static const Color warning = Color(0xFFFFA000);       // amber 700
  static const Color warningLight = Color(0xFFFFCC80);  // orange 200
  static const Color warningBg = Color(0xFFFFF3E0);     // orange 50

  static const Color info = Color(0xFF2196F3);          // blue 500
  static const Color infoLight = Color(0xFF90CAF9);     // blue 200
  static const Color infoDark = Color(0xFF1976D2);      // blue 700

  // ─── Chart palette ────────────────────────────
  static const List<Color> chartColors = [
    Color(0xFFF44336), // red
    Color(0xFF2196F3), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFF9800), // orange
    Color(0xFF9C27B0), // purple
    Color(0xFF009688), // teal
    Color(0xFFE91E63), // pink
    Color(0xFF3F51B5), // indigo
  ];

  // ─── Sleep chart ──────────────────────────────
  static const Color sleepDeep = Color(0xFF283593);     // indigo 800
  static const Color sleepRem = Color(0xFF42A5F5);      // blue 400
  static const Color sleepLight = Color(0xFF81D4FA);    // lightBlue 200

  // ─── Calendar ─────────────────────────────────
  static const Color calendarToday = Color(0xFF00796B); // teal 700 (= primaryDark)
  static const Color calendarSelected = Color(0xFFFF6D00); // deepOrange accent 400
  static const Color calendarHoliday = Color(0xFFE53935); // red 600
  static const Color calendarLunar = Color(0xFF7B1FA2);   // purple 700

  // ─── Heatmap ──────────────────────────────────
  static const Color heatmapEmpty = Color(0x14000000);  // ~8% black
  static const Color heatmapSkip = Color(0xFFFFCC80);   // orange 200
  static const Color heatmapFull = Color(0xFF66BB6A);   // green 400
  static const Color heatmapPartial = Color(0xFFA5D6A7);// green 200
  static const Color heatmapLow = Color(0xFFC8E6C9);    // green 100
  static const Color heatmapMiss = Color(0xFFFFCDD2);   // red 100

  // ─── Emotion colors (character widget) ────────
  static const Color emotionHappy = Color(0xFFFFC107);
  static const Color emotionAngry = Color(0xFFEF5350);
  static const Color emotionSad = Color(0xFF64B5F6);
  static const Color emotionSurprised = Color(0xFFFF9800);
  static const Color emotionAnnoyed = Color(0xFFFF8A65);
  static const Color emotionDisappointed = Color(0xFF78909C);
  static const Color emotionScolding = Color(0xFFE53935);
  static const Color emotionProud = Color(0xFF4CAF50);
  static const Color emotionWorried = Color(0xFFCE93D8);
  static const Color emotionDefault = Color(0xFF009688);

  // ─── Misc ─────────────────────────────────────
  static const Color trophy = Color(0xFFFFD54F);        // amber 300
  static const Color streak = Color(0xFFFF6D00);        // deepOrange accent 400
}
