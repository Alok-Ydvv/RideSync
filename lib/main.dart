import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/auth_gate.dart';

/// RideSync Phase 1 bootstrap.
/// Free-first: Supabase + FCM + flutter_map. No Mapbox/Agora/OneSignal.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Env is optional for UI-first dev (map/dashboard work without backend).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    debugPrint('RideSync: .env not found, running in offline UI mode.');
  }

  final url = dotenv.maybeGet('SUPABASE_URL');
  final anon = dotenv.maybeGet('SUPABASE_ANON_KEY');
  if (url != null && anon != null && url.startsWith('http')) {
    await Supabase.initialize(url: url, anonKey: anon);
  } else {
    debugPrint('RideSync: SUPABASE_URL/ANON_KEY missing — backend disabled.');
  }

  try {
    await Firebase.initializeApp();
  } catch (_) {
    debugPrint('RideSync: Firebase not configured yet — push disabled.');
  }

  runApp(const ProviderScope(child: RideSyncApp()));
}

class RideSyncApp extends StatelessWidget {
  const RideSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // System theme; Phase 1 supports light + dark.
      themeMode: ThemeMode.system,
      // EN + HI ready. Actual strings land with Phase 1 l10n pass.
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('hi')],
      home: const AuthGate(),
    );
  }
}
