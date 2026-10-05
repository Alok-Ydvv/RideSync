import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../ride/new_ride_screen.dart';
import '../ride/group_lobby_screen.dart';
import '../ride/active_ride_screen.dart';
import '../map/map_screen.dart';
import '../route/route_planner_screen.dart';
import '../nearby/nearby_screen.dart';
import '../chat/chat_screen.dart';
import '../history/history_screen.dart';
import '../sos/sos_screen.dart';
import '../settings/settings_screen.dart';
import '../safety/weather_strip.dart';
import '../../providers/ride_provider.dart';

/// Phase 1 Home Dashboard — all 11 spec screens wired.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(currentGroupProvider);
    final ride = ref.watch(activeRideProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('RideSync — Phase 1')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const WeatherStrip(),
          const SizedBox(height: 8),
          if (group != null)
            Card(
              color: ride != null
                  ? Colors.green.shade50
                  : Theme.of(context).cardColor,
              child: ListTile(
                leading: Icon(
                  ride != null ? Icons.radio_button_checked : Icons.timer,
                  color: ride != null ? Colors.green : Colors.orange,
                ),
                title: Text(group.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(ride != null
                    ? 'Ride ACTIVE · ${group.vehicleType} · tap to continue'
                    : 'Ride ready in lobby · tap to continue'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => ride != null
                          ? const ActiveRideScreen()
                          : const GroupLobbyScreen()),
                ),
              ),
            ),
          if (group != null) const SizedBox(height: 8),
          const Text('Quick actions',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _tile(context, 'Start New Ride', Icons.navigation, AppColors.safe,
              'Solo / Group → Bike / Car / Mixed',
              const NewRideScreen()),
          _tile(context, 'Group Lobby', Icons.groups, AppColors.info,
              group == null ? 'Create a ride first' : '${group.name} · ${group.inviteCode}',
              const GroupLobbyScreen()),
          _tile(context, 'Active Ride', Icons.play_circle, AppColors.safe,
              'Commands + history + map entry', const ActiveRideScreen()),
          _tile(context, 'Map View', Icons.map, AppColors.info,
              'All vehicles, Leader/Tail badges', const MapScreen()),
          _tile(context, 'Plan Route', Icons.route, AppColors.info,
              'Waypoints + fuel estimate', const RoutePlannerScreen()),
          _tile(context, 'Nearby Places', Icons.local_gas_station,
              AppColors.warning, 'Fuel, hospital, mechanic, ATM',
              const NearbyScreen()),
          _tile(context, 'Group Chat', Icons.chat, AppColors.info,
              'Text, photo, pin, voice note', const ChatScreen()),
          _tile(context, 'Ride History', Icons.history, AppColors.offline,
              'Playback 1x/2x/4x + stats', const HistoryScreen()),
          _tile(context, 'SOS', Icons.sos, AppColors.danger,
              'Always accessible, 10s cancel', const SosScreen()),
          _tile(context, 'Profile & Settings', Icons.person, AppColors.offline,
              'Contacts, vehicle, language EN/HI', const SettingsScreen()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.danger,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SosScreen()),
        ),
        icon: const Icon(Icons.sos),
        label: const Text('SOS'),
      ),
    );
  }

  Widget _tile(BuildContext context, String title, IconData icon, Color color,
      String sub, Widget dest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color, child: Icon(icon, color: Colors.white)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => dest),
        ),
      ),
    );
  }
}
