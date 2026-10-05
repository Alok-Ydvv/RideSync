import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';

/// Phase 1 location pipeline (free, battery-aware).
/// UI subscribes to [positions]; [SyncService] batches to Supabase:
/// Broadcast every 10s (ephemeral) + DB upsert every 30s. No per-ping writes.
///
/// NOTE: [LocationSettings.timeLimit] must NOT be set here — it ends the
/// stream after that duration (previously killed tracking 10s after start).
/// Tier pacing is done by the sync layer (Broadcast 10s / upsert 30s),
/// not by killing the GPS stream.
class LocationService {
  StreamSubscription<Position>? _sub;
  final _ctrl = StreamController<Position>.broadcast();

  Stream<Position> get positions => _ctrl.stream;

  /// Returns null when usable, otherwise a short user-facing reason.
  /// Handles: location services off, denied, denied-forever (→ app settings).
  static Future<String?> ensurePermission({bool background = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on Location Services, then retry.';
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied) {
      return 'Location permission denied — map shows demo positions.';
    }
    if (p == LocationPermission.deniedForever) {
      return 'Location blocked — enable it in App Settings, then retry.';
    }
    if (background) {
      // Android "Allow all the time" + iOS Always. Best-effort: if the user
      // keeps "While in use", foreground tracking still works.
      final bg = await Geolocator.requestPermission();
      if (bg != LocationPermission.always) {
        return 'Background location not granted — tracking pauses when the app is closed.';
      }
    }
    return null;
  }

  /// Tier from spec: active 10s / background 30s / stationary 60s.
  /// The stream runs until [stop]/[dispose] (screen exit stops GPS).
  /// Distance filter stays 25m to save battery + data.
  Future<void> start({required bool moving, required bool inBackground}) async {
    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.distanceFilterMeters.toInt(),
      ),
    ).listen(
      _ctrl.add,
      onError: (_) {},
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _sub?.cancel();
    if (!_ctrl.isClosed) _ctrl.close();
  }
}
