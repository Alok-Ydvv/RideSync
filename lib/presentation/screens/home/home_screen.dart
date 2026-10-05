import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

/// Phase 1 Home Dashboard — quick actions + entry to the 11 spec screens.
/// Screens land incrementally; this file is the nav skeleton.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      _HomeItem('Start New Ride', Icons.navigation, AppColors.safe, 'Solo / Group → Bike / Car / Mixed'),
      _HomeItem('Group Lobby', Icons.groups, AppColors.info, 'Slots, invites, ready states'),
      _HomeItem('Map View', Icons.map, AppColors.info, 'All vehicles, Leader/Tail badges'),
      _HomeItem('Nearby Places', Icons.local_gas_station, AppColors.warning, 'Fuel, hospital, mechanic, ATM'),
      _HomeItem('Group Chat', Icons.chat, AppColors.info, 'Text, photo, pin, voice note (P1)'),
      _HomeItem('Ride History', Icons.history, AppColors.offline, 'Playback 1x/2x/4x + stats'),
      _HomeItem('SOS', Icons.sos, AppColors.danger, 'Always accessible, 10s cancel'),
      _HomeItem('Profile & Settings', Icons.person, AppColors.offline, 'Contacts, vehicle, language EN/HI'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('RideSync — Phase 1')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final it = items[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: it.color, child: Icon(it.icon, color: Colors.white)),
              title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(it.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${it.title} lands in the next Phase 1 slice.')),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.danger,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS scaffold: triple-path (Broadcast + FCM + SMS) lands next.')),
          );
        },
        icon: const Icon(Icons.sos),
        label: const Text('SOS'),
      ),
    );
  }
}

class _HomeItem {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;
  _HomeItem(this.title, this.icon, this.color, this.subtitle);
}
