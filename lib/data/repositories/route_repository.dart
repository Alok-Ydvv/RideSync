import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/supabase_client.dart';

/// Phase 1 route repo: leader computes once via Edge `route-cache` (OSRM),
/// result shared to group via ride_routes. Offline fallback: straight-line
/// estimate so UI never blocks (syncs later).
class RouteRepository {
  Future<Map<String, dynamic>> getRoute({
    required String rideId,
    required List<Map<String, double>> waypoints,
  }) async {
    final c = trySupabase();
    if (c == null) return _estimate(waypoints);
    try {
      final res = await c.functions.invoke('route-cache', body: {
        'ride_id': rideId,
        'waypoints':
            waypoints.map((w) => {'lat': w['lat'], 'lng': w['lng']}).toList(),
      });
      return (res.data as Map).cast<String, dynamic>();
    } on FunctionException {
      return _estimate(waypoints);
    } catch (_) {
      return _estimate(waypoints);
    }
  }

  Map<String, dynamic> _estimate(List<Map<String, double>> wps) {
    double dist = 0;
    for (var i = 1; i < wps.length; i++) {
      final dLat = (wps[i]['lat']! - wps[i - 1]['lat']!) * 111320;
      final dLng = (wps[i]['lng']! - wps[i - 1]['lng']!) * 111320 * 0.8;
      dist += (dLat * dLat + dLng * dLng);
    }
    dist = dist <= 0 ? 0 : _sqrt(dist);
    return {
      'total_distance': dist, // meters
      'estimated_duration': (dist / 13.9).round(), // ~50km/h
      'estimated': true,
    };
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (var i = 0; i < 10; i++) {
      g = (g + x / g) / 2;
    }
    return g;
  }
}
