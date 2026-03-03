import 'dart:async';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

class CameraController {
  mp.MapboxMap? _mapboxMap;

  double _currentZoom = 15;
  double _currentPitch = 0;
  double _currentBearing = 0;
  bool _isFollowingUser = true;
  bool _isNavigationMode = false;

  geo.Position? _lastCameraPosition;
  DateTime? _lastCameraUpdate;
  Timer? _cameraUpdateTimer;

  static const double _smoothingFactor = 0.3;
  static const double _defaultZoom = 15;
  static const double _navigationZoom = 17;
  static const double _navigationPitch = 0; // Keep flat like Waze
  static const double _overviewPitch = 0;
  static const int _animationDuration = 1000;

  void initialize(mp.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  double get currentZoom => _currentZoom;
  double get currentPitch => _currentPitch;
  double get currentBearing => _currentBearing;
  bool get isFollowingUser => _isFollowingUser;
  bool get isNavigationMode => _isNavigationMode;

  Future<void> updateCamera({
    required geo.Position userPosition,
    double? userBearing,
    bool animate = true,
    bool isOverviewMode = false,
  }) async {
    if (_mapboxMap == null || !_isFollowingUser) return;

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
      _actuallyUpdateCamera(userPosition, userBearing, animate, isOverviewMode);
    });
  }

  Future<void> _actuallyUpdateCamera(
    geo.Position userPosition,
    double? userBearing,
    bool animate,
    bool isOverviewMode,
  ) async {
    if (_mapboxMap == null) return;

    _lastCameraPosition = userPosition;

    if (_isNavigationMode && !isOverviewMode) {
      await _updateNavigationCamera(
        userPosition: userPosition,
        userBearing: userBearing,
        animate: animate,
      );
    } else if (_isNavigationMode && isOverviewMode) {
      await _updateOverviewCamera(
        userPosition: userPosition,
        animate: animate,
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

    await _mapboxMap!.setCamera(cameraOptions);
  }

  Future<void> _updateNavigationCamera({
    required geo.Position userPosition,
    double? userBearing,
    bool animate = true,
  }) async {
    if (!_isValidPosition(userPosition)) return;

    // Calculate speed in km/h (speed is in m/s)
    final speedKmh = userPosition.speed * 3.6;

    // 1. Calculate Target Zoom based on Speed
    // Slow (< 30km/h) -> Zoom 17.5 (Close detail)
    // Fast (> 100km/h) -> Zoom 14.0 (Highway view)
    double targetZoom;
    if (speedKmh < 30) {
      targetZoom = 17.5;
    } else if (speedKmh > 100) {
      targetZoom = 14.0;
    } else {
      // Linear interpolation between 30km/h and 100km/h
      final t = (speedKmh - 30) / (100 - 30);
      targetZoom = 17.5 - (t * (17.5 - 14.0));
    }

    // 2. Calculate Bearing Smoothing based on Speed
    // Stopped/Crawl (< 3km/h) -> Ignore bearing updates (prevent spin)
    // Walking/Driving -> Use smart smoothing
    final targetBearing = userBearing ?? 0;
    
    double smoothedBearing = _currentBearing;
    if (speedKmh > 3.0) { // Lowered to 3 km/h to support walking
       smoothedBearing = _smoothBearing(_currentBearing, targetBearing);
    }

    _currentBearing = smoothedBearing;
    _currentPitch = _navigationPitch;
    
    // Smoothly interpolate zoom
    // We don't want the zoom to jump if speed changes rapidly
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

  Future<void> _updateOverviewCamera({
    required geo.Position userPosition,
    bool animate = true,
  }) async {
    if (!_isValidPosition(userPosition)) return;

    _currentBearing = 0; // North up for overview
    _currentPitch = _overviewPitch;
    _currentZoom = 14; // Zoom out for overview

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

    final targetBearing = userBearing != null ?
        _smoothBearing(_currentBearing, userBearing) : _currentBearing;

    final useSmoothing = _shouldUsePositionSmoothing(userPosition);
    final cameraPosition = useSmoothing ?
        _smoothPosition(userPosition) : userPosition;

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
        zoom: _navigationZoom,
        bearing: userBearing,
        pitch: _navigationPitch,
      ),
      mp.MapAnimationOptions(duration: 2000),
    );

    _currentZoom = _navigationZoom;
    _currentPitch = _navigationPitch;
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

    final smoothingFactor = diff.abs() < 30 ? 0.3 : 0.5;
    return currentBearing + diff * smoothingFactor;
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
          zoom: _navigationZoom,
          bearing: currentPosition.heading >= 0 ? currentPosition.heading : 0,
          pitch: _navigationPitch,
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