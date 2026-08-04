import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

/// Fuses GPS course with the device magnetometer to produce a stable puck
/// bearing.
///
/// GPS course (`position.heading`) is accurate at speed but noisy or invalid
/// when stationary or moving slowly — the puck spins randomly in parking lots
/// and at traffic lights. Below [_gpsBearingSpeedThresholdMps] we fall back to
/// the compass heading; above it we trust the GPS course.
class BearingFusionService {
  static const double _gpsBearingSpeedThresholdMps = 5 * 1000 / 3600; // 5 km/h

  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _compassHeading;

  void start() {
    _compassSubscription ??= FlutterCompass.events?.listen((event) {
      _compassHeading = event.heading;
    });
  }

  /// Returns the fused bearing for [position], or `null` if no source is
  /// currently reliable (caller should keep the previous value).
  double? fuse(Position position) {
    final gpsHeading = position.heading;
    final gpsHeadingValid = gpsHeading >= 0 && gpsHeading <= 360;
    final movingFastEnough = position.speed >= _gpsBearingSpeedThresholdMps;

    if (gpsHeadingValid && movingFastEnough) {
      return gpsHeading;
    }

    final compass = _compassHeading;
    if (compass != null && compass >= 0) {
      return compass;
    }

    return gpsHeadingValid ? gpsHeading : null;
  }

  Future<void> dispose() async {
    await _compassSubscription?.cancel();
    _compassSubscription = null;
    _compassHeading = null;
  }
}
