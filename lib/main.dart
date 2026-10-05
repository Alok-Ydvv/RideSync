import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/auth_gate.dart';
import 'presentation/providers/settings_provider.dart';

/// RideSync Phase 1 bootstrap.
/// Free-first: Supabase + FCM + flutter_map. No Mapbox/Agora/OneSignal.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Env is optional for UI-first dev (map/dashboard work without backend).
  // maybeGet throws NotInitializedError if load failed, so gate on the flag.
  var envReady = false;
  try {
    await dotenv.load(fileName: '.env');
    envReady = true;
  } catch (_) {
    debugPrint('RideSync: .env not found, running in offline UI mode.');
  }

  final url = envReady ? dotenv.maybeGet('SUPABASE_URL') : null;
  // supabase_flutter renamed anonKey → publishableKey. Accepts the new
  // SUPABASE_PUBLISHABLE_KEY, falls back to legacy SUPABASE_ANON_KEY.
  final pubKey = envReady
      ? dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY') ??
          dotenv.maybeGet('SUPABASE_ANON_KEY')
      : null;
  if (url != null && pubKey != null && url.startsWith('http')) {
    await Supabase.initialize(url: url, publishableKey: pubKey);
  } else {
    debugPrint('RideSync: SUPABASE_URL/KEY missing — backend disabled.');
  }

  // Guarded: firebase plugins auto-init the default app from
  // google-services.json when present; a second initializeApp throws
  // [core/duplicate-app] and trips the background-handler error.
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (_) {
    debugPrint('RideSync: Firebase not configured yet — push disabled.');
  }

  runApp(const ProviderScope(child: RideSyncApp()));
}

class RideSyncApp extends ConsumerWidget {
  const RideSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'RideSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: const [Locale('en'), Locale('hi')],
      home: const AuthGate(),
    );
  }
}
