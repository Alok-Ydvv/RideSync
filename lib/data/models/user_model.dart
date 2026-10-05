/// Phase 1 user + emergency contact models. Mirrors Supabase tables:
/// users, emergency_contacts. Manual JSON (no codegen) to keep scaffold light.
class UserModel {
  final String id;
  final String? phone;
  final String? email;
  final String fullName;
  final String? profilePhotoUrl;
  final String? bloodGroup;
  final String? licenseNumber;
  final String defaultVehicleType; // bike | car

  const UserModel({
    required this.id,
    this.phone,
    this.email,
    required this.fullName,
    this.profilePhotoUrl,
    this.bloodGroup,
    this.licenseNumber,
    this.defaultVehicleType = 'bike',
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        fullName: (j['full_name'] ?? '') as String,
        profilePhotoUrl: j['profile_photo_url'] as String?,
        bloodGroup: j['blood_group'] as String?,
        licenseNumber: j['license_number'] as String?,
        defaultVehicleType: (j['default_vehicle_type'] ?? 'bike') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'email': email,
        'full_name': fullName,
        'profile_photo_url': profilePhotoUrl,
        'blood_group': bloodGroup,
        'license_number': licenseNumber,
        'default_vehicle_type': defaultVehicleType,
      };
}

class EmergencyContactModel {
  final String? id;
  final String userId;
  final String name;
  final String phone;
  final String relationship;
  final int priority; // 1-3

  const EmergencyContactModel({
    this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relationship,
    this.priority = 1,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> j) =>
      EmergencyContactModel(
        id: j['id'] as String?,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        relationship: j['relationship'] as String,
        priority: (j['priority'] ?? 1) as int,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'priority': priority,
      };
}
