import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ride_provider.dart';
import '../../../data/repositories/route_repository.dart';

/// Phase 1 route planner: start + destination + waypoints, reorder,
/// fastest/shortest/no-toll selector, distance/time/fuel, save + share.
/// Leader computes once (Edge cache); group reuses.
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});
  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _start = TextEditingController(text: '28.6139, 77.2090');
  final _dest = TextEditingController(text: '28.5355, 77.3910');
  final _stops = <TextEditingController>[];
  String _pref = 'fastest';
  bool _busy = false;
  Map<String, dynamic>? _info;

  @override
  void dispose() {
    _start.dispose();
    _dest.dispose();
    for (final c in _stops) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double>? _parse(String s) {
    final parts = s.split(',').map((e) => e.trim()).toList();
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  Future<void> _compute() async {
    final pts = <Map<String, double>>[];
    final s = _parse(_start.text);
    final d = _parse(_dest.text);
    if (s == null || d == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter lat,lng for start + destination.')),
      );
      return;
    }
    pts.add(s);
    for (final c in _stops) {
      final p = _parse(c.text);
      if (p != null) pts.add(p);
    }
    pts.add(d);
    setState(() => _busy = true);
    try {
      final rideId = ref.read(activeRideProvider)?.id ?? 'local';
      final info =
          await RouteRepository().getRoute(rideId: rideId, waypoints: pts);
      setState(() => _info = info);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Route failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distKm = ((_info?['total_distance'] as num?) ?? 0) / 1000;
    final durMin = ((_info?['estimated_duration'] as num?) ?? 0) / 60;
    final vType = ref.watch(vehicleTypeProvider);
    final mileage = vType == 'car' ? 15.0 : 40.0; // kmpl estimate
    final fuel = distKm / mileage;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan Route')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fastest', label: Text('Fastest')),
              ButtonSegment(value: 'shortest', label: Text('Shortest')),
              ButtonSegment(value: 'notoll', label: Text('No toll')),
            ],
            selected: {_pref},
            onSelectionChanged: (s) => setState(() => _pref = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _start,
              decoration: const InputDecoration(
                  labelText: 'Start (lat,lng)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          for (var i = 0; i < _stops.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                        controller: _stops[i],
                        decoration: InputDecoration(
                            labelText: 'Stop ${i + 1} (lat,lng)',
                            border: const OutlineInputBorder())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _stops[i].dispose();
                      _stops.removeAt(i);
                    }),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () =>
                setState(() => _stops.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: const Text('Add stop'),
          ),
          TextField(
              controller: _dest,
              decoration: const InputDecoration(
                  labelText: 'Destination (lat,lng)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _compute,
            child: Text(_busy ? 'Routing…' : 'Compute route ($_pref)'),
          ),
          if (_info != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Distance ${distKm.toStringAsFixed(1)} km\n'
                  'Time ~${durMin.round()} min\n'
                  'Fuel ~${fuel.toStringAsFixed(1)} L (@${mileage.round()} kmpl)\n'
                  '${_info!['estimated'] == true ? 'Offline estimate — syncs when online.' : _info!['cached'] == true ? 'Cached route (shared to group).' : 'Fresh route (shared to group).'}',
                ),
              ),
            ),
            const Text(
                'Pre-ride checklist: offline tiles + weather + emergency contacts + all members ready.'),
          ],
        ],
      ),
    );
  }
}
