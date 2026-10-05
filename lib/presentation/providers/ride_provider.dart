import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ride_models.dart';
import '../../data/repositories/ride_repository.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) => RideRepository());

/// Wizard state (Step 1 ride type, Step 2 vehicle type).
final rideTypeProvider = StateProvider<String>((ref) => 'group'); // solo | group
final vehicleTypeProvider = StateProvider<String>((ref) => 'bike'); // bike | car | mixed

/// Active group + slots. Null until created. Works offline with local slots
/// when backend is missing (lobby still demonstrable for resume video).
final currentGroupProvider = StateProvider<GroupModel?>((ref) => null);
final vehiclesProvider = StateProvider<List<VehicleModel>>((ref) => []);
final pendingInvitesProvider = StateProvider<Set<String>>((ref) => {});
final readyVehiclesProvider = StateProvider<Set<String>>((ref) => {});
final activeRideProvider = StateProvider<RideModel?>((ref) => null);
