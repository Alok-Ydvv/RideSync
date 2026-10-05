import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../datasources/supabase_client.dart';
import '../models/ride_models.dart';
import '../../core/errors/failures.dart';

/// Phase 1 ride repository. Writes go to Supabase when configured,
/// otherwise throw NetworkFailure so UI falls back to local lobby state.
class RideRepository {
  static const _uuid = Uuid();

  SupabaseClient get _c {
    final c = trySupabase();
    if (c == null) throw const NetworkFailure('Backend not configured.');
    return c;
  }

  Future<GroupModel> createGroup({
    required String name,
    required String rideType,
    required String vehicleType,
    required String leaderId,
    int? maxSpeed,
    int distanceAlert = 1000,
  }) async {
    final row = {
      'name': name,
      'leader_id': leaderId,
      'ride_type': rideType,
      'vehicle_type': vehicleType,
      'max_speed_limit': maxSpeed,
      'distance_alert_threshold': distanceAlert,
      'status': 'planning',
    };
    final res = await _c.from('groups').insert(row).select().single();
    return GroupModel.fromJson(res);
  }

  Future<List<VehicleModel>> addVehicles(
    String groupId,
    List<Map<String, dynamic>> slots,
  ) async {
    final rows = [
      for (final s in slots)
        {
          'id': _uuid.v4(),
          'group_id': groupId,
          'vehicle_type': s['vehicle_type'] ?? 'bike',
          'max_passengers': s['max_passengers'] ?? 1,
          'position_in_group': s['position'] ?? 1,
          'role': s['role'] ?? 'middle',
          'driver_id': s['driver_id'],
        }
    ];
    final res = await _c.from('vehicles').insert(rows).select();
    return (res as List).map((e) => VehicleModel.fromJson(e)).toList();
  }

  Future<List<VehicleModel>> fetchVehicles(String groupId) async {
    final res = await _c
        .from('vehicles')
        .select()
        .eq('group_id', groupId)
        .order('position_in_group');
    return (res as List).map((e) => VehicleModel.fromJson(e)).toList();
  }

  Future<void> assignDriver(String vehicleId, String driverId) async {
    await _c.from('vehicles').update({'driver_id': driverId}).eq('id', vehicleId);
  }

  Future<void> removeDriver(String vehicleId) async {
    await _c.from('vehicles').update({'driver_id': null}).eq('id', vehicleId);
  }

  Future<InviteModel> createInvite({
    required String groupId,
    String? vehicleId,
    required String phone,
    required String invitedBy,
  }) async {
    final res = await _c.from('invites').insert({
      'group_id': groupId,
      'vehicle_id': vehicleId,
      'invited_phone': phone,
      'invited_by': invitedBy,
    }).select().single();
    return InviteModel.fromJson(res);
  }

  Future<void> setGroupStatus(String groupId, String status) async {
    await _c.from('groups').update({'status': status}).eq('id', groupId);
  }

  Future<RideModel> createRide(String groupId) async {
    final res =
        await _c.from('rides').insert({'group_id': groupId}).select().single();
    return RideModel.fromJson(res);
  }
}
