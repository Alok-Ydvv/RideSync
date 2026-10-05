import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Phase 1 settings state: theme + locale. Persist via SharedPreferences
/// in the next slice; in-memory for now (survives session).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));
