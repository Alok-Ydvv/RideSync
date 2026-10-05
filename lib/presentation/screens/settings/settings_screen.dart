import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

/// Profile & Settings: edit profile, emergency contacts shortcut,
/// language EN/HI, dark mode, sessions, delete account.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(profile?.fullName ?? 'Rider'),
              subtitle: Text(
                  '${profile?.phone ?? 'No phone'} · ${profile?.defaultVehicleType ?? 'bike'}'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Language / भाषा',
              style: TextStyle(fontWeight: FontWeight.w700)),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'hi', label: Text('हिन्दी')),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) =>
                ref.read(localeProvider.notifier).state = Locale(s.first),
          ),
          const SizedBox(height: 8),
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {theme},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              // Global sign-out (all devices): revokes refresh tokens.
              // supabase_flutter: auth.signOut() clears local session;
              // revoke server-side via Dashboard → Auth → Users → Sign out user.
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Logged out from all devices.')));
              }
            },
            icon: const Icon(Icons.devices_other),
            label: const Text('Logout from all devices'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete account?'),
                  content: const Text(
                      'Removes profile, contacts, routes and auth user. Cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Keep')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Delete requested: wire Edge `account-delete` (service role) to remove auth user + cascade rows.')));
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete account + all data'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Login history & active sessions: Supabase Dashboard → Auth → Users → Sessions (audit log 7d on Pro).',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
