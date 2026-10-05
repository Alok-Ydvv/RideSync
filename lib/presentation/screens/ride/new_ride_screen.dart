import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/ride_models.dart';
import '../../../data/datasources/supabase_client.dart';
import 'group_lobby_screen.dart';

/// Step 1: Solo / Group. Step 2: Bike / Car (+Mixed for groups).
/// Then per-vehicle config: counts + passengers + pillion (spec).
class NewRideScreen extends ConsumerStatefulWidget {
  const NewRideScreen({super.key});
  @override
  ConsumerState<NewRideScreen> createState() => _NewRideScreenState();
}

class _NewRideScreenState extends ConsumerState<NewRideScreen> {
  final _name = TextEditingController(text: 'Weekend Ride');
  int _count = 3; // bikes or cars in group
  int _soloPax = 1;
  int _speed = 80;
  int _distAlert = 1000;
  bool _creating = false;
  static const _uuid = Uuid();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildSlots(String rideType, String vType) {
    if (rideType == 'solo') {
      final t = vType == 'car' ? 'car' : 'bike';
      return [
        {
          'vehicle_type': t,
          'max_passengers': _soloPax,
          'position': 1,
          'role': 'leader',
        }
      ];
    }
    // Group: leader=1, tail=last, rest middle. Mixed alternates bike/car.
    return List.generate(_count, (i) {
      final pos = i + 1;
      final role = pos == 1 ? 'leader' : (pos == _count ? 'tail' : 'middle');
      String t;
      if (vType == 'mixed') {
        t = pos.isOdd ? 'bike' : 'car';
      } else {
        t = vType;
      }
      return {
        'vehicle_type': t,
        'max_passengers': t == 'car' ? 4 : 1,
        'position': pos,
        'role': role,
      };
    });
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final rideType = ref.read(rideTypeProvider);
      final vType = ref.read(vehicleTypeProvider);
      final repo = ref.read(rideRepositoryProvider);
      final uid = ref.read(authRepositoryProvider).session?.user.id;
      final slots = _buildSlots(rideType, vType);

      if (hasBackend && uid != null) {
        final g = await repo.createGroup(
          name: _name.text.trim().isEmpty ? 'Ride' : _name.text.trim(),
          rideType: rideType,
          vehicleType: vType,
          leaderId: uid,
          maxSpeed: _speed,
          distanceAlert: _distAlert,
        );
        final vehicles = await repo.addVehicles(g.id, slots);
        // Leader drives vehicle #1 — no need to invite yourself.
        await repo.assignDriver(vehicles.first.id, uid);
        ref.read(currentGroupProvider.notifier).state = g;
        ref.read(vehiclesProvider.notifier).state =
            await repo.fetchVehicles(g.id);
      } else {
        // Offline fallback: local group so lobby/map demo works without .env.
        final g = GroupModel(
          id: _uuid.v4(),
          name: _name.text.trim().isEmpty ? 'Ride' : _name.text.trim(),
          inviteCode: (100000 + DateTime.now().millisecond % 900000).toString(),
          leaderId: 'local',
          rideType: rideType,
          vehicleType: vType,
          maxSpeedLimit: _speed,
          distanceAlertThreshold: _distAlert,
        );
        ref.read(currentGroupProvider.notifier).state = g;
        ref.read(vehiclesProvider.notifier).state = [
          for (var i = 0; i < slots.length; i++)
            VehicleModel(
              id: _uuid.v4(),
              groupId: g.id,
              vehicleType: slots[i]['vehicle_type'] as String,
              // Leader auto-drives slot #1 even offline.
              driverId: i == 0 ? 'local' : null,
              maxPassengers: slots[i]['max_passengers'] as int,
              position: slots[i]['position'] as int,
              role: slots[i]['role'] as String,
            ),
        ];
      }
      ref.read(pendingInvitesProvider.notifier).state = {};
      ref.read(readyVehiclesProvider.notifier).state = {};
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GroupLobbyScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Create failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideType = ref.watch(rideTypeProvider);
    final vType = ref.watch(vehicleTypeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Start New Ride')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _StepsHeader(),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Ride name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const Text('How are you travelling?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'solo', label: Text('🚶 Solo'), icon: Icon(Icons.person)),
              ButtonSegment(value: 'group', label: Text('👥 Group'), icon: Icon(Icons.groups)),
            ],
            selected: {rideType},
            onSelectionChanged: (s) =>
                ref.read(rideTypeProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 16),
          const Text('Select vehicle type',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'bike', label: Text('🏍️ Bike')),
              const ButtonSegment(value: 'car', label: Text('🚗 Car')),
              if (rideType == 'group')
                const ButtonSegment(value: 'mixed', label: Text('🏍️+🚗 Mixed')),
            ],
            selected: {vType},
            onSelectionChanged: (s) =>
                ref.read(vehicleTypeProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 16),
          if (rideType == 'solo') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(vType == 'car'
                    ? 'Passengers incl. driver (1-7)'
                    : 'Riders on bike (1-2)'),
                Row(
                  children: [
                    IconButton(
                      onPressed: _soloPax > 1
                          ? () => setState(() => _soloPax--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_soloPax',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: _soloPax < (vType == 'car' ? 7 : 2)
                          ? () => setState(() => _soloPax++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            const Text('Pillion/passenger name + phone can be added in lobby (emergency use).'),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(vType == 'car'
                    ? 'Total cars (1-10)'
                    : vType == 'mixed'
                        ? 'Total vehicles (2-20)'
                        : 'Total bikes (1-20)'),
                Row(
                  children: [
                    IconButton(
                      onPressed: _count > (vType == 'mixed' ? 2 : 1)
                          ? () => setState(() => _count--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_count',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    IconButton(
                      onPressed: _count < (vType == 'car' ? 10 : 20)
                          ? () => setState(() => _count++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _speed,
                  decoration: const InputDecoration(
                      labelText: 'Speed limit (km/h)',
                      border: OutlineInputBorder()),
                  items: [40, 60, 80, 100, 120]
                      .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
                      .toList(),
                  onChanged: (v) => setState(() => _speed = v ?? 80),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _distAlert,
                  decoration: const InputDecoration(
                      labelText: 'Gap alert', border: OutlineInputBorder()),
                  items: [500, 1000, 2000, 5000]
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(m >= 1000 ? '${m ~/ 1000}km' : '${m}m')))
                      .toList(),
                  onChanged: (v) => setState(() => _distAlert = v ?? 1000),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _creating ? null : _create,
            child: Text(_creating ? 'Creating…' : 'Create ride → Lobby'),
          ),
        ],
      ),
    );
  }
}

/// 1 Ride type · 2 Vehicle · 3 Setup — single-page wizard progress header.
class _StepsHeader extends StatelessWidget {
  const _StepsHeader();
  @override
  Widget build(BuildContext context) {
    const steps = ['1 · Ride', '2 · Vehicle', '3 · Setup'];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            const Expanded(child: Divider(thickness: 2, indent: 6, endIndent: 6)),
          Chip(
            avatar: CircleAvatar(
              radius: 10,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text('${i + 1}',
                  style: const TextStyle(fontSize: 11, color: Colors.white)),
            ),
            label: Text(steps[i].substring(4)),
          ),
        ],
      ],
    );
  }
}
