import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/supabase_client.dart';

/// Phase 1 history: past rides + basic stats (totals). Filters in UI.
class HistoryRepository {
  SupabaseClient? get _c => trySupabase();

  Future<List<Map<String, dynamic>>> fetchRides({int limit = 50}) async {
    final c = _c;
    if (c == null) return [];
    try {
      final res = await c
          .from('rides')
          .select('id, group_id, status, total_distance, total_duration, actual_start_time, actual_end_time, groups(name, ride_type, vehicle_type)')
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchStats() async {
    final c = _c;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) {
      return {'total_rides': 0, 'total_distance': 0, 'total_duration': 0};
    }
    try {
      final res = await c
          .from('ride_statistics')
          .select()
          .eq('user_id', uid)
          .order('updated_at', ascending: false)
          .limit(12);
      var rides = 0;
      double dist = 0;
      var dur = 0;
      for (final r in (res as List)) {
        rides += ((r as Map)['total_rides'] as int? ?? 0);
        dist += ((r['total_distance'] as num?) ?? 0).toDouble();
        dur += (r['total_duration'] as int? ?? 0);
      }
      return {'total_rides': rides, 'total_distance': dist, 'total_duration': dur};
    } catch (_) {
      return {'total_rides': 0, 'total_distance': 0, 'total_duration': 0};
    }
  }
}
