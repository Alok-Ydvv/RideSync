import 'package:flutter/material.dart';

/// RideSync color system (spec):
/// Green = safe/online/ready, Yellow = warning, Orange = attention,
/// Red = danger/SOS, Blue = info/nav, Gray = offline/inactive.
class AppColors {
  static const safe = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const attention = Color(0xFFF97316);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const offline = Color(0xFF6B7280);

  // Soft surfaces for section cards (lightweight, no extra deps).
  static const safeSoft = Color(0xFFE8F7EE);
  static const infoSoft = Color(0xFFEAF1FE);
  static const warnSoft = Color(0xFFFFF7E6);
  static const dangerSoft = Color(0xFFFDECEC);
  static const neutralSoft = Color(0xFFF1F3F5);
}

/// Lightweight, high-contrast Material 3 theme. No custom fonts or
/// extra packages — stock Roboto with M3 shape system reads well in sun.
class AppTheme {
  static final _filled = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(64, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.safe),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: _filled,
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        chipTheme: ChipThemeData(
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        listTileTheme: const ListTileThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14))),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.safe,
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2F38)),
          ),
          margin: EdgeInsets.zero,
        ),
        filledButtonTheme: _filled,
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,
        ),
      );
}
