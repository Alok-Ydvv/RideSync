import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/supabase_client.dart';

/// Phase 1 POI + weather via Edge cache (free-tier safe).
/// Phones never call Overpass/Open-Meteo directly.
class PoiRepository {
  Future<List<Map<String, dynamic>>> nearby({
    required double lat,
    required double lng,
    int radius = 5000,
    String category = 'fuel',
  }) async {
    final c = trySupabase();
    if (c == null) return [];
    try {
      final res = await c.functions.invoke('poi-cache', body: {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'category': category,
      });
      final items = (res.data as Map)['items'] as List? ?? [];
      return items.cast<Map<String, dynamic>>();
    } on FunctionException {
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> weather({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    final c = trySupabase();
    if (c == null) return null;
    try {
      final res = await c.functions.invoke('weather-cache', body: {
        'ride_id': rideId,
        'lat': lat,
        'lng': lng,
      });
      return (res.data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}
