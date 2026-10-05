import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';

/// Phase 1 location pipeline (free, battery-aware).
/// UI subscribes to [positions]; [SyncService] batches to Supabase:
/// Broadcast every 10s (ephemeral) + DB upsert every 30s. No per-ping writes.
class LocationService {
  StreamSubscription<Position>? _sub;
  final _ctrl = StreamController<Position>.broadcast();

  Stream<Position> get positions => _ctrl.stream;

  /// Tier from spec: active 10s / background 30s / stationary 60s.
  /// Caller picks tier; distance filter stays 25m to save battery + data.
  Future<void> start({required bool moving, required bool inBackground}) async {
    final loc = await Geolocator.checkPermission();
    if (loc == LocationPermission.denied || loc == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    final interval = !moving
        ? AppConstants.stationaryIntervalSec
        : inBackground
            ? AppConstants.backgroundIntervalSec
            : AppConstants.activeIntervalSec;

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.distanceFilterMeters.toInt(),
        timeLimit: Duration(seconds: interval),
      ),
    ).listen(_ctrl.add);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _sub?.cancel();
    _ctrl.close();
  }
}
