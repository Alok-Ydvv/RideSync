import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Phase 1 live tracking state (free-first).
/// Leader position is real GPS; group members simulated as offsets in dev
/// (real multi-phone Broadcast lands with the same keys).
class VehiclePing {
  final String vehicleId;
  final LatLng at;
  final double speedKmh;
  final String role;
  final String vehicleType;
  const VehiclePing({
    required this.vehicleId,
    required this.at,
    this.speedKmh = 0,
    this.role = 'middle',
    this.vehicleType = 'bike',
  });
}

final livePingsProvider =
    StateProvider<Map<String, VehiclePing>>((ref) => {});
final trackingActiveProvider = StateProvider<bool>((ref) => false);
final overspeedIdsProvider = StateProvider<Set<String>>((ref) => {});
final gapAlertProvider = StateProvider<String?>((ref) => null);
final leaderRouteProvider = StateProvider<List<LatLng>>((ref) => []);
