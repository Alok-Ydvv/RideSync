/// Phase 1 ride models. Mirrors Supabase: groups, vehicles,
/// vehicle_passengers, invites, rides. Manual JSON, no codegen.
class GroupModel {
  final String id;
  final String name;
  final String inviteCode;
  final String leaderId;
  final String rideType; // solo | group
  final String vehicleType; // bike | car | mixed
  final int? maxSpeedLimit;
  final int distanceAlertThreshold;
  final String status;

  const GroupModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.leaderId,
    required this.rideType,
    required this.vehicleType,
    this.maxSpeedLimit,
    this.distanceAlertThreshold = 1000,
    this.status = 'planning',
  });

  factory GroupModel.fromJson(Map<String, dynamic> j) => GroupModel(
        id: j['id'] as String,
        name: (j['name'] ?? 'Ride') as String,
        inviteCode: (j['invite_code'] ?? '') as String,
        leaderId: j['leader_id'] as String,
        rideType: (j['ride_type'] ?? 'group') as String,
        vehicleType: (j['vehicle_type'] ?? 'bike') as String,
        maxSpeedLimit: j['max_speed_limit'] as int?,
        distanceAlertThreshold: (j['distance_alert_threshold'] ?? 1000) as int,
        status: (j['status'] ?? 'planning') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'invite_code': inviteCode,
        'leader_id': leaderId,
        'ride_type': rideType,
        'vehicle_type': vehicleType,
        'max_speed_limit': maxSpeedLimit,
        'distance_alert_threshold': distanceAlertThreshold,
        'status': status,
      };
}

class VehicleModel {
  final String id;
  final String groupId;
  final String vehicleType; // bike | car
  final String? driverId;
  final int maxPassengers;
  final int position;
  final String role; // leader | middle | tail

  const VehicleModel({
    required this.id,
    required this.groupId,
    required this.vehicleType,
    this.driverId,
    this.maxPassengers = 1,
    this.position = 1,
    this.role = 'middle',
  });

  /// Slot state (spec): Empty → Invited → Confirmed → Ready.
  /// Invited tracked via invites table; Ready is a local lobby flag.
  String slotState({required bool hasPendingInvite, required bool ready}) {
    if (ready && driverId != null) return 'Ready';
    if (driverId != null) return 'Confirmed';
    if (hasPendingInvite) return 'Invited';
    return 'Empty';
  }

  factory VehicleModel.fromJson(Map<String, dynamic> j) => VehicleModel(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        vehicleType: (j['vehicle_type'] ?? 'bike') as String,
        driverId: j['driver_id'] as String?,
        maxPassengers: (j['max_passengers'] ?? 1) as int,
        position: (j['position_in_group'] ?? 1) as int,
        role: (j['role'] ?? 'middle') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'vehicle_type': vehicleType,
        'driver_id': driverId,
        'max_passengers': maxPassengers,
        'position_in_group': position,
        'role': role,
      };
}

class InviteModel {
  final String id;
  final String groupId;
  final String? vehicleId;
  final String invitedPhone;
  final String status;

  const InviteModel({
    required this.id,
    required this.groupId,
    this.vehicleId,
    required this.invitedPhone,
    this.status = 'pending',
  });

  factory InviteModel.fromJson(Map<String, dynamic> j) => InviteModel(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        vehicleId: j['vehicle_id'] as String?,
        invitedPhone: (j['invited_phone'] ?? '') as String,
        status: (j['status'] ?? 'pending') as String,
      );
}

class RideModel {
  final String id;
  final String groupId;
  final String status;
  final double? totalDistance;
  final int? totalDuration;

  const RideModel({
    required this.id,
    required this.groupId,
    this.status = 'planned',
    this.totalDistance,
    this.totalDuration,
  });

  factory RideModel.fromJson(Map<String, dynamic> j) => RideModel(
        id: j['id'] as String,
        groupId: j['group_id'] as String,
        status: (j['status'] ?? 'planned') as String,
        totalDistance: (j['total_distance'] as num?)?.toDouble(),
        totalDuration: j['total_duration'] as int?,
      );
}
