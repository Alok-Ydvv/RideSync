/// SOS triple-path (spec): Realtime Broadcast to group + FCM to all +
/// sms: intent to emergency contacts (works without internet).
/// 10s false-alarm cancel window.
abstract class SosService {
  /// Trigger SOS. [rideId] links the alert to the active ride so the whole
  /// group is notified; null = solo/offline alert to contacts only.
  /// Implementations must run all three paths in parallel.
  Future<void> trigger(
      {required double lat, required double lng, String? rideId});

  /// Cancel within [AppConstants.sosCancelWindowSec].
  Future<void> cancel(String alertId);
}
