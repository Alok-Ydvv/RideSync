import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_provider.dart';
import '../../providers/ride_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/chat_models.dart';
import '../map/map_screen.dart';

/// Active Ride: map entry + leader command bar + fullscreen 3s alert +
/// vibration + history. Broadcast-first, DB-backed.
class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});
  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  Timer? _clear;

  Future<void> _send(String type) async {
    final ride = ref.read(activeRideProvider);
    final uid = ref.read(authRepositoryProvider).session?.user.id;
    // Local overlay always (works offline in demo).
    ref.read(activeCommandProvider.notifier).state = type;
    HapticFeedback.heavyImpact();
    _clear?.cancel();
    _clear = Timer(const Duration(seconds: 3), () {
      ref.read(activeCommandProvider.notifier).state = null;
    });
    if (ride == null || uid == null) return;
    try {
      await ref.read(chatRepositoryProvider).sendCommand(
            rideId: ride.id,
            senderId: uid,
            type: type,
          );
      final hist = await ref
          .read(chatRepositoryProvider)
          .fetchCommands(ride.id);
      ref.read(commandsProvider.notifier).state = hist;
    } catch (_) {
      // Offline: overlay + local history still shown.
      final local = LeaderCommand(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        rideId: ride.id,
        senderId: uid,
        type: type,
        sentAt: DateTime.now(),
      );
      ref.read(commandsProvider.notifier).state = [local, ...ref.read(commandsProvider)];
    }
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeCommandProvider);
    final hist = ref.watch(commandsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Active Ride')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MapScreen()),
                ),
                icon: const Icon(Icons.map),
                label: const Text('Open live map'),
              ),
              const SizedBox(height: 12),
              const Text('Leader commands',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in LeaderCommand.labels.entries)
                    FilledButton.tonal(
                      onPressed: () => _send(e.key),
                      child: Text(e.value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Command history',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              for (final c in hist)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.campaign),
                  title: Text(LeaderCommand.labels[c.type] ?? c.type),
                  subtitle: Text(c.sentAt.toLocal().toString()),
                ),
              if (hist.isEmpty)
                const Text('No commands yet this ride.'),
            ],
          ),
          if (active != null)
            Container(
              color: Colors.black87,
              alignment: Alignment.center,
              child: Text(
                LeaderCommand.labels[active] ?? active,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
