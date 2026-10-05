import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/ride_models.dart';
import 'active_ride_screen.dart';

/// Waiting room before ride starts. Slots: Empty → Invited → Confirmed → Ready.
/// Leader can invite (contacts/QR/6-digit/link), remove, mark ready, start ride.
/// Start creates the ride row + flips group to active so commands/SOS/history
/// all share one ride id.
class GroupLobbyScreen extends ConsumerStatefulWidget {
  const GroupLobbyScreen({super.key});
  @override
  ConsumerState<GroupLobbyScreen> createState() => _GroupLobbyScreenState();
}

class _GroupLobbyScreenState extends ConsumerState<GroupLobbyScreen> {
  static const _uuid = Uuid();
  bool _starting = false;

  Future<void> _inviteDialog(String vehicleId) async {
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite driver'),
        content: TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
              prefixText: '+91 ', hintText: '10-digit mobile'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (validatePhone(phone.text) != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(validatePhone(phone.text)!)));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Send invite')),
        ],
      ),
    );
    if (ok != true) return;
    final group = ref.read(currentGroupProvider);
    final uid = ref.read(authRepositoryProvider).session?.user.id;
    if (group == null) return;
    try {
      if (uid != null) {
        await ref.read(rideRepositoryProvider).createInvite(
              groupId: group.id,
              vehicleId: vehicleId,
              phone: phone.text.replaceAll(RegExp(r'\D'), ''),
              invitedBy: uid,
            );
      }
    } catch (_) {
      // Offline: still mark invited locally so demo flows.
    }
    ref.read(pendingInvitesProvider.notifier).state = {
      ...ref.read(pendingInvitesProvider),
      vehicleId,
    };
  }

  void _shareSheet() {
    final group = ref.read(currentGroupProvider);
    if (group == null) return;
    final link =
        'ridesync://join/${group.inviteCode} — Join "${group.name}"! Code: ${group.inviteCode} (24h).';
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: link, version: QrVersions.auto, size: 200),
            const SizedBox(height: 8),
            SelectableText('Code: ${group.inviteCode}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Share.share(link),
              icon: const Icon(Icons.share),
              label: const Text('Share via WhatsApp / SMS / …'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRide() async {
    setState(() => _starting = true);
    try {
      final group = ref.read(currentGroupProvider);
      if (group == null) return;
      final repo = ref.read(rideRepositoryProvider);
      try {
        final ride = await repo.createRide(group.id);
        await repo.setGroupStatus(group.id, 'active');
        ref.read(activeRideProvider.notifier).state = ride;
      } catch (_) {
        // Offline: local ride so commands/SOS/history still work in demo.
        ref.read(activeRideProvider.notifier).state = RideModel(
          id: _uuid.v4(),
          groupId: group.id,
          status: 'active',
        );
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ActiveRideScreen()),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'Ready':
        return Colors.green;
      case 'Confirmed':
        return Colors.blue;
      case 'Invited':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(currentGroupProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final pending = ref.watch(pendingInvitesProvider);
    final ready = ref.watch(readyVehiclesProvider);

    if (group == null) {
      return const Scaffold(
          body: Center(child: Text('Create a ride first.')));
    }
    final readyCount =
        vehicles.where((v) => v.driverId != null).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: _shareSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(
                  '${group.rideType.toUpperCase()} · ${group.vehicleType.toUpperCase()}'),
              subtitle: Text(
                  'Code ${group.inviteCode} · Limit ${group.maxSpeedLimit ?? '-'} km/h · Gap ${group.distanceAlertThreshold}m'),
              trailing: Chip(label: Text('$readyCount/${vehicles.length} ready')),
            ),
          ),
          const SizedBox(height: 8),
          for (final v in vehicles)
            Builder(builder: (context) {
              final state = v.slotState(
                  hasPendingInvite: pending.contains(v.id),
                  ready: ready.contains(v.id));
              return Card(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: _stateColor(state), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: _stateColor(state).withValues(alpha: 0.15),
                      child: Text(v.vehicleType == 'bike' ? '🏍' : '🚗')),
                  title: Text(
                      '#${v.position} ${v.role.toUpperCase()} · ${v.vehicleType}'),
                  subtitle: Text(
                    v.driverId != null ? '$state · driver set' : state,
                    style: TextStyle(
                        color: _stateColor(state),
                        fontWeight: FontWeight.w700),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (a) async {
                      if (a == 'invite') {
                        await _inviteDialog(v.id);
                      } else if (a == 'ready') {
                        ref.read(readyVehiclesProvider.notifier).state = {
                          ...ref.read(readyVehiclesProvider),
                          v.id,
                        };
                      } else if (a == 'remove') {
                        ref.read(readyVehiclesProvider.notifier).state =
                            Set<String>.from(
                                ref.read(readyVehiclesProvider))
                              ..remove(v.id);
                        ref.read(pendingInvitesProvider.notifier).state =
                            Set<String>.from(
                                ref.read(pendingInvitesProvider))
                              ..remove(v.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'invite', child: Text('Invite driver')),
                      PopupMenuItem(value: 'ready', child: Text('Mark ready')),
                      PopupMenuItem(value: 'remove', child: Text('Reset slot')),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _starting ? null : _startRide,
            icon: const Icon(Icons.play_arrow),
            label: Text(_starting ? 'Starting…' : 'Start ride → Active'),
          ),
        ],
      ),
    );
  }
}
