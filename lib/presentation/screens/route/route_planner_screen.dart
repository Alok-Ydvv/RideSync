import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/ride_provider.dart';
import '../../../data/repositories/route_repository.dart';
import '../../../data/datasources/free_apis.dart';

/// Phase 1 map-based route planner (free tiles: OpenTopoMap).
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
  String? _loadedSavedName;
  bool _loadedSaved = false;

  @override
  void initState() {
    super.initState();
    // Auto-load a saved route selected during ride setup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadSaved());
  }

  Future<void> _maybeLoadSaved() async {
    if (_loadedSaved) return;
    final saved = ref.read(pendingSavedRouteProvider);
    if (saved == null) return;
    _loadedSaved = true;
    final wps = (saved['waypoints'] as List? ?? [])
        .map((e) => LatLng(
            (e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()))
        .toList();
    if (wps.length < 2) return;
    setState(() {
      _loadedSavedName = (saved['name'] ?? 'Route').toString();
      _start = wps.first;
      _stops
        ..clear()
        ..addAll(wps.sublist(1, wps.length - 1));
      _dest = wps.last;
    });
    ref.read(pendingSavedRouteProvider.notifier).state = null;
    await _compute();
  }

  Future<void> _saveRoute() async {
    if (_start == null || _dest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Plan a route first, then save it.')),
      );
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Save route'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'e.g. Delhi → Leh highway run'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Save')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    final wps = <LatLng>[_start!, ..._stops, _dest!];
    try {
      await RouteRepository().saveRoute(
        name: name,
        waypoints: wps
            .map((w) =>
                <String, double>{'lat': w.latitude, 'lng': w.longitude})
            .toList(),
        distanceMeters: (_info?['total_distance'] as num?)?.toDouble(),
        durationSeconds: (_info?['estimated_duration'] as num?)?.toInt(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "$name" to your routes.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

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
            icon: const Icon(Icons.bookmark_add),
            tooltip: 'Save route',
            onPressed: _saveRoute,
          ),
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
            child: Stack(
              children: [
                FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: const LatLng(28.6139, 77.2090),
                initialZoom: 11,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
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
                const Positioned(
                  bottom: 4,
                  right: 8,
                  child: Text('© OSM contributors · © SRTM · OpenTopoMap',
                      style: TextStyle(fontSize: 10, color: Colors.black54)),
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
                if (_loadedSavedName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      avatar: const Icon(Icons.bookmark, size: 16),
                      label: Text('Loaded saved route: $_loadedSavedName'),
                    ),
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
