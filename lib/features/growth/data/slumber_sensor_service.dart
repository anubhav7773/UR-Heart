import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum SlumberDeviceState { active, restingFaceDown, morningHarvestReady }

/// Policy-safe Accelerometer Slumber & Morning Pickup Sensor Service (DIS-08, ACT-06 & WEB Parity)
/// Utilizes genuine physical accelerometer events on Mobile (sensors_plus).
/// Detects face-down stillness posture (Z < -8.5 m/s^2) on phones.
/// Provides graceful Nocturnal Sanctuary Stillness on Web/Desktop browsers.
class SlumberSensorService {
  static final SlumberSensorService instance = SlumberSensorService._internal();
  SlumberSensorService._internal();

  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  final StreamController<SlumberDeviceState> _stateController =
      StreamController<SlumberDeviceState>.broadcast();

  Stream<SlumberDeviceState> get slumberStateStream => _stateController.stream;

  DateTime? _slumberStartTime;
  bool _isFaceDown = false;
  bool _isMonitoring = false;
  void Function()? _onMorningPickup;

  bool get isMonitoring => _isMonitoring;

  static const double _gravityThreshold = 8.5; // Z-axis threshold for face-down
  static const double _stillnessTolerance = 1.2;

  Duration _lastRestDuration = Duration.zero;
  Duration get lastRestDuration => _lastRestDuration;
  double get lastRestHours => _lastRestDuration.inMinutes / 60.0;

  /// Starts physical hardware accelerometer monitoring with callback compatibility
  void startMonitoring({required void Function() onMorningPickup}) {
    _onMorningPickup = onMorningPickup;
    startHardwareMonitoring();
  }

  /// Initiates hardware sensor event listening stream
  void startHardwareMonitoring() {
    _isMonitoring = true;
    _sensorSubscription?.cancel();

    if (kIsWeb) {
      // Web / Desktop platform: hardware accelerometer not present or cannot be placed face-down.
      // Slumber is managed via Nocturnal Sanctuary Stillness or manual rest trigger.
      debugPrint('[SlumberSensorService] Web environment active: Nocturnal Sanctuary Stillness enabled.');
      return;
    }

    runZonedGuarded(() {
      _sensorSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        _processAccelerometerData,
        onError: (dynamic e) {
          debugPrint('[SlumberSensorService] Sensor error: $e');
        },
        cancelOnError: false,
      );
    }, (error, stack) {
      debugPrint('[SlumberSensorService] Sensor hardware channel notice: $error');
    });
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    // Face-down posture: Z-axis is negative gravity (-9.8 m/s^2)
    final bool currentlyFaceDown = event.z < -_gravityThreshold &&
        event.x.abs() < _stillnessTolerance &&
        event.y.abs() < _stillnessTolerance;

    if (currentlyFaceDown && !_isFaceDown) {
      // Device was just placed face-down
      _isFaceDown = true;
      _slumberStartTime = DateTime.now();
      _stateController.add(SlumberDeviceState.restingFaceDown);
    } else if (!currentlyFaceDown && _isFaceDown) {
      // Device picked up after being face-down
      _isFaceDown = false;
      final startTime = _slumberStartTime;
      if (startTime != null) {
        final durationResting = DateTime.now().difference(startTime);
        _lastRestDuration = durationResting;
        // Minimum 10 seconds of resting required for harvest unlock
        if (durationResting.inSeconds >= 10) {
          _stateController.add(SlumberDeviceState.morningHarvestReady);
          _onMorningPickup?.call();
        } else {
          _stateController.add(SlumberDeviceState.active);
        }
      }
      _slumberStartTime = null;
    }
  }

  /// Initiates a Web Stillness rest session
  void startWebStillnessSession() {
    _isFaceDown = true;
    _slumberStartTime = DateTime.now();
    _stateController.add(SlumberDeviceState.restingFaceDown);
  }

  /// Concludes a Web Stillness session and unlocks morning harvest if qualified
  void completeWebStillnessSession() {
    _isFaceDown = false;
    final startTime = _slumberStartTime;
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _lastRestDuration = duration;
      if (duration.inSeconds >= 10) {
        _stateController.add(SlumberDeviceState.morningHarvestReady);
        _onMorningPickup?.call();
      } else {
        _stateController.add(SlumberDeviceState.active);
      }
    } else {
      triggerMorningPickupWakeEvent();
    }
    _slumberStartTime = null;
  }

  /// Stops physical hardware sensor monitoring
  void stopMonitoring() {
    stopHardwareMonitoring();
    _onMorningPickup = null;
  }

  void stopHardwareMonitoring() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _slumberStartTime = null;
    _isFaceDown = false;
    _isMonitoring = false;
  }

  /// Simulates / triggers morning pickup wake event (e.g. for testing / web / demo)
  void triggerMorningPickupWakeEvent() {
    _lastRestDuration = const Duration(hours: 7);
    _stateController.add(SlumberDeviceState.morningHarvestReady);
    _onMorningPickup?.call();
  }
}
