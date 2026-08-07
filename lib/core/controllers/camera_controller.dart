import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:flutter_polyline_points/flutter_polyline_points.dart' hide TravelMode;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/services/nav_trace_recorder.dart';
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

  /// When our own camera animation is expected to finish.
  ///
  /// Mapbox reports programmatic camera moves through the same
  /// scroll/zoom listeners as finger gestures, so without this the
  /// follow-camera's own easeTo reads as "the user panned" and switches
  /// following off. Anything arriving before this instant is ours.
  DateTime? _programmaticMoveUntil;

  /// True while a camera move we initiated is still settling.
  bool get isAnimatingProgrammatically {
    final until = _programmaticMoveUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// Mark that we are about to drive the camera for [durationMs].
  /// A small grace period covers the listener firing just after the
  /// animation completes.
  void _markProgrammaticMove(int durationMs) {
    _programmaticMoveUntil = DateTime.now()
        .add(Duration(milliseconds: durationMs + 250));
  }

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

  /// Viewport padding during navigation follow mode. Pushes the camera
  /// center down so the puck sits in the lower third of the screen and
  /// most of the viewport shows the road ahead (Waze/Google framing).
  /// Set from the map's layout via [setNavigationPadding].
  mp.MbxEdgeInsets? _navPadding;

  /// Timestamp of the previous navigation camera update, used to measure
  /// the real GPS cadence so the easeTo animation spans the whole gap
  /// between fixes instead of finishing early and stalling.
  DateTime? _lastNavCameraUpdate;
  int _navEaseDurationMs = 1000;

  static const double _smoothingFactor = 0.3;

  /// Base blend for camera rotation, per GPS fix (~1 Hz). Low enough that
  /// the map leans into a turn rather than snapping; [_smoothBearing] scales
  /// it up with the size of the turn.
  static const double _bearingSmoothingFactor = 0.25;
  static const double _defaultZoom = 15;
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
  bool get isCourseUp => _isCourseUp;

  void toggleCourseUp() {
    _isCourseUp = !_isCourseUp;
  }

  /// Set the navigation viewport padding (screen px, already scaled for the
  /// platform's expected units by the caller). Applied to every nav-mode
  /// camera update so the puck rides in the lower portion of the screen.
  void setNavigationPadding(mp.MbxEdgeInsets padding) {
    _navPadding = padding;
  }

  /// The nav viewport padding, for callers that need to fit geometry into
  /// the same padded box the camera uses (native-style framed zoom).
  mp.MbxEdgeInsets? get navigationPadding => _navPadding;

  /// Mapbox keeps the last-set padding when CameraOptions.padding is null,
  /// so non-nav camera modes must explicitly clear it or the nav offset
  /// leaks into overview / free-drive framing.
  static mp.MbxEdgeInsets get _zeroPadding =>
      mp.MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0);

  /// Immediately write the nav padding onto the map camera. Used before
  /// handing the camera to the native FollowPuckViewportState, which
  /// deliberately never modifies padding — so whatever is set here defines
  /// the puck's on-screen anchor for the whole native-driven session.
  void applyNavigationPaddingNow(mp.MapboxMap? map) {
    final target = map ?? _mapboxMap;
    if (target == null || _navPadding == null) return;
    target.setCamera(mp.CameraOptions(padding: _navPadding));
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

    // No distance-skip / debounce — native Mapbox drives the camera every
    // render frame (60Hz) via ValueInterpolator. Skipping small updates or
    // debouncing here creates the "stuttery" feel; we want every GPS event
    // to flow into an easeTo that runs until the next one.
    _actuallyUpdateCamera(
      userPosition,
      userBearing,
      animate,
      isOverviewMode,
      distanceToManeuverAlongRouteMeters: distanceToManeuverAlongRouteMeters,
      remainingDistanceAlongRouteMeters: remainingDistanceAlongRouteMeters,
      remainingRouteForOverview: remainingRouteForOverview,
    );
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

  }

  /// Duration for recenter (my location) animation — Waze-style smooth ease.
  static const int _recenterAnimationDurationMs = 700;

  Future<void> updatePosition(geo.Position position) async {
    if (_mapboxMap == null) return;

    // During navigation the recenter action should return the camera to
    // the full navigation preset (3D pitch, course-up bearing, active
    // guidance zoom) — not just re-center on the current lat/lng with
    // whatever pitch/bearing/zoom the free-drive session was in.
    final targetZoom = _isNavigationMode ? _activeGuidanceZoom : _currentZoom;
    final targetPitch =
        _isNavigationMode ? kFollowingDefaultPitch : _currentPitch;
    final targetBearing = position.heading >= 0
        ? position.heading
        : (_isNavigationMode ? _currentBearing : 0.0);

    final cameraOptions = mp.CameraOptions(
      center: mp.Point(
        coordinates: mp.Position(
          position.longitude,
          position.latitude,
        ),
      ),
      padding: _isNavigationMode ? _navPadding : _zeroPadding,
      zoom: targetZoom,
      bearing: targetBearing,
      pitch: targetPitch,
    );

    // Keep internal state in sync so the next per-GPS-tick nav update
    // doesn't unwind what recenter just set.
    _currentZoom = targetZoom;
    _currentPitch = targetPitch;
    _currentBearing = targetBearing;
    // Nav camera's first-frame snap so smoothing doesn't spin the camera
    // from wherever it was to the course bearing over multiple updates.
    if (_isNavigationMode) _pendingNavBearingSnap = true;

    try {
      _markProgrammaticMove(_recenterAnimationDurationMs);
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

    // 2. Pitch: flatten near maneuver so driver sees the intersection from
    // above; otherwise keep default 3D perspective (native ~45°).
    if (distanceToManeuverAlongRouteMeters != null &&
        distanceToManeuverAlongRouteMeters <= kPitchNearManeuverTriggerMeters) {
      _currentPitch = kPitchNearManeuverValue;
    } else {
      _currentPitch = kFollowingDefaultPitch;
    }

    // 3. Bearing: apply user's course whenever we have one. Native uses the
    // course bearing directly and lets the 450ms easeTo do the smoothing;
    // no per-step clamps, no low-speed gates that leave the camera stuck
    // facing north while the car drives south.
    if (!_isCourseUp) {
      _currentBearing = 0.0;
    } else if (userBearing != null) {
      if (_pendingNavBearingSnap) {
        _currentBearing = userBearing;
        _pendingNavBearingSnap = false;
      } else {
        _currentBearing = _smoothBearing(_currentBearing, userBearing);
      }
    }
    // If userBearing is null (GPS heading unknown), keep _currentBearing
    // as-is rather than snapping to 0 — that's what caused the "map not
    // facing user heading" bug at the start of a trip.
    final smoothedBearing = _currentBearing;

    // Smoothly interpolate zoom. Native uses ~0.15 (converges over ~4 updates
    // instead of ~20 with 0.05) so speed-based zoom actually reacts.
    _currentZoom = _currentZoom + (targetZoom - _currentZoom) * 0.15;

    final cameraOptions = mp.CameraOptions(
      center: mp.Point(
        coordinates: mp.Position(
          userPosition.longitude,
          userPosition.latitude,
        ),
      ),
      padding: _navPadding,
      zoom: _currentZoom,
      bearing: smoothedBearing, // Follow user's heading
      pitch: _currentPitch,
    );

    NavTraceRecorder.instance.log('camera', {
      'lat': r(userPosition.latitude),
      'lng': r(userPosition.longitude),
      // requested vs applied shows the smoothing at work: a large gap means
      // the camera is easing (expected in a turn) or lagging (a problem).
      'bearingRequested': r(userBearing, 1),
      'bearingApplied': r(smoothedBearing, 1),
      'zoom': r(_currentZoom, 2),
      'zoomTarget': r(targetZoom, 2),
      'pitch': r(_currentPitch, 1),
      'speedKmh': r(speedKmh, 1),
      'courseUp': _isCourseUp,
      'easeMs': animate ? _navEaseDurationMs : 0,
      'distToManeuver': r(distanceToManeuverAlongRouteMeters, 1),
    });

    // The ease must span the whole gap until the next GPS fix, or the
    // camera glides then freezes (animation done, no new target yet).
    // Measure the real cadence and animate slightly past it so the next
    // fix always lands on a still-moving camera.
    final now = DateTime.now();
    if (_lastNavCameraUpdate != null) {
      final intervalMs = now.difference(_lastNavCameraUpdate!).inMilliseconds;
      if (intervalMs > 0) {
        _navEaseDurationMs =
            ((intervalMs * 1.15).round()).clamp(400, 2000);
      }
    }
    _lastNavCameraUpdate = now;

    try {
      _markProgrammaticMove(animate ? _navEaseDurationMs : 0);
      await _mapboxMap!.easeTo(
        cameraOptions,
        mp.MapAnimationOptions(duration: animate ? _navEaseDurationMs : 0),
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
        padding: _zeroPadding,
        zoom: _currentZoom,
        bearing: 0,
        pitch: _currentPitch,
      );
      try {
        _markProgrammaticMove(animate ? 1500 : 0);
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
      padding: _zeroPadding,
      zoom: _currentZoom,
      bearing: _currentBearing,
      pitch: _currentPitch,
    );

    try {
      _markProgrammaticMove(animate ? 1500 : 0);
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
      padding: _zeroPadding,
      zoom: _currentZoom,
      bearing: targetBearing,
      pitch: _currentPitch,
    );

    try {
      if (animate && useSmoothing) {
        _markProgrammaticMove(100);
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

  /// Set to true when nav mode starts so the first _updateNavigationCamera
  /// call can snap-to-course rather than interpolating from bearing 0°
  /// (which would spin the camera at trip start).
  bool _pendingNavBearingSnap = false;

  void enableNavigationMode() {
    _isNavigationMode = true;
    _isFollowingUser = true;
    _pendingNavBearingSnap = true;
    // Starting navigation triggers a burst of camera work we don't own —
    // drawing the route, fitting waypoints, dismissing the route sheet. Those
    // surface as scroll callbacks and would switch following straight back
    // off, leaving the map north-up for the whole trip. Ignore gesture
    // callbacks until that burst settles; a real pan after this still works.
    _markProgrammaticMove(1500);
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
        _markProgrammaticMove(_animationDuration);
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
        _markProgrammaticMove(_animationDuration);
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

    _markProgrammaticMove(2000);
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

    // Re-assert following *after* the flyTo. Drawing the route and dismissing
    // the sheet move the camera too, and any stray scroll callback from that
    // would otherwise leave navigation starting with following already off —
    // a north-up map that never rotates.
    _isFollowingUser = true;
    _pendingNavBearingSnap = true;

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

  /// Bearing is normalized to the shortest-path direction (so a 350°→10°
  /// change goes +20°, not −340°) then passed through directly. The 450ms
  /// easeTo on the map itself is what smooths it — mirroring native, where
  /// the animation duration provides the smoothing rather than per-step
  /// angle caps that make the camera physically unable to keep up with a
  /// turning driver.
  /// Ease the camera toward the route bearing instead of snapping to it.
  ///
  /// This used to return the target verbatim — the shortest-angle unwrap was
  /// there, but no actual smoothing — so every bearing change jumped. Waze
  /// leans into a turn: the map starts rotating as you approach the corner
  /// and settles as you come out of it.
  ///
  /// Small corrections track almost 1:1 so the map still feels responsive on
  /// a straight road; big swings (a 90° turn) ease over a few fixes.
  double _smoothBearing(double currentBearing, double targetBearing) {
    double diff = targetBearing - currentBearing;
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // Blend harder the bigger the turn, so sharp corners still complete
    // quickly rather than lagging the car through the junction.
    final magnitude = diff.abs();
    final factor = magnitude < 5
        ? 1.0 // tiny drift: track exactly, no visible lag
        : (_bearingSmoothingFactor + (magnitude / 180.0) * 0.35)
            .clamp(0.0, 1.0);

    return currentBearing + diff * factor;
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
    _lastNavCameraUpdate = null;
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

    _markProgrammaticMove(1500);
    await _mapboxMap!.flyTo(
      cameraOptions,
      mp.MapAnimationOptions(duration: 1500),
    );

    // Route preview: stop following so the fitted frame stays put. During
    // active navigation we must NOT drop follow mode — a route redraw
    // (reroute, refresh) would otherwise freeze the nav camera until the
    // user notices the recenter pill.
    if (!_isNavigationMode) {
      _isFollowingUser = false;
    }
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

  /// Snap the camera into the full navigation preset. [initialBearing]
  /// should be the route's departure bearing — at trip start the car is
  /// usually stationary, so GPS course is invalid (0/-1) and using it
  /// would leave the map facing north instead of down the route.
  Future<void> forceNavigationZoom(
    geo.Position currentPosition, {
    double? initialBearing,
  }) async {
    if (_mapboxMap == null) return;

    final bearing = initialBearing ??
        (currentPosition.heading >= 0 ? currentPosition.heading : 0.0);

    // Sync internal state so per-GPS-tick updates continue smoothly from
    // this preset instead of re-animating from stale values.
    _currentZoom = _activeGuidanceZoom;
    _currentPitch = kFollowingDefaultPitch;
    _currentBearing = bearing;
    _pendingNavBearingSnap = false;

    try {
      _markProgrammaticMove(900);
      await _mapboxMap!.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
              currentPosition.longitude,
              currentPosition.latitude,
            ),
          ),
          padding: _navPadding,
          zoom: _activeGuidanceZoom,
          bearing: bearing,
          pitch: kFollowingDefaultPitch,
        ),
        mp.MapAnimationOptions(duration: 900),
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
    _mapboxMap = null;
  }
}
