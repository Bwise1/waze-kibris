import 'dart:async';

import 'package:flutter_polyline_points/flutter_polyline_points.dart' hide TravelMode;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/core/constants/navigation_camera_constants.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';

class CameraController {
  mp.MapboxMap? _mapboxMap;

  double _currentZoom = 15;
  double _currentPitch = 0;
  double _currentBearing = 0;
  bool _isFollowingUser = true;
  bool _isNavigationMode = false;
  TravelMode _travelMode = TravelMode.drive;

  /// Zoom used during active guidance; walking zooms in tighter to show side
  /// streets and building entrances.
  double get _activeGuidanceZoom => _travelMode.activeGuidanceZoom;

  /// Update the mode driving zoom decisions. Safe to call any time; next
  /// camera update uses the new zoom.
  void setTravelMode(TravelMode mode) {
    _travelMode = mode;
  }
  bool _isCourseUp = true;

  geo.Position? _lastCameraPosition;
  DateTime? _lastCameraUpdate;
  Timer? _cameraUpdateTimer;

  static const double _smoothingFactor = 0.3;
  static const double _defaultZoom = 15;
  static const double _overviewPitch = 0;
  static const int _animationDuration = 1000;
  static const double _lowSpeedBearingThresholdKmh = 5.0;

  void initialize(mp.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  double get currentZoom => _currentZoom;
  double get currentPitch => _currentPitch;
  double get currentBearing => _currentBearing;
  bool get isFollowingUser => _isFollowingUser;
  bool get isNavigationMode => _isNavigationMode;
  bool get isCourseUp => _isCourseUp;

  void toggleCourseUp() {
    _isCourseUp = !_isCourseUp;
  }

  Future<void> updateCamera({
    required geo.Position userPosition,
    double? userBearing,
    bool animate = true,
    bool isOverviewMode = false,
    double? distanceToManeuverAlongRouteMeters,
    double? remainingDistanceAlongRouteMeters,
    List<PointLatLng>? remainingRouteForOverview,
  }) async {
    // Allow updates when following user, or when in overview mode so overview moves with user
    if (_mapboxMap == null) return;
    if (!_isFollowingUser && !isOverviewMode) return;

    if (!_isValidPosition(userPosition)) return;

    // Check if user has moved significantly to avoid unnecessary updates
    if (_lastCameraPosition != null) {
      final distance = geo.Geolocator.distanceBetween(
        _lastCameraPosition!.latitude,
        _lastCameraPosition!.longitude,
        userPosition.latitude,
        userPosition.longitude,
      );
      if (distance < 3.0) return;
    }

    // Debounce camera updates to prevent excessive calls
    _cameraUpdateTimer?.cancel();
    _cameraUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      _actuallyUpdateCamera(
        userPosition,
        userBearing,
        animate,
        isOverviewMode,
        distanceToManeuverAlongRouteMeters: distanceToManeuverAlongRouteMeters,
        remainingDistanceAlongRouteMeters: remainingDistanceAlongRouteMeters,
        remainingRouteForOverview: remainingRouteForOverview,
      );
    });
  }

  Future<void> _actuallyUpdateCamera(
    geo.Position userPosition,
    double? userBearing,
    bool animate,
    bool isOverviewMode, {
    double? distanceToManeuverAlongRouteMeters,
    double? remainingDistanceAlongRouteMeters,
    List<PointLatLng>? remainingRouteForOverview,
  }) async {
    if (_mapboxMap == null) return;

    _lastCameraPosition = userPosition;

    if (_isNavigationMode && !isOverviewMode) {
      await _updateNavigationCamera(
        userPosition: userPosition,
        userBearing: userBearing,
        animate: animate,
        distanceToManeuverAlongRouteMeters: distanceToManeuverAlongRouteMeters,
        remainingDistanceAlongRouteMeters: remainingDistanceAlongRouteMeters,
      );
    } else if (_isNavigationMode && isOverviewMode) {
      await _updateOverviewCamera(
        userPosition: userPosition,
        animate: animate,
        remainingRoutePoints: remainingRouteForOverview,
      );
    } else {
      await _updateFollowCamera(
        userPosition: userPosition,
        userBearing: userBearing,
        animate: animate,
      );
    }

    _lastCameraUpdate = DateTime.now();
  }

  /// Duration for recenter (my location) animation — Waze-style smooth ease.
  static const int _recenterAnimationDurationMs = 700;

  Future<void> updatePosition(geo.Position position) async {
    if (_mapboxMap == null) return;

    final cameraOptions = mp.CameraOptions(
      center: mp.Point(
        coordinates: mp.Position(
          position.longitude,
          position.latitude,
        ),
      ),
      zoom: _currentZoom,
      bearing: position.heading >= 0 ? position.heading : _currentBearing,
      pitch: _currentPitch,
    );

    try {
      await _mapboxMap!.easeTo(
        cameraOptions,
        mp.MapAnimationOptions(duration: _recenterAnimationDurationMs),
      );
    } catch (e) {
      await _mapboxMap!.setCamera(cameraOptions);
    }
  }

  /// Navigation follow mode: speed-based zoom (14–17.5), bearing follows user, camera centers on position.
  /// Zoom clamped to native range [kFollowingMinZoom, kFollowingMaxZoom]. Pitch 0° near maneuver.
  /// When user pans away, _isFollowingUser becomes false and we skip updates until they tap recenter.
  Future<void> _updateNavigationCamera({
    required geo.Position userPosition,
    double? userBearing,
    bool animate = true,
    double? distanceToManeuverAlongRouteMeters,
    double? remainingDistanceAlongRouteMeters,
  }) async {
    if (!_isValidPosition(userPosition)) return;

    // Calculate speed in km/h (speed is in m/s)
    final speedKmh = userPosition.speed * 3.6;

    // 1. Target zoom: arrival (19) when very close; else speed-based for
    // driving (14–17.5), or the mode's fixed active-guidance zoom for
    // walk/cycle (drivers care about seeing highway exits ahead; pedestrians
    // need building-scale detail regardless of pace).
    double targetZoom;
    if (remainingDistanceAlongRouteMeters != null &&
        remainingDistanceAlongRouteMeters <=
            kArrivalRemainingDistanceThresholdMeters) {
      targetZoom = kArrivalZoom.clamp(kFollowingMinZoom, 22.0);
    } else if (!_travelMode.isVehicle) {
      targetZoom = _activeGuidanceZoom;
    } else {
      // Speed-based: slow -> 17.5, fast -> 14.0
      if (speedKmh < 30) {
        targetZoom = 17.5;
      } else if (speedKmh > 100) {
        targetZoom = 14.0;
      } else {
        final t = (speedKmh - 30) / (100 - 30);
        targetZoom = 17.5 - (t * (17.5 - 14.0));
      }
      targetZoom = targetZoom.clamp(kFollowingMinZoom, kFollowingMaxZoom);
    }

    // 2. Pitch: 0° near maneuver (native pitch-near-maneuver); else default (2D)
    if (distanceToManeuverAlongRouteMeters != null &&
        distanceToManeuverAlongRouteMeters <= kPitchNearManeuverTriggerMeters) {
      _currentPitch = 0;
    } else {
      _currentPitch = kFollowingDefaultPitch;
    }

    // 3. Bearing smoothing (capped at 45°)
    double smoothedBearing = _currentBearing;
    if (!_isCourseUp) {
      // Force North-Up
      smoothedBearing = 0.0;
    } else if (userBearing != null) {
      final targetBearing = userBearing;
      // At very low speeds, heading may be noisy; still use route/course bearing
      // but keep smoothing engaged so camera rotation remains stable.
      if (speedKmh < _lowSpeedBearingThresholdKmh) {
        smoothedBearing = _smoothBearing(_currentBearing, targetBearing);
      } else if (speedKmh > 3.0) {
        smoothedBearing = _smoothBearing(_currentBearing, targetBearing);
      }
    }
    _currentBearing = smoothedBearing;

    // Smoothly interpolate zoom
    _currentZoom = _currentZoom + (targetZoom - _currentZoom) * 0.05;

    final cameraOptions = mp.CameraOptions(
      center: mp.Point(
        coordinates: mp.Position(
          userPosition.longitude,
          userPosition.latitude,
        ),
      ),
      zoom: _currentZoom,
      bearing: smoothedBearing, // Follow user's heading
      pitch: _currentPitch,
    );

    try {
      await _mapboxMap!.easeTo(
        cameraOptions,
        mp.MapAnimationOptions(duration: animate ? 1000 : 0),
      );
    } catch (e) {
      try {
        await _mapboxMap!.setCamera(cameraOptions);
      } catch (fallbackError) {
        // Silently ignore
      }
    }
  }

  /// Overview mode: center on user at fixed zoom, or frame remaining route when provided.
  /// Zoom capped at kOverviewMaxZoom (native overview max).
  Future<void> _updateOverviewCamera({
    required geo.Position userPosition,
    bool animate = true,
    List<PointLatLng>? remainingRoutePoints,
  }) async {
    if (!_isValidPosition(userPosition)) return;

    _currentBearing = 0; // North up for overview
    _currentPitch = _overviewPitch;

    if (remainingRoutePoints != null && remainingRoutePoints.isNotEmpty) {
      // Frame user + remaining route; clamp zoom to [kOverviewDefaultZoom, kOverviewMaxZoom]
      double minLat = userPosition.latitude;
      double maxLat = userPosition.latitude;
      double minLng = userPosition.longitude;
      double maxLng = userPosition.longitude;
      for (final p in remainingRoutePoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      final bounds = mp.CoordinateBounds(
        southwest: mp.Point(coordinates: mp.Position(minLng, minLat)),
        northeast: mp.Point(coordinates: mp.Position(maxLng, maxLat)),
        infiniteBounds: false,
      );
      final cameraOptions = await _mapboxMap!.cameraForCoordinateBounds(
        bounds,
        mp.MbxEdgeInsets(top: 150.0, left: 80.0, bottom: 200.0, right: 80.0),
        null,
        null,
        null,
        null,
      );
      final zoom = cameraOptions.zoom ?? kOverviewDefaultZoom;
      _currentZoom = zoom.clamp(kOverviewDefaultZoom, kOverviewMaxZoom);
      final options = mp.CameraOptions(
        center: cameraOptions.center,
        zoom: _currentZoom,
        bearing: 0,
        pitch: _currentPitch,
      );
      try {
        await _mapboxMap!.easeTo(
          options,
          mp.MapAnimationOptions(duration: animate ? 1500 : 0),
        );
      } catch (e) {
        try {
          await _mapboxMap!.setCamera(options);
        } catch (_) {}
      }
      return;
    }

    _currentZoom =
        kOverviewDefaultZoom.clamp(kFollowingMinZoom, kOverviewMaxZoom);

    final cameraOptions = mp.CameraOptions(
      center: mp.Point(
        coordinates: mp.Position(
          userPosition.longitude,
          userPosition.latitude,
        ),
      ),
      zoom: _currentZoom,
      bearing: _currentBearing,
      pitch: _currentPitch,
    );

    try {
      await _mapboxMap!.easeTo(
        cameraOptions,
        mp.MapAnimationOptions(duration: animate ? 1500 : 0),
      );
    } catch (e) {
      try {
        await _mapboxMap!.setCamera(cameraOptions);
      } catch (fallbackError) {
        // Silently ignore
      }
    }
  }

  Future<void> _updateFollowCamera({
    required geo.Position userPosition,
    double? userBearing,
    bool animate = true,
  }) async {
    if (!_isValidPosition(userPosition)) return;

    final targetBearing = userBearing != null
        ? _smoothBearing(_currentBearing, userBearing)
        : _currentBearing;

    final useSmoothing = _shouldUsePositionSmoothing(userPosition);
    final cameraPosition =
        useSmoothing ? _smoothPosition(userPosition) : userPosition;

    _currentBearing = targetBearing;
    _currentPitch = _overviewPitch;

    final cameraOptions = mp.CameraOptions(
      center: mp.Point(
        coordinates: mp.Position(
          cameraPosition.longitude,
          cameraPosition.latitude,
        ),
      ),
      zoom: _currentZoom,
      bearing: targetBearing,
      pitch: _currentPitch,
    );

    try {
      if (animate && useSmoothing) {
        await _mapboxMap!.flyTo(
          cameraOptions,
          mp.MapAnimationOptions(duration: 100),
        );
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      try {
        final fallbackOptions = mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
              userPosition.longitude,
              userPosition.latitude,
            ),
          ),
          zoom: _currentZoom,
          bearing: targetBearing,
          pitch: _currentPitch,
        );
        await _mapboxMap!.setCamera(fallbackOptions);
      } catch (fallbackError) {
        // Silently ignore
      }
    }
  }

  void enableNavigationMode() {
    _isNavigationMode = true;
    _isFollowingUser = true;
  }

  void disableNavigationMode() {
    _isNavigationMode = false;
  }

  void enableFollowUser() {
    _isFollowingUser = true;
  }

  void disableFollowUser() {
    _isFollowingUser = false;
  }

  Future<void> setZoom(double zoom, {bool animate = true}) async {
    if (_mapboxMap == null) return;

    _currentZoom = zoom.clamp(1, 22);
    final cameraOptions = mp.CameraOptions(zoom: _currentZoom);

    try {
      if (animate) {
        await _mapboxMap!.flyTo(
          cameraOptions,
          mp.MapAnimationOptions(duration: _animationDuration),
        );
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> setPitch(double pitch, {bool animate = true}) async {
    if (_mapboxMap == null) return;

    _currentPitch = pitch.clamp(0, 60);
    final cameraOptions = mp.CameraOptions(pitch: _currentPitch);

    try {
      if (animate) {
        await _mapboxMap!.flyTo(
          cameraOptions,
          mp.MapAnimationOptions(duration: _animationDuration),
        );
      } else {
        await _mapboxMap!.setCamera(cameraOptions);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> update3DCamera({
    required geo.Position userPosition,
    required double userBearing,
  }) async {
    if (_mapboxMap == null) return;

    _isNavigationMode = true;
    _isFollowingUser = true;

    await _mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(
            userPosition.longitude,
            userPosition.latitude,
          ),
        ),
        zoom: _activeGuidanceZoom,
        bearing: userBearing,
        pitch: kFollowingDefaultPitch,
      ),
      mp.MapAnimationOptions(duration: 2000),
    );

    _currentZoom = _activeGuidanceZoom;
    _currentPitch = kFollowingDefaultPitch;
    _currentBearing = userBearing;
  }

  bool _shouldUsePositionSmoothing(geo.Position userPosition) {
    if (_lastCameraPosition == null) return false;

    final distance = geo.Geolocator.distanceBetween(
      _lastCameraPosition!.latitude,
      _lastCameraPosition!.longitude,
      userPosition.latitude,
      userPosition.longitude,
    );

    return distance < 20.0;
  }

  geo.Position _smoothPosition(geo.Position targetPosition) {
    if (_lastCameraPosition == null) return targetPosition;

    final distance = geo.Geolocator.distanceBetween(
      _lastCameraPosition!.latitude,
      _lastCameraPosition!.longitude,
      targetPosition.latitude,
      targetPosition.longitude,
    );

    if (distance > 50.0) return targetPosition;

    final smoothedLat = _lastCameraPosition!.latitude +
        (targetPosition.latitude - _lastCameraPosition!.latitude) *
            _smoothingFactor;
    final smoothedLng = _lastCameraPosition!.longitude +
        (targetPosition.longitude - _lastCameraPosition!.longitude) *
            _smoothingFactor;

    if (smoothedLat.abs() > 90 || smoothedLng.abs() > 180) {
      return targetPosition;
    }

    return geo.Position(
      latitude: smoothedLat,
      longitude: smoothedLng,
      timestamp: targetPosition.timestamp,
      accuracy: targetPosition.accuracy,
      altitude: targetPosition.altitude,
      altitudeAccuracy: targetPosition.altitudeAccuracy,
      heading: targetPosition.heading,
      headingAccuracy: targetPosition.headingAccuracy,
      speed: targetPosition.speed,
      speedAccuracy: targetPosition.speedAccuracy,
    );
  }

  double _smoothBearing(double currentBearing, double targetBearing) {
    double diff = targetBearing - currentBearing;

    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // Native: max bearing deviation from raw course (45°)
    final clampedDiff = diff.clamp(
      -kBearingSmoothingMaxAngleDegrees,
      kBearingSmoothingMaxAngleDegrees,
    );
    final smoothingFactor = clampedDiff.abs() < 30 ? 0.3 : 0.5;
    return currentBearing + clampedDiff * smoothingFactor;
  }

  bool _isValidPosition(geo.Position position) {
    if (position.latitude.abs() > 90) return false;
    if (position.longitude.abs() > 180) return false;

    if (position.latitude.isNaN ||
        position.latitude.isInfinite ||
        position.longitude.isNaN ||
        position.longitude.isInfinite) {
      return false;
    }

    if (position.latitude == 0 && position.longitude == 0) {
      if (_lastCameraPosition != null) {
        final distance = geo.Geolocator.distanceBetween(
          _lastCameraPosition!.latitude,
          _lastCameraPosition!.longitude,
          0,
          0,
        );
        if (distance > 1000000) return false;
      }
    }

    return true;
  }

  void reset() {
    _lastCameraPosition = null;
    _lastCameraUpdate = null;
    _currentZoom = _defaultZoom;
    _currentPitch = _overviewPitch;
    _currentBearing = 0;
    _isFollowingUser = true;
    _isNavigationMode = false;
  }

  Future<void> fitToRoute(List<PointLatLng> routePoints) async {
    if (_mapboxMap == null || routePoints.isEmpty) return;

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (var point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = mp.CoordinateBounds(
      southwest: mp.Point(coordinates: mp.Position(minLng, minLat)),
      northeast: mp.Point(coordinates: mp.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    final cameraOptions = await _mapboxMap!.cameraForCoordinateBounds(
      bounds,
      mp.MbxEdgeInsets(top: 150.0, left: 80.0, bottom: 200.0, right: 80.0),
      null,
      null,
      null,
      null,
    );

    await _mapboxMap!.flyTo(
      cameraOptions,
      mp.MapAnimationOptions(duration: 1500),
    );

    // Disable follow mode temporarily
    _isFollowingUser = false;
  }

  Future<void> fitToRouteFromMapboxRoute(MapboxRoute route) async {
    if (_mapboxMap == null) return;

    final routePoints = <PointLatLng>[];
    for (final coordinate in route.geometry.coordinates) {
      if (coordinate.length >= 2) {
        routePoints.add(PointLatLng(coordinate[1], coordinate[0])); // lat, lng
      }
    }

    await fitToRoute(routePoints);
  }

  Future<void> forceNavigationZoom(geo.Position currentPosition) async {
    if (_mapboxMap == null) return;

    try {
      await _mapboxMap!.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
              currentPosition.longitude,
              currentPosition.latitude,
            ),
          ),
          zoom: _activeGuidanceZoom,
          bearing: currentPosition.heading >= 0 ? currentPosition.heading : 0,
          pitch: kFollowingDefaultPitch,
        ),
        mp.MapAnimationOptions(duration: 500),
      );
    } catch (e) {
      // Silently ignore
    }
  }

  Future<void> getCurrentCameraState() async {
    if (_mapboxMap == null) return;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      _currentZoom = cameraState.zoom;
      _currentPitch = cameraState.pitch;
      _currentBearing = cameraState.bearing;
    } catch (e) {
      // Silently ignore
    }
  }

  void dispose() {
    _cameraUpdateTimer?.cancel();
    _mapboxMap = null;
  }
}
