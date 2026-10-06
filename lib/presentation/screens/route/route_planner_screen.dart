import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/ride_provider.dart';
import '../../../data/repositories/route_repository.dart';
import '../../../data/datasources/free_apis.dart';

/// Phase 1 map-based route planner (free tiles: Carto Voyager).
/// Tap the map to set Start / Stops / Destination, pick a preference,
/// then compute — route renders as a real polyline with distance, time,
/// fuel estimate. Works without Edge functions (falls to direct OSRM).
class RoutePlannerScreen extends ConsumerStatefulWidget {
  const RoutePlannerScreen({super.key});
  @override
  ConsumerState<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends ConsumerState<RoutePlannerScreen> {
  final _map = MapController();
  LatLng? _start;
  final List<LatLng> _stops = [];
  LatLng? _dest;
  String _mode = 'start'; // start | stop | dest
  String _pref = 'fastest';
  bool _busy = false;
  Map<String, dynamic>? _info;
  List<LatLng>? _poly;

  Future<void> _useGpsStart() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      setState(() => _start = LatLng(p.latitude, p.longitude));
      _map.move(LatLng(p.latitude, p.longitude), 13);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get GPS fix.')),
        );
      }
    }
  }

  void _onTap(TapPosition _, LatLng at) {
    setState(() {
      switch (_mode) {
        case 'start':
          _start = at;
          break;
        case 'stop':
          _stops.add(at);
          break;
        case 'dest':
          _dest = at;
          break;
      }
    });
  }

  void _clear() {
    setState(() {
      _start = null;
      _stops.clear();
      _dest = null;
      _info = null;
      _poly = null;
    });
  }

  Future<void> _compute() async {
    if (_start == null || _dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a start and destination on the map.')),
      );
      return;
    }
    final wps = <LatLng>[_start!, ..._stops, _dest!];
    setState(() => _busy = true);
    try {
      final rideId = ref.read(activeRideProvider)?.id ?? 'local';
      final info = await RouteRepository().getRoute(
        rideId: rideId,
        waypoints: wps
            .map((w) => <String, double>{'lat': w.latitude, 'lng': w.longitude})
            .toList(),
        pref: _pref,
      );
      final poly = info['encoded_polyline'] != null
          ? decodePolyline(info['encoded_polyline'] as String)
          : <LatLng>[];
      setState(() {
        _info = info;
        _poly = poly;
      });
      if (poly.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(poly);
        _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      }
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
    final theme = Theme.of(context);
    final vType = ref.watch(vehicleTypeProvider);
    final distKm = ((_info?['total_distance'] as num?) ?? 0) / 1000;
    final durMin = ((_info?['estimated_duration'] as num?) ?? 0) / 60;
    final mileage = vType == 'car' ? 15.0 : 40.0;
    final fuel = distKm / mileage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 320,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: const LatLng(28.6139, 77.2090),
                initialZoom: 11,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  // OSM Mapnik public tiles — no API key required.
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ridesync.ridesync',
                ),
                if (_poly != null && _poly!.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _poly!,
                        color: const Color(0xFF2563EB),
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_start != null)
                      Marker(
                        point: _start!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.trip_origin,
                            color: Colors.green, size: 32),
                      ),
                    for (var i = 0; i < _stops.length; i++)
                      Marker(
                        point: _stops[i],
                        width: 32,
                        height: 32,
                        child: const Icon(Icons.flag,
                            color: Colors.orange, size: 28),
                      ),
                    if (_dest != null)
                      Marker(
                        point: _dest!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 32),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Set Start'),
                      selected: _mode == 'start',
                      onSelected: (_) => setState(() => _mode = 'start'),
                    ),
                    ChoiceChip(
                      label: const Text('+ Stop'),
                      selected: _mode == 'stop',
                      onSelected: (_) => setState(() => _mode = 'stop'),
                    ),
                    ChoiceChip(
                      label: const Text('Set Destination'),
                      selected: _mode == 'dest',
                      onSelected: (_) => setState(() => _mode = 'dest'),
                    ),
                    ActionChip(
                      label: const Text('GPS start'),
                      onPressed: _useGpsStart,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fastest', label: Text('Fastest')),
                    ButtonSegment(value: 'shortest', label: Text('Shortest')),
                    ButtonSegment(value: 'notoll', label: Text('No toll')),
                  ],
                  selected: {_pref},
                  onSelectionChanged: (s) => setState(() => _pref = s.first),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : _compute,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.directions),
                  label: Text(_busy ? 'Routing…' : 'Compute route'),
                ),
                if (_info != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Distance  ${distKm.toStringAsFixed(1)} km\n'
                        'Time  ~${durMin.round()} min\n'
                        'Fuel  ~${fuel.toStringAsFixed(1)} L @ ${mileage.round()} kmpl\n'
                        '${_info!['estimated'] == true ? 'Offline estimate — syncs when online.' : _info!['cached'] == true ? 'Cached (shared to group).' : 'Fresh route (shared to group).'}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  Text(
                    'Pre-ride: offline tiles · weather strip · emergency contacts · members ready',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
