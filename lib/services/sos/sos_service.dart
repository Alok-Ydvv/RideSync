/// SOS triple-path (spec): Realtime Broadcast to group + FCM to all +
/// SMS via own SIM (works without internet). 10s false-alarm cancel window.
/// Full telephony wiring lands in the SOS slice; this is the contract.
abstract class SosService {
  /// Trigger SOS. Implementations must run all three paths in parallel.
  Future<void> trigger({required double lat, required double lng});

  /// Cancel within [AppConstants.sosCancelWindowSec].
  Future<void> cancel(String alertId);
}
