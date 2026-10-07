import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../providers/ride_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/location/location_service.dart';

/// Phase 1 Map View: all vehicles with bike/car icons, Leader/Tail badges,
/// speed, gap alerts, overspeed flags, zoom-to-fit. Free tiles: OSM.
/// Offline: cached tiles + last-known pings stay visible.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  final _loc = LocationService();
  StreamSubscription<Position>? _gps;
  Timer? _sim;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    ref.read(trackingActiveProvider.notifier).state = true;
    final blocked = await LocationService.ensurePermission();
    if (blocked != null) {
      if (blocked.contains('App Settings')) {
        await Geolocator.openAppSettings();
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(blocked)));
      }
    }
    try {
      await _loc.start(moving: true, inBackground: false);
    } catch (_) {
      // No fix — demo seed below keeps the map demonstrable.
    }
    _gps = _loc.positions.listen(_onLeader);
    // Dev simulator: other vehicles trail the leader with fixed offsets.
    _sim = Timer.periodic(const Duration(seconds: 10), (_) {
      final pings = Map<String, VehiclePing>.from(ref.read(livePingsProvider));
      if (pings.isEmpty) {
        _seedDemo();
        return;
      }
      ref.read(livePingsProvider.notifier).state = pings;
      _checkGaps(pings);
    });
    _seedDemo();
  }

  void _seedDemo() {
    final vehicles = ref.read(vehiclesProvider);
    if (vehicles.isEmpty) return;
    const base = LatLng(28.6139, 77.2090); // Delhi default for demo
    final pings = <String, VehiclePing>{};
    for (var i = 0; i < vehicles.length; i++) {
      final v = vehicles[i];
      pings[v.id] = VehiclePing(
        vehicleId: v.id,
        at: LatLng(base.latitude - i * 0.004, base.longitude + i * 0.002),
        speedKmh: 45 + (i * 7) % 30,
        role: v.role,
        vehicleType: v.vehicleType,
      );
    }
    ref.read(livePingsProvider.notifier).state = pings;
    _checkGaps(pings);
  }

  void _onLeader(Position p) {
    final vehicles = ref.read(vehiclesProvider);
    final pings = Map<String, VehiclePing>.from(ref.read(livePingsProvider));
    final speedKmh = (p.speed * 3.6).clamp(0, 200).toDouble();
    if (vehicles.isEmpty) {
      pings['leader'] = VehiclePing(
        vehicleId: 'leader',
        at: LatLng(p.latitude, p.longitude),
        speedKmh: speedKmh,
        role: 'leader',
      );
    } else {
      final lead = vehicles.first;
      pings[lead.id] = VehiclePing(
        vehicleId: lead.id,
        at: LatLng(p.latitude, p.longitude),
        speedKmh: speedKmh,
        role: lead.role,
        vehicleType: lead.vehicleType,
      );
      // Simulate followers behind leader for single-phone demo.
      for (var i = 1; i < vehicles.length; i++) {
        final v = vehicles[i];
        final prev = pings[v.id]?.at ??
            LatLng(p.latitude - i * 0.004, p.longitude + i * 0.002);
        pings[v.id] = VehiclePing(
          vehicleId: v.id,
          at: prev,
          speedKmh: (speedKmh - i * 3).clamp(0, 200).toDouble(),
          role: v.role,
          vehicleType: v.vehicleType,
        );
      }
    }
    ref.read(livePingsProvider.notifier).state = pings;
    _checkOverspeed(pings);
    _checkGaps(pings);
  }

  void _checkOverspeed(Map<String, VehiclePing> pings) {
    final group = ref.read(currentGroupProvider);
    final limit = (group?.maxSpeedLimit ?? 80) + 10; // default +10 tolerance
    final over = <String>{};
    for (final e in pings.entries) {
      if (e.value.speedKmh > limit) over.add(e.key);
    }
    ref.read(overspeedIdsProvider.notifier).state = over;
  }

  void _checkGaps(Map<String, VehiclePing> pings) {
    final group = ref.read(currentGroupProvider);
    final threshold = group?.distanceAlertThreshold ?? 1000;
    if (pings.length < 2) {
      ref.read(gapAlertProvider.notifier).state = null;
      return;
    }
    final pts = pings.values.map((e) => e.at).toList();
    double maxGap = 0;
    for (var i = 1; i < pts.length; i++) {
      final g = haversineMeters(pts[0].latitude, pts[0].longitude,
          pts[i].latitude, pts[i].longitude);
      if (g > maxGap) maxGap = g;
    }
    ref.read(gapAlertProvider.notifier).state =
        maxGap > threshold ? 'Gap ${maxGap.round()}m > ${threshold}m' : null;
  }

  void _fitAll() {
    final pings = ref.read(livePingsProvider).values.toList();
    if (pings.isEmpty) return;
    double minLat = pings.first.at.latitude,
        maxLat = pings.first.at.latitude,
        minLng = pings.first.at.longitude,
        maxLng = pings.first.at.longitude;
    for (final p in pings) {
      if (p.at.latitude < minLat) minLat = p.at.latitude;
      if (p.at.latitude > maxLat) maxLat = p.at.latitude;
      if (p.at.longitude < minLng) minLng = p.at.longitude;
      if (p.at.longitude > maxLng) maxLng = p.at.longitude;
    }
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
      padding: const EdgeInsets.all(60),
    ));
  }

  @override
  void dispose() {
    _gps?.cancel();
    _sim?.cancel();
    _loc.dispose();
    // NOTE: don't mutate providers in dispose — Riverpod rebuilds listeners
    // during tree teardown and trips a defunct-element assertion.
    super.dispose();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'leader':
        return Colors.green;
      case 'tail':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pings = ref.watch(livePingsProvider).values.toList();
    final gap = ref.watch(gapAlertProvider);
    final over = ref.watch(overspeedIdsProvider);
    final center = pings.isEmpty ? const LatLng(28.6139, 77.2090) : pings.first.at;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        actions: [
          IconButton(
              icon: const Icon(Icons.fit_screen), onPressed: _fitAll),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                // OpenTopoMap — free, no key, styled for road trips
                // (hillshade + road emphasis). Attribution required.
                urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.ridesync.ridesync',
              ),
              MarkerLayer(
                markers: [
                  for (final p in pings)
                    Marker(
                      point: p.at,
                      width: 90,
                      height: 70,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: over.contains(p.vehicleId)
                                  ? Colors.red
                                  : _roleColor(p.role),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${p.vehicleType == 'bike' ? '🏍' : '🚗'} ${p.role} · ${p.speedKmh.round()}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (gap != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('⚠️ $gap',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          Positioned(
            bottom: over.isNotEmpty ? 76 : 16,
            left: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                child: Text(
                  '🟢 Leader  🔵 Middle  🟠 Tail  🔴 Overspeed',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 4,
            right: 8,
            child: Text('© OpenStreetMap contributors · © SRTM · OpenTopoMap',
                style: TextStyle(fontSize: 10, color: Colors.black54)),
          ),
          if (over.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('🚨 Overspeed: ${over.length} vehicle(s)',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recenter',
        mini: true,
        onPressed: () {
          if (pings.isNotEmpty) {
            _map.move(pings.first.at, 15);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
