/// Policy-safe Slumber and Device Pickup detection service
/// AdMob IVT compliant: STRICTLY ZERO background video ad loops
class SlumberSensorService {
  static final SlumberSensorService instance = SlumberSensorService._internal();
  SlumberSensorService._internal();

  bool _isMonitoring = false;
  void Function()? _onMorningPickup;

  bool get isMonitoring => _isMonitoring;

  /// Activates mindful slumber monitoring
  /// Never executes or schedules video ads in the background
  void startMonitoring({required void Function() onMorningPickup}) {
    _isMonitoring = true;
    _onMorningPickup = onMorningPickup;
  }

  /// Stops slumber monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _onMorningPickup = null;
  }

  /// Simulates / receives accelerometer device pickup wake event
  /// Opens the interactive Morning Harvest Modal only when user holds device
  void triggerMorningPickupWakeEvent() {
    if (!_isMonitoring) return;
    final callback = _onMorningPickup;
    if (callback != null) {
      callback();
    }
  }
}
