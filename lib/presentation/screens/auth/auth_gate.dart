import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../../data/datasources/supabase_client.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

/// Routes: offline-dev (no .env) → Home; logged-out → Login;
/// logged-in without profile row → ProfileSetup; else → Home.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasBackend) return const HomeScreen(); // UI-first dev mode

    final sessionAsync = ref.watch(sessionProvider);
    return sessionAsync.when(
      data: (authState) {
        if (authState.session == null) return const LoginScreen();
        return ref.watch(profileProvider).when(
              data: (profile) =>
                  profile == null ? const ProfileSetupScreen() : const HomeScreen(),
              loading: () => const _Splash('Loading profile…'),
              error: (e, s) => const HomeScreen(),
            );
      },
      loading: () => const _Splash('Checking session…'),
      error: (e, s) => const LoginScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  final String label;
  const _Splash(this.label);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}
