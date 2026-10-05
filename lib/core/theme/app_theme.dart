import 'package:flutter/material.dart';

/// RideSync color system (spec):
/// Green = safe/online/ready, Yellow = warning, Orange = attention,
/// Red = danger/SOS, Blue = info/nav, Gray = offline/inactive.
class AppColors {
  static const safe = Color(0xFF16A34A);
  static const warning = Color(0xFFEAB308);
  static const attention = Color(0xFFF97316);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const offline = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.safe),
        // Large touch targets for gloved/stationary use.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.safe,
          brightness: Brightness.dark,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
}
