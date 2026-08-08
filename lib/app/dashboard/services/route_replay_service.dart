import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

/// Debug-only drive simulator.
///
/// Turns a route into a stream of realistic [Position] fixes — crucially
/// **with bearing and speed**, which `adb emu geo fix` and the iOS simulator
/// never provide. That makes course-up rotation, the follow camera, speed
/// based zoom and banner timing testable without driving.
///
/// Ported from the Android SDK's `ReplayRouteMapper` (see
/// docs/mapbox_native_nav_reference.md §15): mark significant vertices,
/// derive a target speed per vertex from how sharply the route turns there,
/// back-propagate braking so the car slows *before* a corner, then emit
/// positions at 1 Hz along a trapezoidal accelerate–cruise–decelerate
/// profile.
class RouteReplayService {
  RouteReplayService._();
  static final RouteReplayService instance = RouteReplayService._();

  // --- Tuning, from the native implementation -----------------------------

  /// Speed caps by how sharply the route turns at a vertex.
  static const double _maxSpeedMps = 30.0; // straight
  static const double _turnSpeedMps = 3.0; // 90°
  static const double _uTurnSpeedMps = 1.0; // 180°

  static const double _maxAccelMps2 = 3.0;
  static const double _minAccelMps2 = -4.0; // braking

  /// Emit one fix per second, like a real GPS.
  static const Duration _tick = Duration(milliseconds: 1000);

  Timer? _timer;
  List<Position> _frames = const [];
  int _index = 0;
  double _speedMultiplier = 1;

  final _controller = StreamController<Position>.broadcast();

  /// Simulated fixes. The position pipeline listens to this instead of
  /// Geolocator while a replay is running.
  Stream<Position> get positions => _controller.stream;

  bool get isRunning => _timer != null;

  /// Simulated fixes are tagged with this exact accuracy so the position
  /// pipeline can tell them apart from real device fixes and ignore the
  /// latter while a replay is running.
  static const double simulatedAccuracy = 4.242;

  bool isSimulated(Position p) => p.accuracy == simulatedAccuracy;

  /// Progress through the current replay, 0–1.
  double get progress =>
      _frames.isEmpty ? 0 : (_index / _frames.length).clamp(0.0, 1.0);

  double get speedMultiplier => _speedMultiplier;

  /// Build the drive and start emitting. Safe to call again to restart.
  void start(MapboxRoute route, {double speedMultiplier = 1}) {
    if (kReleaseMode) return; // never runs in release
    stop();
    _speedMultiplier = speedMultiplier.clamp(0.5, 8.0);
    _frames = _buildFrames(route);
    _index = 0;
    if (_frames.isEmpty) {
      debugPrint('🎬 Replay: route produced no frames');
      return;
    }
    debugPrint('🎬 Replay: ${_frames.length} frames '
        '(~${_frames.length ~/ 60} min at 1x)');
    _schedule();
  }

  void setSpeedMultiplier(double value) {
    _speedMultiplier = value.clamp(0.5, 8.0);
    if (isRunning) _schedule();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _schedule() {
    _timer?.cancel();
    final interval = Duration(
      milliseconds: (_tick.inMilliseconds / _speedMultiplier).round(),
    );
    _timer = Timer.periodic(interval, (_) {
      if (_index >= _frames.length) {
        debugPrint('🎬 Replay: finished');
        stop();
        return;
      }
      // Stamp each frame as "now" so downstream staleness checks pass.
      final frame = _frames[_index++];
      _controller.add(
        Position(
          latitude: frame.latitude,
          longitude: frame.longitude,
          timestamp: DateTime.now(),
          accuracy: simulatedAccuracy,
          altitude: frame.altitude,
          altitudeAccuracy: frame.altitudeAccuracy,
          heading: frame.heading,
          headingAccuracy: frame.headingAccuracy,
          speed: frame.speed,
          speedAccuracy: frame.speedAccuracy,
        ),
      );
    });
  }

  // --- Frame generation ---------------------------------------------------

  List<Position> _buildFrames(MapboxRoute route) {
    final coords = route.geometry.coordinates;
    if (coords.length < 2) return const [];

    // 1. Dedupe consecutive identical points.
    final points = <_LatLng>[];
    for (final c in coords) {
      if (c.length < 2) continue;
      final p = _LatLng(c[1], c[0]);
      if (points.isEmpty || _distance(points.last, p) > 0.5) {
        points.add(p);
      }
    }
    if (points.length < 2) return const [];

    // 2. Target speed at each vertex, from how sharply the route turns.
    final speeds = List<double>.filled(points.length, _maxSpeedMps);
    for (var i = 1; i < points.length - 1; i++) {
      final turn = _turnAngleDegrees(points[i - 1], points[i], points[i + 1]);
      speeds[i] = _speedForTurn(turn);
    }
    // Start and finish at rest.
    speeds[0] = 0;
    speeds[points.length - 1] = 0;

    // 3. Back-propagate braking so we slow down *before* the corner, not at
    //    it — v² = u² + 2as rearranged for the entry speed.
    for (var i = points.length - 2; i >= 0; i--) {
      final d = _distance(points[i], points[i + 1]);
      final maxEntry = math.sqrt(
        speeds[i + 1] * speeds[i + 1] + 2 * _minAccelMps2.abs() * d,
      );
      speeds[i] = math.min(speeds[i], maxEntry);
    }

    // 4. Forward pass for acceleration limits, then walk the polyline at
    //    1 Hz emitting a fix per second.
    final frames = <Position>[];
    var speed = 0.0;
    var segment = 0;
    var alongSegment = 0.0;

    while (segment < points.length - 1 && frames.length < 20000) {
      final from = points[segment];
      final to = points[segment + 1];
      final segLength = _distance(from, to);
      if (segLength <= 0) {
        segment++;
        continue;
      }

      // Accelerate toward this segment's target, capped by what braking
      // allows for the corner ahead.
      final target = speeds[segment + 1];
      if (speed < target) {
        speed = math.min(target, speed + _maxAccelMps2);
      } else {
        speed = math.max(target, speed + _minAccelMps2);
      }
      speed = speed.clamp(0.5, _maxSpeedMps);

      alongSegment += speed; // one second of travel
      while (alongSegment >= segLength && segment < points.length - 1) {
        alongSegment -= segLength;
        segment++;
        if (segment >= points.length - 1) break;
      }
      if (segment >= points.length - 1) break;

      final segFrom = points[segment];
      final segTo = points[segment + 1];
      final segLen = _distance(segFrom, segTo);
      final t = segLen <= 0 ? 0.0 : (alongSegment / segLen).clamp(0.0, 1.0);
      final pos = _interpolate(segFrom, segTo, t);

      // Bearing along the segment we're actually on. A 2-point lookahead
      // made the "car" face the next turn while still travelling straight,
      // which reads as the map swinging early. A real vehicle points where
      // it's going now; the camera smoothing handles easing into the turn.
      final bearing = _bearing(segFrom, segTo);

      frames.add(
        Position(
          latitude: pos.lat,
          longitude: pos.lng,
          timestamp: DateTime.now(),
          accuracy: simulatedAccuracy,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: bearing,
          headingAccuracy: 5,
          speed: speed,
          speedAccuracy: 1,
        ),
      );
    }

    return frames;
  }

  /// Quadratic falloff: straight roads run fast, right-angles crawl, and a
  /// U-turn is walking pace.
  double _speedForTurn(double turnDegrees) {
    final t = (turnDegrees.abs() / 180.0).clamp(0.0, 1.0);
    if (t <= 0.5) {
      // 0°–90°: max speed down to turn speed.
      final k = t / 0.5;
      return _maxSpeedMps - (_maxSpeedMps - _turnSpeedMps) * k * k;
    }
    // 90°–180°: turn speed down to U-turn speed.
    final k = (t - 0.5) / 0.5;
    return _turnSpeedMps - (_turnSpeedMps - _uTurnSpeedMps) * k;
  }

  double _turnAngleDegrees(_LatLng a, _LatLng b, _LatLng c) {
    final inBearing = _bearing(a, b);
    final outBearing = _bearing(b, c);
    var diff = (outBearing - inBearing).abs() % 360;
    if (diff > 180) diff = 360 - diff;
    return diff;
  }

  // --- Geo helpers --------------------------------------------------------

  static const double _earthRadius = 6371000.0;

  double _distance(_LatLng a, _LatLng b) {
    const toRad = math.pi / 180;
    final dLat = (b.lat - a.lat) * toRad;
    final dLon = (b.lng - a.lng) * toRad;
    final lat1 = a.lat * toRad;
    final lat2 = b.lat * toRad;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * _earthRadius * math.asin(math.sqrt(h));
  }

  double _bearing(_LatLng a, _LatLng b) {
    const toRad = math.pi / 180;
    final lat1 = a.lat * toRad;
    final lat2 = b.lat * toRad;
    final dLon = (b.lng - a.lng) * toRad;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  _LatLng _interpolate(_LatLng a, _LatLng b, double t) =>
      _LatLng(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
}

class _LatLng {
  const _LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}
