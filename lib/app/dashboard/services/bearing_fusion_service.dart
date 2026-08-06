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

  /// Whether the device is moving fast enough for GPS course to be usable.
  bool isMoving(Position position) =>
      position.speed >= _gpsBearingSpeedThresholdMps;

  /// Bearing for the **puck**, which may follow the compass while stationary
  /// so the arrow still shows which way the driver is facing.
  ///
  /// Returns `null` if no source is currently reliable (caller should keep
  /// the previous value).
  double? fuse(Position position) {
    final gpsHeading = position.heading;
    final gpsHeadingValid = gpsHeading >= 0 && gpsHeading <= 360;

    if (gpsHeadingValid && isMoving(position)) {
      return gpsHeading;
    }

    final compass = _compassHeading;
    if (compass != null && compass >= 0) {
      return compass;
    }

    return gpsHeadingValid ? gpsHeading : null;
  }

  /// Bearing for the **camera**. Unlike [fuse] this never falls back to the
  /// compass: rotating the phone while parked would spin the whole map,
  /// which is disorienting and burns frames for no information. Waze does
  /// the same — the puck turns, the map holds still.
  ///
  /// Returns `null` when stationary, meaning "keep the current heading".
  double? cameraBearing(Position position) {
    final gpsHeading = position.heading;
    final gpsHeadingValid = gpsHeading >= 0 && gpsHeading <= 360;
    if (gpsHeadingValid && isMoving(position)) {
      return gpsHeading;
    }
    return null;
  }

  Future<void> dispose() async {
    await _compassSubscription?.cancel();
    _compassSubscription = null;
    _compassHeading = null;
  }
}
