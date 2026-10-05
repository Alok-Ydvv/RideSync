import 'dart:math' as math;

/// Phase 1 constants. Free-tier budgets enforced via Edge cache, not per-phone polling.
class AppConstants {
  // Location tiers (spec, simplified offline model).
  static const activeIntervalSec = 10;
  static const backgroundIntervalSec = 30;
  static const stationaryIntervalSec = 60;
  static const distanceFilterMeters = 25.0;

  // Group limits (spec).
  static const maxBikes = 20;
  static const maxCars = 10;
  static const maxCarPassengers = 7;
  static const maxEmergencyContacts = 3;

  // Distance alerts + overspeed tolerance (spec).
  static const distanceAlertOptions = [500, 1000, 2000, 5000];
  static const overspeedToleranceOptions = [5, 10, 15];

  // SOS cancel window (spec: 10s false-alarm window).
  static const sosCancelWindowSec = 10;

  // Weather cache: one fetch per ride per 20 min (Open-Meteo free: 10k/day).
  static const weatherCacheMinutes = 20;

  // Invite code TTL (spec: 24h).
  static const inviteTtlHours = 24;
}

/// Haversine distance in meters. Used for distance alerts + wrong-turn checks.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  return r * c;
}
