import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/supabase_client.dart';
import '../datasources/free_apis.dart';

/// Phase 1 POI + weather. Edge cache first (shared to the group, saves
/// free quota), direct free APIs as fallback so everything still works
/// when functions aren't deployed. Phones never hit Overpass/Open-Meteo
/// at 60fps — one fetch per tap/open.
class PoiRepository {
  Future<List<Map<String, dynamic>>> nearby({
    required double lat,
    required double lng,
    int radius = 5000,
    String category = 'fuel',
  }) async {
    final c = trySupabase();
    if (c != null) {
      try {
        final res = await c.functions.invoke('poi-cache', body: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
          'category': category,
        });
        final items = (res.data as Map)['items'] as List? ?? [];
        if (items.isNotEmpty) return items.cast<Map<String, dynamic>>();
      } catch (_) {
        // Fall through to direct API.
      }
    }
    return nearbyDirect(lat: lat, lng: lng, radius: radius, category: category);
  }

  Future<Map<String, dynamic>?> weather({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    final c = trySupabase();
    if (c != null) {
      try {
        final res = await c.functions.invoke('weather-cache', body: {
          'ride_id': rideId,
          'lat': lat,
          'lng': lng,
        });
        final j = (res.data as Map?)?.cast<String, dynamic>();
        if (j != null) return j;
      } catch (_) {
        // Fall through to direct API.
      }
    }
    return weatherDirect(lat, lng);
  }
}
