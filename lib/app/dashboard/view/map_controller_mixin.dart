import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart' hide TravelMode;
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/gen/assets.gen.dart';
import 'package:waze_kibris/app/dashboard/services/bearing_fusion_service.dart';
import 'package:waze_kibris/app/dashboard/services/snap_to_road_service.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/core/constants/navigation_camera_constants.dart';
import 'package:waze_kibris/core/controllers/camera_controller.dart';
import 'package:waze_kibris/core/services/nav_puck_preference.dart';
import 'package:waze_kibris/core/services/nav_settings.dart';
import 'package:waze_kibris/core/services/puck_icon_factory.dart';
import 'package:waze_kibris/core/services/route_visualization_service.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/utils/report_expiry.dart';
import 'package:waze_kibris/core/models/user/nearby_user.dart';
import 'package:waze_kibris/app/dashboard/modals/report_details_modal.dart';

mixin MapControllerMixin<T extends StatefulWidget> on State<T> {
  mp.MapboxMap? _mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.PointAnnotationManager? reportAnnotationManager;
  mp.PointAnnotationManager? groupAnnotationManager;
  mp.PointAnnotationManager? nearbyUsersAnnotationManager;

  // Camera controller - replaces individual camera variables
  late final CameraController _cameraController;
  // Route visualization service - replaces old polyline drawing
  late final RouteVisualizationService _routeVisualizationService;
  Timer? _reportIconUpdateTimer;

  // Store current reports for zoom updates
  List<ReportData> _currentReports = [];
  List<PointLatLng>? _currentPolylinePoints;

  // Last known user position for recentering
  Position? _lastKnownUserPosition;

  // Map to track annotation ID to report ID mapping
  final Map<String, int> _annotationToReportMap = {};

  // Snap to road service
  final SnapToRoadService _snapToRoadService = SnapToRoadService();

  // Compass/GPS bearing fusion — GPS course is unreliable at low speeds
  final BearingFusionService _bearingFusion = BearingFusionService();

  // ---------------------------------------------------------------------
  // Native viewport (iOS): during navigation the camera is driven by the
  // SDK's FollowPuckViewportState — it consumes the puck's 60fps
  // interpolated position on the render thread, so camera and puck move
  // in perfect lockstep with zero platform-channel latency. This is the
  // same architecture as the native Mapbox Navigation SDK / Google Maps.
  // The Dart CameraController remains the driver on Android (where the
  // course bearing mode isn't available) and for overview/free-drive.
  // ---------------------------------------------------------------------
  mp.ViewportState? _navViewport;

  /// Current viewport for the MapWidget. Null until navigation uses it.
  mp.ViewportState? get navViewport => _navViewport;

  /// FollowPuckViewportStateBearingCourse is iOS-only, so the native
  /// viewport path is too. Android keeps the Dart-driven camera.
  bool get useNativeNavViewport => Platform.isIOS;

  double _nativeViewportZoom = kFollowingMaxZoom;
  double _nativeViewportPitch = kFollowingDefaultPitch;
  bool _nativeBearingIsCourse = false;

  /// Enter (or retune) the native follow-puck viewport. Padding is set
  /// separately on the map camera and is deliberately NOT part of the
  /// state — native leaves it untouched, so the lower-third puck framing
  /// persists. [constantBearing] pins the camera bearing (used at trip
  /// start when GPS course is invalid); when null, the camera follows the
  /// device course.
  void enterNativeFollowViewport({
    double? zoom,
    double? pitch,
    double? constantBearing,
    int maxDurationMs = 2000,
  }) {
    if (!useNativeNavViewport || !mounted) return;
    _nativeViewportZoom = zoom ?? _nativeViewportZoom;
    _nativeViewportPitch = pitch ?? _nativeViewportPitch;
    _nativeBearingIsCourse = constantBearing == null;
    setStateWithViewportAnimation(
      () {
        _navViewport = mp.FollowPuckViewportState(
          zoom: _nativeViewportZoom,
          pitch: _nativeViewportPitch,
          bearing: constantBearing != null
              ? mp.FollowPuckViewportStateBearingConstant(constantBearing)
              : const mp.FollowPuckViewportStateBearingCourse(),
        );
      },
      transition: mp.DefaultViewportTransition(
        maxDuration: Duration(milliseconds: maxDurationMs),
      ),
    );
  }

  /// Reset dynamics and enter the native follow viewport for a new trip.
  /// Initial zoom = native zoomRange upper bound (16.35), which is also
  /// what the native SDK uses as the trip-start zoom.
  void startNativeNavViewport({double? initialBearing}) {
    _cameraController.applyNavigationPaddingNow(_mapboxMapController);
    enterNativeFollowViewport(
      zoom: kFollowingMaxZoom,
      pitch: kFollowingDefaultPitch,
      constantBearing: initialBearing ?? 0,
      maxDurationMs: 1800,
    );
  }

  /// Hand the camera back to Dart control (nav end, overview mode).
  void exitNativeViewport() {
    if (!useNativeNavViewport || !mounted) return;
    if (_navViewport == null || _navViewport is mp.IdleViewportState) return;
    setState(() {
      _navViewport = const mp.IdleViewportState();
    });
  }

  /// Maneuver types that do NOT flatten the camera on approach, per the
  /// native SDK (PitchNearManeuvers.excludedManeuvers).
  static const Set<String> _pitchExcludedManeuvers = {
    'continue',
    'merge',
    'on ramp',
    'off ramp',
    'fork',
  };

  bool _viewportDynamicsBusy = false;

  /// Per-fix retune of the native viewport, mirroring the native
  /// MapboxNavigationViewportDataSource:
  ///  - PITCH ramps linearly 45° → 0° over the last 180m before a maneuver
  ///    (skipped for continue/merge/ramp/fork and the final step).
  ///  - ZOOM frames the road ahead: look-ahead = avg intersection spacing
  ///    × 7, fitted into the padded viewport, clamped to [10.5, 16.35].
  ///    Zoom is NOT speed-based — dense streets zoom in, open roads out.
  ///  - Bearing switches from the pinned departure bearing to live course
  ///    once actually moving.
  /// Values are quantized so a viewport transition only fires on a real
  /// change.
  Future<void> _updateNativeViewportDynamics(
      Position position, SnapToRoadResult? snap) async {
    if (_viewportDynamicsBusy || _mapboxMapController == null) return;
    final navState = navigationBloc.state;
    if (navState is! NavigationInProgress) return;
    _viewportDynamicsBusy = true;
    try {
      // ---- Pitch: native 180m linear ramp ----
      final d = snap?.distanceToCurrentStepManeuverAlongRouteMeters;
      final maneuverType =
          navState.currentStep.maneuver.type.toLowerCase().trim();
      final legSteps = navState.currentLegIndex < navState.route.legs.length
          ? navState.route.legs[navState.currentLegIndex].steps
          : const <MapboxStep>[];
      final isFinalStep = legSteps.isNotEmpty &&
          navState.currentStepIndex >= legSteps.length - 1;

      var targetPitch = kFollowingDefaultPitch;
      if (d != null &&
          d >= 0 &&
          d <= 180 &&
          !isFinalStep &&
          !_pitchExcludedManeuvers.contains(maneuverType)) {
        targetPitch = kFollowingDefaultPitch * (d / 180).clamp(0.0, 1.0);
      }
      targetPitch = (targetPitch / 5).roundToDouble() * 5; // 5° steps

      // ---- Zoom: frame the look-ahead geometry ----
      var targetZoom = _nativeViewportZoom;
      final lookahead = _snapToRoadService.lookaheadDistanceFor(
          navState.currentLegIndex, navState.currentStepIndex);
      final framingPoints =
          _snapToRoadService.getFramingPointsAhead(lookahead);
      if (framingPoints.length >= 2) {
        try {
          final coords = framingPoints
              .map((p) =>
                  mp.Point(coordinates: mp.Position(p.longitude, p.latitude)))
              .toList();
          final fitted = await _mapboxMapController!.cameraForCoordinatesPadding(
            coords,
            mp.CameraOptions(
              bearing: position.heading >= 0 ? position.heading : null,
              pitch: targetPitch,
            ),
            _cameraController.navigationPadding,
            null,
            null,
          );
          final zoom = fitted.zoom;
          if (zoom != null && zoom.isFinite) {
            targetZoom =
                zoom.clamp(kFollowingMinZoom, kFollowingMaxZoom).toDouble();
            targetZoom = (targetZoom * 4).roundToDouble() / 4; // 0.25 steps
          }
        } catch (e) {
          debugPrint('viewport framing zoom failed: $e');
        }
      }

      final speedKmh = position.speed >= 0 ? position.speed * 3.6 : 0.0;
      final needsCourseSwitch = !_nativeBearingIsCourse && speedKmh > 10;

      if (needsCourseSwitch ||
          targetZoom != _nativeViewportZoom ||
          targetPitch != _nativeViewportPitch) {
        enterNativeFollowViewport(
          zoom: targetZoom,
          pitch: targetPitch,
          maxDurationMs: 1200,
        );
      }
    } finally {
      _viewportDynamicsBusy = false;
    }
  }

  /// Minimum distance (m) from user puck for report icons; closer reports are radially offset so they don't cover the puck.
  static const double _puckMinDisplayDistanceMeters = 35.0;

  // Getters for subclasses
  mp.MapboxMap? get mapboxMapController => _mapboxMapController;
  bool get isFollowingUser => _cameraController.isFollowingUser;
  CameraController get cameraController => _cameraController;

  // Navigation bloc must be provided by the implementing class
  NavigationBloc get navigationBloc;

  // Optional method for position updates - can be overridden
  void onPositionUpdate(Position position) {
    // Override in implementing class to handle position updates
  }

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController();
    _routeVisualizationService = RouteVisualizationService();
  }

  // Setters for camera following
  void setIsFollowingUser(bool value) {
    if (value) {
      _cameraController.enableFollowUser();
    } else {
      _cameraController.disableFollowUser();
    }
    // Trigger a rebuild so widgets that read isFollowingUser (e.g. the
    // recenter pill swap) reflect the new state.
    if (mounted) setState(() {});
  }

  /// Call this from map pan/zoom/rotate gesture handlers to exit follow mode
  /// (similar to Mapbox NavigationCamera behavior).
  void onUserMapGesture() {
    if (!_cameraController.isFollowingUser) return; // Already off; skip rebuild
    _cameraController.disableFollowUser();
    if (mounted) setState(() {});
  }

  /// Recenter the map on the user's current (or last known) position
  /// and re-enable follow mode, similar to Waze/Google Maps.
  Future<void> recenterOnUser() async {
    if (_mapboxMapController == null) return;

    // Native nav viewport: recentering is just re-attaching the native
    // follow state — instant, no GPS fix needed, padding persists.
    final navState = navigationBloc.state;
    if (useNativeNavViewport &&
        navState is NavigationInProgress &&
        !navState.isOverviewVisible &&
        _cameraController.isNavigationMode) {
      enterNativeFollowViewport(maxDurationMs: 1500);
      setIsFollowingUser(true);
      return;
    }

    Position? targetPosition;

    try {
      targetPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting current position for recenter: $e');
    }

    targetPosition ??= _lastKnownUserPosition;

    if (targetPosition == null) {
      debugPrint('No known user position available for recenter');
      return;
    }

    await _cameraController.updatePosition(targetPosition);
    setIsFollowingUser(true);
  }

  void onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      _mapboxMapController = controller;
    });

    // Defer heavy style/runtime mutations until after first layout.
    // This helps avoid Mapbox warnings about invalid view sizes and ignored style updates.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _mapboxMapController == null) return;

      // If we already obtained a user position before the map was created,
      // apply an initial camera update now so the map starts centered/zoomed correctly.
      final pendingPos = _lastKnownUserPosition;
      if (pendingPos != null) {
        _mapboxMapController?.easeTo(
          mp.CameraOptions(
            center: mp.Point(
              coordinates:
                  mp.Position(pendingPos.longitude, pendingPos.latitude),
            ),
            zoom: 16.0,
            bearing: 0.0,
            pitch: 0.0,
          ),
          mp.MapAnimationOptions(duration: 750),
        );
      }

      // Zoom limits: match how consumer nav apps constrain the map to
      // "useful" ranges. Beyond zoom 20 there's no more street-level detail
      // to reveal — Mapbox tiles just start pixelating. Below zoom 5 you're
      // staring at a continent, which is useless for turn-by-turn.
      //   Google Maps: 3–21   Apple Maps: 3–20   Waze: 5–19
      await controller.setBounds(
        mp.CameraBoundsOptions(
          minZoom: 5.0,
          maxZoom: 20.0,
        ),
      );

      // Initialize camera controller with map
      _cameraController.initialize(controller);

      // Initialize route visualization service with map (await it)
      await _initializeRouteVisualization(controller);

      // Add report icons to style
      await _addReportIconsToStyle();

      // Setup annotation managers
      await _setupAnnotationManagers();

      // Setup location component with custom CurrentPosition.png
      await _setupLocationPuck();

      // Hide UI elements
      _mapboxMapController?.logo
          .updateSettings(mp.LogoSettings(enabled: false));
      _mapboxMapController?.attribution
          .updateSettings(mp.AttributionSettings(enabled: false));
      // The built-in compass ornament is hidden: its size isn't exposed by
      // the plugin, so aligning it with our own 42pt buttons meant guessing
      // an offset — and it always landed visibly off the menu button's
      // line. We draw our own compass in the Flutter layer instead (see
      // _MapCompassButton), where it shares the exact geometry of the
      // other floating controls.
      _mapboxMapController?.compass
          .updateSettings(mp.CompassSettings(enabled: false));
      _mapboxMapController?.scaleBar
          .updateSettings(mp.ScaleBarSettings(enabled: false));
    });
  }

  /// Snap the map back to north-up, as tapping the compass does in Google
  /// Maps. During navigation the camera is course-up by design, so this
  /// only applies when the user is free-panning.
  Future<void> resetMapBearingToNorth() async {
    final map = _mapboxMapController;
    if (map == null) return;
    if (navigationBloc.state is NavigationInProgress) return;
    try {
      await map.easeTo(
        mp.CameraOptions(bearing: 0),
        mp.MapAnimationOptions(duration: 300),
      );
    } catch (e) {
      debugPrint('⚠️ Reset bearing failed: $e');
    }
  }

  /// The style URI currently applied to the map (set at creation via
  /// MapWidget.styleUri, updated by [applyMapStyleUri]).
  String? _appliedStyleUri;

  /// Record the style the MapWidget was created with, so runtime switches
  /// can no-op when nothing changed.
  void markInitialStyleApplied(String uri) {
    _appliedStyleUri ??= uri;
  }

  /// Switch the map style at runtime (day/night). A style reload wipes every
  /// runtime source, layer, and image, so everything is rebuilt afterwards.
  Future<void> applyMapStyleUri(String uri) async {
    final map = _mapboxMapController;
    if (map == null) return;
    if (uri == _appliedStyleUri) return;
    _appliedStyleUri = uri;

    try {
      await map.loadStyleURI(uri);

      // Rebuild everything the reload destroyed.
      await _routeVisualizationService.initialize(map);
      await _addReportIconsToStyle();
      await _setupAnnotationManagers();
      await _setupLocationPuck();

      // Let the host screen restore route drawing etc.
      onMapStyleReloaded();

      debugPrint('🎨 Map style switched to $uri');
    } catch (e) {
      debugPrint('❌ Failed to switch map style: $e');
    }
  }

  /// Hook for the host screen to restore state after a style reload
  /// (e.g. redraw the active route). Override in the implementing class.
  void onMapStyleReloaded() {}

  /// Create (or re-create) the point annotation managers. Re-runnable: a
  /// style reload wipes the layers the managers own, so callers can invoke
  /// this again after switching map styles.
  Future<void> _setupAnnotationManagers() async {
    final map = _mapboxMapController;
    if (map == null) return;

    // Best-effort removal of stale managers from a previous style.
    for (final manager in [
      pointAnnotationManager,
      reportAnnotationManager,
      groupAnnotationManager,
      nearbyUsersAnnotationManager,
    ]) {
      if (manager != null) {
        try {
          await map.annotations.removeAnnotationManager(manager);
        } catch (_) {
          // Manager may already be gone with the old style.
        }
      }
    }

    pointAnnotationManager = await map.annotations.createPointAnnotationManager();

    final reportManager = await map.annotations.createPointAnnotationManager();
    reportManager.tapEvents(onTap: _onReportAnnotationTap);
    reportAnnotationManager = reportManager;

    groupAnnotationManager = await map.annotations.createPointAnnotationManager();
    nearbyUsersAnnotationManager =
        await map.annotations.createPointAnnotationManager();

    if (mounted) setState(() {});

    // Display any reports that arrived before the managers were ready.
    if (mounted && _currentReports.isNotEmpty) {
      await displayReportsOnMap(_currentReports);
    }
  }

  /// Initialize route visualization service asynchronously
  Future<void> _initializeRouteVisualization(mp.MapboxMap controller) async {
    try {
      await _routeVisualizationService.initialize(controller);
      debugPrint(
          '✅ RouteVisualizationService initialized in MapControllerMixin');
    } catch (e) {
      debugPrint('❌ Failed to initialize RouteVisualizationService: $e');
    }
  }

  /// Display reports using PointAnnotations with click handling and smart positioning
  Future<void> displayReportsOnMap(List<ReportData> reports) async {
    // Expired reports never show; muted types are hidden per the user's
    // Alerts & reports settings (also suppresses their proximity alerts,
    // since those read from _currentReports).
    final filtered = filterNonExpiredReports(reports)
        .where((r) => NavSettings.isReportTypeEnabled(r.type))
        .toList();
    _currentReports = filtered;
    if (reportAnnotationManager == null || !mounted) return;

    try {
      // Clear existing report annotations and mapping
      await reportAnnotationManager!.deleteAll();
      _annotationToReportMap.clear();

      // Get current zoom level for smart clustering
      final cameraState = await _mapboxMapController?.getCameraState();
      final zoom = cameraState?.zoom ?? 14.0;

      // Group reports by proximity (Waze-style clustering); optionally offset clusters near user puck
      final clusters = _clusterReports(filtered, zoom, _lastKnownUserPosition);

      // Create annotations for each cluster
      for (final cluster in clusters) {
        final iconId = _getReportIcon(cluster.reports.first.type);

        // Calculate offset for overlapping reports
        final offset = cluster.offset;

        final annotation = await reportAnnotationManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(
              coordinates: mp.Position(
                cluster.longitude,
                cluster.latitude,
              ),
            ),
            iconImage: iconId,
            iconSize: 0.7,
            iconAnchor: mp.IconAnchor.BOTTOM,
            iconOffset: offset,
          ),
        );

        // Map annotation ID to the first (or most important) report in cluster
        _annotationToReportMap[annotation.id] = cluster.reports.first.id;
      }

      debugPrint(
          '✅ Displayed ${clusters.length} report annotations (${filtered.length} reports total, ${reports.length - filtered.length} expired skipped)');

      // Saved pins are positioned to avoid reports, so a change in the
      // report set means they may need to move.
      await refreshSavedPlaces();
    } catch (e) {
      debugPrint('❌ Error displaying reports on map: $e');
    }
  }

  /// Display nearby connected users on the map (driver/user pins). Does not include the current user.
  Future<void> displayNearbyUsersOnMap(List<NearbyUser> users) async {
    if (nearbyUsersAnnotationManager == null || !mounted) return;

    try {
      await nearbyUsersAnnotationManager!.deleteAll();

      for (final user in users) {
        await nearbyUsersAnnotationManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(
              coordinates: mp.Position(user.longitude, user.latitude),
            ),
            iconImage: 'group-member-icon',
            iconSize: 0.8,
            iconAnchor: mp.IconAnchor.BOTTOM,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error displaying nearby users on map: $e');
    }
  }

  /// Cluster nearby reports to prevent overlap (Waze-style). If [userPosition] is set, clusters very close to the user are radially offset so they don't cover the puck.
  List<_ReportCluster> _clusterReports(
    List<ReportData> reports,
    double zoom, [
    Position? userPosition,
  ]) {
    final clusters = <_ReportCluster>[];
    final processed = <int>{};

    // Distance threshold based on zoom level (in degrees, ~meters)
    // At zoom 14: ~50m, zoom 16: ~20m, zoom 18: ~5m
    final threshold = 0.0005 / math.pow(2, zoom - 14);

    for (var i = 0; i < reports.length; i++) {
      if (processed.contains(i)) continue;

      final report = reports[i];
      final nearbyReports = <ReportData>[report];
      processed.add(i);

      // Find nearby reports
      for (var j = i + 1; j < reports.length; j++) {
        if (processed.contains(j)) continue;

        final other = reports[j];
        final distance = _calculateReportDistance(report, other);

        if (distance < threshold) {
          nearbyReports.add(other);
          processed.add(j);
        }
      }

      // Display position: optionally push away from user puck so report doesn't cover it
      double displayLat = report.latitude;
      double displayLon = report.longitude;
      if (userPosition != null) {
        final pos = _clusterDisplayPositionNearPuck(
          userPosition.latitude,
          userPosition.longitude,
          report.latitude,
          report.longitude,
          _puckMinDisplayDistanceMeters,
        );
        displayLat = pos.lat;
        displayLon = pos.lon;
      }

      // Create cluster with offset for overlapping reports
      if (nearbyReports.length == 1) {
        // Single report - no offset
        clusters.add(_ReportCluster(
          reports: nearbyReports,
          latitude: displayLat,
          longitude: displayLon,
          offset: [0, 0],
        ));
      } else {
        // Multiple reports at same location - create fan pattern
        for (var k = 0; k < nearbyReports.length; k++) {
          final angle = (k * 360 / nearbyReports.length) * (math.pi / 180);
          final radius =
              zoom > 15 ? 25.0 : 20.0; // Wider offset for better separation

          double fanLat = nearbyReports[k].latitude;
          double fanLon = nearbyReports[k].longitude;
          if (userPosition != null) {
            final pos = _clusterDisplayPositionNearPuck(
              userPosition.latitude,
              userPosition.longitude,
              nearbyReports[k].latitude,
              nearbyReports[k].longitude,
              _puckMinDisplayDistanceMeters,
            );
            fanLat = pos.lat;
            fanLon = pos.lon;
          }

          clusters.add(_ReportCluster(
            reports: [nearbyReports[k]],
            latitude: fanLat,
            longitude: fanLon,
            offset: [
              radius * math.cos(angle),
              -radius * math.sin(angle),
            ],
          ));
        }
      }
    }

    return clusters;
  }

  /// Calculate distance between two reports in degrees
  double _calculateReportDistance(ReportData a, ReportData b) {
    final dx = a.longitude - b.longitude;
    final dy = a.latitude - b.latitude;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Distance in meters between two lat/lon points (Haversine via Geolocator).
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2).toDouble();
  }

  /// If (targetLat, targetLon) is within [minDistanceMeters] of (userLat, userLon), returns the point at [minDistanceMeters] from user in the direction of target (radial offset). Otherwise returns (targetLat, targetLon).
  ({double lat, double lon}) _clusterDisplayPositionNearPuck(
    double userLat,
    double userLon,
    double targetLat,
    double targetLon,
    double minDistanceMeters,
  ) {
    final dist = _distanceMeters(userLat, userLon, targetLat, targetLon);
    if (dist >= minDistanceMeters || dist < 1) {
      return (lat: targetLat, lon: targetLon);
    }
    // Bearing from user to target (radians)
    const toRad = math.pi / 180;
    final dLon = (targetLon - userLon) * toRad;
    final lat1 = userLat * toRad;
    final lat2 = targetLat * toRad;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearingRad = math.atan2(y, x);
    // Destination point at minDistanceMeters from user (standard formula)
    const R = 6371000.0;
    final lon1Rad = userLon * toRad;
    final ang = minDistanceMeters / R;
    final newLatRad = math.asin(math.sin(lat1) * math.cos(ang) +
        math.cos(lat1) * math.sin(ang) * math.cos(bearingRad));
    final newLonRad = lon1Rad +
        math.atan2(
          math.sin(bearingRad) * math.sin(ang) * math.cos(lat1),
          math.cos(ang) - math.sin(lat1) * math.sin(newLatRad),
        );
    return (
      lat: newLatRad / toRad,
      lon: newLonRad / toRad,
    );
  }

  /// Handle tap on report annotation
  void _onReportAnnotationTap(mp.PointAnnotation annotation) {
    try {
      // Get report ID from mapping
      final reportId = _annotationToReportMap[annotation.id];
      if (reportId == null) {
        debugPrint('⚠️ No report found for annotation ${annotation.id}');
        return;
      }

      debugPrint('👆 Tapped on report: $reportId');

      // Find the full report data
      final report = _currentReports.firstWhere(
        (r) => r.id == reportId,
        orElse: () {
          debugPrint('⚠️ Report $reportId not found in current reports');
          return _currentReports.first;
        },
      );

      // Show details modal from TOP (Waze-style)
      if (mounted) {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black.withOpacity(0.3),
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) {
            // The Material ancestor is required: without it every Text in the
            // sheet falls back to Flutter's debug style (yellow double
            // underlines) because there is no default text style in scope.
            return Align(
              alignment: Alignment.topCenter,
              child: Material(
                type: MaterialType.transparency,
                child: ReportDetailsModal(report: report),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1), // Start from above the screen
                end: Offset.zero, // Slide down to position
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              )),
              child: child,
            );
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling report tap: $e');
    }
  }

  /// Get appropriate icon ID for report type
  String _getReportIcon(String reportType) {
    switch (reportType.toLowerCase()) {
      case 'police':
        return 'police-icon';
      case 'traffic':
        return 'traffic-icon';
      case 'accident':
        return 'accident-icon';
      case 'photosharing':
        return 'photo-icon';
      default:
        return 'police-icon'; // Default fallback
    }
  }

  /// Switch the map's location component into or out of navigation mode.
  ///
  /// Both modes now use the built-in [LocationComponent] puck rather than
  /// a custom SymbolLayer. Mapbox internally interpolates the puck at 60fps
  /// via CADisplayLink from the raw 1Hz GPS stream — running our own
  /// AnimationController on top only re-broke the interpolation.
  ///
  /// Nav mode uses [PuckBearing.COURSE] (direction of movement) so the
  /// puck arrow points along the route. Free-drive uses no bearing.
  void updateMapForNavigationMode(bool isNavigating) async {
    if (_mapboxMapController == null) return;

    if (isNavigating) {
      _cameraController.enableNavigationMode();
    } else {
      _cameraController.disableNavigationMode();
      // Return camera control to Dart (free-drive follow / idle).
      exitNativeViewport();
    }

    final locationPuckBytes = await _loadLocationPuckImage();

    await _mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: isNavigating,
        puckBearing: mp.PuckBearing.COURSE,
        locationPuck: mp.LocationPuck(
          locationPuck2D: mp.LocationPuck2D(
            topImage: locationPuckBytes,
            scaleExpression: json.encode([
              'interpolate',
              ['linear'],
              ['zoom'],
              10.0,
              0.85,
              14.0,
              1.0,
              18.0,
              1.15,
              22.0,
              1.2,
            ]),
          ),
        ),
        pulsingColor: 0xFF4285F4,
        pulsingEnabled: false,
        showAccuracyRing: !isNavigating,
      ),
    );
  }


  // Removed: Old drawPolyline method - now using professional LineLayer approach

  /// Draw route using advanced RouteVisualizationService
  Future<void> drawMapboxPolyline(
    MapboxRoute route, {
    List<MapboxRoute>? alternativeRoutes,
    bool fitCamera = true,
  }) async {
    await clearRoutePolyline();

    if (_mapboxMapController == null) {
      debugPrint('Map controller not ready.');
      return;
    }

    try {
      // Convert Mapbox geometry coordinates to PointLatLng for marker placement
      final List<PointLatLng> routePoints = [];
      for (final coordinate in route.geometry.coordinates) {
        if (coordinate.length >= 2) {
          routePoints
              .add(PointLatLng(coordinate[1], coordinate[0])); // lat, lng
        }
      }

      if (routePoints.isEmpty) {
        debugPrint('Mapbox route has no geometry points.');
        return;
      }

      // Store points for adaptive updates
      _currentPolylinePoints = routePoints;

      // Use RouteVisualizationService to draw the route (+ optional grey alternatives)
      await _routeVisualizationService.drawRoute(
        route,
        alternativeRoutes: alternativeRoutes,
      );

      // Update SnapToRoadService with the new route
      _snapToRoadService.setMapboxRoute(route);

      // Add route markers using existing functionality
      await _addRouteMarkers(routePoints);

      // Fit camera to route bounds — only for route preview. During active
      // navigation (start + reroute redraws) the nav camera owns the
      // viewport; fitting here would yank it out to overview.
      if (fitCamera) {
        await _fitCameraToRoute(routePoints);
      }

      debugPrint('Advanced route visualization created successfully');
    } catch (e) {
      debugPrint('Error creating route visualization: $e');
      // Could implement user notification here
    }
  }

  /// Update route progress during navigation
  Future<void> updateRouteProgress(
    MapboxRoute route,
    int currentStepIndex, {
    int currentLegIndex = 0,
    Position? currentPosition,
    bool forceUpdate = false,
  }) async {
    if (_mapboxMapController == null) return;

    try {
      await _routeVisualizationService.updateRouteProgress(
        route,
        currentStepIndex,
        currentLegIndex: currentLegIndex,
        currentPosition: currentPosition,
        forceUpdate: forceUpdate,
      );
    } catch (e) {
      debugPrint('Error updating route progress: $e');
    }
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(PointLatLng point1, PointLatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // ── Route waypoint markers (origin + destination) ──────────────────────
  //
  // Ported from mapbox-navigation-android's MapboxRouteLineUtils.kt waypoint
  // layer (lines 2011-2077). Instead of using PointAnnotationManager (which
  // takes a fixed iconSize), we render the origin/destination pins via a
  // proper SymbolLayer with `iconSizeExpression` — so Mapbox scales them
  // smoothly with zoom the same way it does its own POIs and labels. That's
  // what fixes the "giant pin at overview zoom" problem for good: no
  // resampling, no reload, no polling.

  static const String _waypointSourceId = 'route-waypoint-source';
  static const String _waypointLayerId = 'route-waypoint-layer';
  static const String _originImageId = 'route-origin-marker';
  static const String _destinationImageId = 'destination-marker';

  Future<void> _addRouteMarkers(List<PointLatLng> points) async {
    if (_mapboxMapController == null || points.isEmpty) return;

    // Make sure both images are registered with the style. `destination-
    // marker` uses the existing high-res asset; the origin gets a small
    // programmatic circle (matches Android's mapbox_ic_route_origin.xml).
    await _addDestinationImageToStyle();
    await _addOriginImageToStyle();

    // Build / refresh the GeoJSON. During active turn-by-turn navigation
    // we suppress the origin marker — the built-in Mapbox puck already
    // represents the driver's position, and a static origin pin left on
    // the trip start becomes visual noise as soon as you drive off. Native
    // Waze / Google Maps do the same: origin visible in route preview and
    // overview only, hidden during follow-mode driving.
    final isNavigating = navigationBloc.state is NavigationInProgress;
    final origin = points.first;
    final destination = points.last;
    final features = <Map<String, dynamic>>[
      if (!isNavigating)
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [origin.longitude, origin.latitude],
          },
          'properties': {'icon': _originImageId},
        },
      {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [destination.longitude, destination.latitude],
        },
        'properties': {'icon': _destinationImageId},
      },
    ];
    final geoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    final sourceExists =
        await _mapboxMapController!.style.styleSourceExists(_waypointSourceId);
    if (sourceExists) {
      await _mapboxMapController!.style
          .setStyleSourceProperty(_waypointSourceId, 'data', geoJson);
    } else {
      await _mapboxMapController!.style.addSource(
        mp.GeoJsonSource(id: _waypointSourceId, data: geoJson),
      );
    }

    final layerExists =
        await _mapboxMapController!.style.styleLayerExists(_waypointLayerId);
    if (!layerExists) {
      try {
        await _mapboxMapController!.style.addLayer(
          mp.SymbolLayer(
            id: _waypointLayerId,
            sourceId: _waypointSourceId,
            iconImageExpression: ['get', 'icon'],
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconAnchor: mp.IconAnchor.BOTTOM,
            // Native Mapbox waypoint curve (exp 1.5) from RouteLineUtils.kt.
            // The image registers at 48×54 pt logical (4.0x asset at its own
            // density). The destination is the single most important marker
            // on the map, so it sits a little larger than the saved-place
            // pins rather than competing with them at the same size.
            iconSizeExpression: [
              'interpolate',
              ['exponential', 1.5],
              ['zoom'],
              0.0, 0.42,
              10.0, 0.60,
              12.0, 0.75,  // city overview (~40 pt)
              14.0, 0.92,  // area view (~50 pt)
              16.0, 1.05,  // street level (~57 pt)
              19.0, 1.20,
              22.0, 1.40,  // max zoom (~76 pt)
            ],
          ),
        );
        debugPrint('✅ Waypoint SymbolLayer added');
      } catch (e) {
        debugPrint('❌ Failed to add waypoint SymbolLayer: $e');
      }
    } else {
      debugPrint('ℹ️  Waypoint layer already existed, source refreshed');
    }

    try {
      await _mapboxMapController!.style
          .moveStyleLayer(_waypointLayerId, null); // Move to top
      debugPrint('✅ Moved waypoint layer to top (origin=${origin.latitude},${origin.longitude} dest=${destination.latitude},${destination.longitude})');
    } catch (e) {
      debugPrint('⚠️ Error moving waypoint layer: $e');
    }
  }

  Future<void> clearRoutePolyline() async {
    // Clear route using RouteVisualizationService
    await _routeVisualizationService.clearRoute();

    // Clear route in SnapToRoadService
    _snapToRoadService.clearRoute();

    // Clear route waypoint markers (SymbolLayer). Any legacy annotations
    // from the pre-SymbolLayer era are cleaned up too, so downgrades don't
    // leave orphan pins on the map.
    if (_mapboxMapController != null) {
      try {
        if (await _mapboxMapController!.style
            .styleLayerExists(_waypointLayerId)) {
          await _mapboxMapController!.style.removeStyleLayer(_waypointLayerId);
        }
        if (await _mapboxMapController!.style
            .styleSourceExists(_waypointSourceId)) {
          await _mapboxMapController!.style
              .removeStyleSource(_waypointSourceId);
        }
      } catch (e) {
        debugPrint('⚠️ Error clearing waypoint layer: $e');
      }
    }
    await pointAnnotationManager?.deleteAll();

    // Clear stored polyline data
    _currentPolylinePoints = null;
  }

  // ── Saved places (Home / Work / …) ────────────────────────────────────
  //
  // Rendered as a SymbolLayer rather than annotations so the pins scale
  // smoothly with zoom and carry their name as a map label, the same way
  // Mapbox draws its own POIs. Tapping one starts navigation there.

  static const String _savedSourceId = 'saved-places-source';
  static const String _savedLayerId = 'saved-places-layer';
  static const String _savedPinImageId = 'saved-place-pin';

  List<SavedLocations> _savedPlaces = const [];

  /// Callback invoked when a saved-place pin is tapped. Set by the host
  /// screen so it can open the route sheet for that destination.
  void Function(SavedLocations place)? onSavedPlaceTapped;

  /// Draw (or refresh) the saved-place pins. Safe to call repeatedly; a
  /// style reload re-runs it via [refreshSavedPlaces].
  Future<void> displaySavedPlacesOnMap(List<SavedLocations> places) async {
    _savedPlaces = places;
    final map = _mapboxMapController;
    if (map == null || !mounted) return;

    try {
      await _addSavedPinImageToStyle();

      final features = places.map((p) {
        // Saved places are fixed points, but the puck and live reports can
        // land right on top of one (you're parked at home and someone
        // reports traffic outside). Nudge the pin clear so all three stay
        // separately visible and tappable.
        final display = _savedPinDisplayPosition(p);
        return {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [display.lon, display.lat],
          },
          'properties': {
            'id': p.id,
            'name': p.name,
            'icon': savedPinImageFor(p.name),
          },
        };
      }).toList();
      final geoJson =
          jsonEncode({'type': 'FeatureCollection', 'features': features});

      if (await map.style.styleSourceExists(_savedSourceId)) {
        await map.style.setStyleSourceProperty(_savedSourceId, 'data', geoJson);
      } else {
        await map.style
            .addSource(mp.GeoJsonSource(id: _savedSourceId, data: geoJson));
      }

      if (!await map.style.styleLayerExists(_savedLayerId)) {
        await map.style.addLayer(
          mp.SymbolLayer(
            id: _savedLayerId,
            sourceId: _savedSourceId,
            // Per-place icon (house / briefcase / bookmark), like Waze.
            iconImageExpression: ['get', 'icon'],
            iconAnchor: mp.IconAnchor.BOTTOM,
            // Let Mapbox's collision engine hide a saved pin when something
            // more urgent (a live report) already occupies that spot —
            // reports are transient and time-critical, a saved place is
            // neither and the user knows where their own home is.
            iconAllowOverlap: false,
            iconIgnorePlacement: false,
            // Lower sort key = drawn first and wins collisions. Reports sit
            // above saved places (see _reportSymbolSortKey).
            symbolSortKey: 10,
            // The image registers at 48×60 pt logical (see
            // _addSavedPinImageToStyle), so these factors put the pin at
            // ~48 pt tall at street zoom — a comfortable touch target —
            // shrinking to ~29 pt at city overview.
            // Pin artwork is 66pt tall at scale 1.0; these land it around
            // 50pt at street zoom — big enough to hit comfortably without
            // dominating the map — and ~33pt when zoomed right out.
            iconSizeExpression: [
              'interpolate',
              ['exponential', 1.5],
              ['zoom'],
              0.0, 0.50,
              12.0, 0.66,
              14.0, 0.72,
              16.0, 0.76,
              19.0, 0.84,
              22.0, 0.92,
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error drawing saved places: $e');
    }
  }

  /// Minimum separation (metres) between a saved pin and the puck or a
  /// report icon before we start displacing it.
  static const double _savedPinClearanceMeters = 35;

  /// Where a saved-place pin should actually draw, given what else is on
  /// the map right now. Displaces it away from the user puck and from any
  /// nearby report so the icons don't stack.
  ({double lat, double lon}) _savedPinDisplayPosition(SavedLocations place) {
    var lat = place.latitude;
    var lon = place.longitude;

    // 1. Clear the user puck.
    final user = _lastKnownUserPosition;
    if (user != null) {
      final moved = _clusterDisplayPositionNearPuck(
        user.latitude,
        user.longitude,
        lat,
        lon,
        _savedPinClearanceMeters,
      );
      lat = moved.lat;
      lon = moved.lon;
    }

    // 2. Clear any report sitting on the same spot. Reports win the
    //    position because they're transient and time-critical.
    for (final report in _currentReports) {
      final d = _distanceMeters(report.latitude, report.longitude, lat, lon);
      if (d < _savedPinClearanceMeters) {
        final moved = _clusterDisplayPositionNearPuck(
          report.latitude,
          report.longitude,
          lat,
          lon,
          _savedPinClearanceMeters,
        );
        lat = moved.lat;
        lon = moved.lon;
      }
    }

    return (lat: lat, lon: lon);
  }

  /// Re-draw saved places after a style reload wiped the runtime layers.
  Future<void> refreshSavedPlaces() async {
    if (_savedPlaces.isNotEmpty) {
      await displaySavedPlacesOnMap(_savedPlaces);
    }
  }

  /// Hit-test a tap against the saved-place layer, returning the place that
  /// was tapped (if any).
  Future<SavedLocations?> _savedPlaceAt(mp.MapContentGestureContext ctx) async {
    final map = _mapboxMapController;
    if (map == null || _savedPlaces.isEmpty) return null;
    try {
      if (!await map.style.styleLayerExists(_savedLayerId)) return null;

      // Small slop around the finger, nothing more. An oversized box makes
      // taps on empty map "hit" a pin that is merely nearby — the box only
      // has to overlap the pin's rendered bounds, so padding downward by
      // 40pt meant a tap well below the pin still caught it.
      const double padX = 12;
      const double padTop = 12;
      const double padBottom = 12;
      final box = mp.RenderedQueryGeometry.fromScreenBox(
        mp.ScreenBox(
          min: mp.ScreenCoordinate(
            x: ctx.touchPosition.x - padX,
            y: ctx.touchPosition.y - padTop,
          ),
          max: mp.ScreenCoordinate(
            x: ctx.touchPosition.x + padX,
            y: ctx.touchPosition.y + padBottom,
          ),
        ),
      );
      final hits = await map.queryRenderedFeatures(
        box,
        mp.RenderedQueryOptions(layerIds: [_savedLayerId], filter: null),
      );
      debugPrint('📍 Saved-place hit-test: ${hits.length} feature(s)');
      if (hits.isEmpty) return null;

      // With several pins close together the query can return more than
      // one; pick whichever is actually nearest the finger rather than
      // whatever the renderer happened to list first.
      SavedLocations? best;
      var bestDistance = double.infinity;
      for (final hit in hits) {
        final props = hit?.queriedFeature.feature['properties'];
        if (props is! Map) continue;
        // The platform channel may hand back numbers as num or String,
        // so parse defensively rather than casting.
        final id = int.tryParse(props['id']?.toString() ?? '');
        if (id == null) continue;
        for (final place in _savedPlaces) {
          if (place.id != id) continue;
          // Use the *drawn* position: pins are displaced away from the
          // puck and reports, so the saved coordinate isn't where the
          // icon actually is.
          final drawn = _savedPinDisplayPosition(place);
          final screen = await map.pixelForCoordinate(
            mp.Point(coordinates: mp.Position(drawn.lon, drawn.lat)),
          );
          final dx = screen.x - ctx.touchPosition.x;
          final dy = screen.y - ctx.touchPosition.y;
          final distance = math.sqrt(dx * dx + dy * dy);
          if (distance < bestDistance) {
            bestDistance = distance;
            best = place;
          }
        }
      }

      // Final guard: the pin's anchor is at its base, so a legitimate tap
      // lands within roughly the pin's height of it. Anything further away
      // is the renderer being generous, not the user aiming at this pin.
      const double maxTapDistance = 56;
      if (best != null && bestDistance > maxTapDistance) {
        debugPrint(
            '📍 Ignoring saved-place hit ${bestDistance.round()}pt away');
        return null;
      }
      return best;
    } catch (e) {
      debugPrint('⚠️ Saved place hit-test failed: $e');
    }
    return null;
  }

  /// Which pin image a saved place uses, keyed off its name the way Waze
  /// does (house for Home, briefcase for Work, bookmark for the rest).
  static String savedPinImageFor(String name) {
    final n = name.trim().toLowerCase();
    if (n == 'home' || n == 'house') return '$_savedPinImageId-home';
    if (n == 'work' || n == 'office') return '$_savedPinImageId-work';
    return '$_savedPinImageId-default';
  }

  /// Waze-style saved-place pin: a white teardrop with a coloured glyph
  /// inside. Drawn programmatically, one image per place kind.
  Future<void> _addSavedPinImageToStyle() async {
    final map = _mapboxMapController;
    if (map == null || !mounted) return;

    const kinds = <String, (IconData, Color)>{
      'home': (Icons.home_rounded, Color(0xFFE53935)),
      'work': (Icons.work_rounded, Color(0xFFC97A20)),
      'default': (Icons.bookmark_rounded, Color(0xFFFF7043)),
    };

    for (final entry in kinds.entries) {
      final imageId = '$_savedPinImageId-${entry.key}';
      try {
        if (await map.style.hasStyleImage(imageId)) continue;

        // Drawn at 4× so it stays crisp when the zoom curve scales it up.
        const double scale = 4;
        const double ptW = 52; // logical size once registered at `scale`
        const double ptH = 66;
        final w = (ptW * scale).round();
        final h = (ptH * scale).round();

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(scale);

        const centre = Offset(ptW / 2, ptW / 2);
        const radius = 24.0;

        // Soft drop shadow so the pin lifts off the map.
        canvas.drawCircle(
          centre.translate(0, 2),
          radius,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

        // White teardrop: circle head + tapered tail, as in Waze.
        final pin = Paint()..color = Colors.white;
        final tail = Path()
          ..moveTo(ptW / 2 - 9, ptW / 2 + 17)
          ..quadraticBezierTo(ptW / 2, ptH - 9, ptW / 2, ptH - 1)
          ..quadraticBezierTo(ptW / 2, ptH - 9, ptW / 2 + 9, ptW / 2 + 17)
          ..close();
        canvas.drawPath(tail, pin);
        canvas.drawCircle(centre, radius, pin);

        // Tinted disc + glyph inside the head.
        final (iconData, colour) = entry.value;
        canvas.drawCircle(
          centre,
          radius - 3.5,
          Paint()..color = colour.withValues(alpha: 0.16),
        );

        final painter = TextPainter(textDirection: TextDirection.ltr)
          ..text = TextSpan(
            text: String.fromCharCode(iconData.codePoint),
            style: TextStyle(
              fontSize: 27,
              fontFamily: iconData.fontFamily,
              package: iconData.fontPackage,
              color: colour,
            ),
          )
          ..layout();
        painter.paint(
          canvas,
          centre - Offset(painter.width / 2, painter.height / 2),
        );

        final image = await recorder.endRecording().toImage(w, h);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (bytes == null || !mounted || _mapboxMapController == null) return;

        await _mapboxMapController!.style.addStyleImage(
          imageId,
          scale, // asset's own density — 176px renders at 44pt logical
          mp.MbxImage(width: w, height: h, data: bytes.buffer.asUint8List()),
          false,
          [],
          [],
          null,
        );
      } catch (e) {
        debugPrint('⚠️ Error creating saved place pin $imageId: $e');
      }
    }
  }

  /// Registers a small circle-in-circle image (mirrors Android's
  /// `mapbox_ic_route_origin.xml`: grey outer, white inner) as the origin pin.
  /// Drawn programmatically so we don't have to ship yet another asset.
  Future<void> _addOriginImageToStyle() async {
    if (_mapboxMapController == null || !mounted) return;
    try {
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      const int pxSize = 96; // 48pt at 2× — matches native waypoint size
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final center = const ui.Offset(pxSize / 2, pxSize / 2);
      // Outer ring: mid-grey, matches Android colorPrimary casing shade
      canvas.drawCircle(
        center,
        pxSize * 0.42,
        ui.Paint()
          ..color = const ui.Color(0xFF546E7A)
          ..style = ui.PaintingStyle.fill
          ..isAntiAlias = true,
      );
      // Inner dot: white
      canvas.drawCircle(
        center,
        pxSize * 0.22,
        ui.Paint()
          ..color = const ui.Color(0xFFFFFFFF)
          ..style = ui.PaintingStyle.fill
          ..isAntiAlias = true,
      );

      final image = await recorder.endRecording().toImage(pxSize, pxSize);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      await _mapboxMapController!.style.addStyleImage(
        _originImageId,
        devicePixelRatio,
        mp.MbxImage(
          width: pxSize,
          height: pxSize,
          data: byteData.buffer.asUint8List(),
        ),
        false,
        [],
        [],
        null,
      );
    } catch (e) {
      debugPrint('Error adding origin image to style: $e');
    }
  }

  /// Calculate adaptive report icon size based on zoom level
  Future<double> _getAdaptiveReportIconSize() async {
    if (_mapboxMapController == null) return 0.7;

    try {
      final cameraState = await _mapboxMapController?.getCameraState();
      if (cameraState == null) return 0.7;

      final zoom = cameraState.zoom;

      // Report icon sizing - smaller than route markers but still responsive
      if (zoom >= 19) {
        return 1.2; // Very close zoom - larger reports
      } else if (zoom >= 18) {
        return 1.0; // Close zoom - standard size
      } else if (zoom >= 16) {
        return 0.8; // Medium-close zoom
      } else if (zoom >= 14) {
        return 0.7; // Medium zoom - default size
      } else if (zoom >= 12) {
        return 0.6; // Medium-far zoom
      } else if (zoom >= 10) {
        return 0.5; // Far zoom - smaller
      } else {
        return 0.4; // Very far zoom - minimal but visible
      }
    } catch (e) {
      debugPrint('Error getting camera state for report icon size: $e');
      return 0.7;
    }
  }

  Future<void> _fitCameraToRoute(List<PointLatLng> points) async {
    // Use camera controller for route fitting
    await _cameraController.fitToRoute(points);
  }

  Future<void> setupPositionTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // On Android, use foreground notification so location updates continue when app is backgrounded
    // distanceFilter: 0 → get every GPS event (typically ~1Hz on iOS/Android).
    // With filter=10 you only get an update every 10m, which at 30km/h is
    // 1.2s between events — long enough for the camera to visibly stall
    // between updates. The SDK / our camera easeTo handles interpolation.
    final LocationSettings locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Waze Kibris',
              notificationText: 'Using your location for navigation',
              notificationChannelName: 'Navigation',
              setOngoing: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            // CoreLocation's own driving model (road-aware filtering) only
            // kicks in with the automotive activity type.
            activityType: ActivityType.automotiveNavigation,
            distanceFilter: 0,
            // iOS defaults to auto-pausing updates when it thinks you've
            // stopped — which freezes navigation at a long red light.
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );

    _userPositionStream?.cancel();

    // Refresh location puck now that we have permissions (fixes iOS startup issue)
    if (_mapboxMapController != null) {
      await _setupLocationPuck();
    }

    // Get current position immediately and move camera to user location
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
          // locationSettings: locationSettings,
          );

      // Cache for cases where map isn't ready yet (onMapCreated will apply it).
      _lastKnownUserPosition = currentPosition;

      // Move camera to user location immediately with Waze-like zoom
      _mapboxMapController?.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
                currentPosition.longitude, currentPosition.latitude),
          ),
          zoom: 16.0, // Waze-style zoom level
          bearing: 0.0,
          pitch: 0.0,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
    }

    _bearingFusion.start();

    _userPositionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position rawPosition) async {
        // Fuse GPS course with compass so the puck stays stable at low speed.
        // Snap-to-road (below) can still override with the route bearing.
        final fusedBearing = _bearingFusion.fuse(rawPosition);
        final Position position = fusedBearing == null
            ? rawPosition
            : Position(
                latitude: rawPosition.latitude,
                longitude: rawPosition.longitude,
                timestamp: rawPosition.timestamp,
                accuracy: rawPosition.accuracy,
                altitude: rawPosition.altitude,
                altitudeAccuracy: rawPosition.altitudeAccuracy,
                heading: fusedBearing,
                headingAccuracy: rawPosition.headingAccuracy,
                speed: rawPosition.speed,
                speedAccuracy: rawPosition.speedAccuracy,
              );

        // Cache last known position for recenter button
        _lastKnownUserPosition = position;

        // Apply snap-to-road during navigation
        final currentState = navigationBloc.state;
        Position processedPosition = position;

        SnapToRoadResult? snapResultForBloc;
        if (currentState is NavigationInProgress) {
          try {
            final snapResult = await _snapToRoadService.snapToRoad(
              position,
              currentLegIndex: currentState.currentLegIndex,
              currentStepIndex: currentState.currentStepIndex,
            );
            snapResultForBloc = snapResult;

            // Create new position with snapped coordinates and route bearing
            processedPosition = Position(
              latitude: snapResult.snappedPosition.latitude,
              longitude: snapResult.snappedPosition.longitude,
              timestamp: position.timestamp,
              accuracy: position.accuracy,
              altitude: position.altitude,
              altitudeAccuracy: position.altitudeAccuracy,
              heading: snapResult.bearing, // Use calculated route bearing
              headingAccuracy: position.headingAccuracy,
              speed: position.speed,
              speedAccuracy: position.speedAccuracy,
            );

            // Log route status for debugging
            if (snapResult.needsReroute) {
              debugPrint(
                  '🔄 REROUTE NEEDED: ${snapResult.distanceFromRoute.toStringAsFixed(1)}m from route');
            } else if (snapResult.isOffRoute) {
              debugPrint(
                  '⚠️ USER OFF ROUTE: ${snapResult.distanceFromRoute.toStringAsFixed(1)}m away');
            } else if (snapResult.isOnRoute) {
              debugPrint(
                  '✅ ON ROUTE: Progress ${(snapResult.routeProgress * 100).toStringAsFixed(1)}%');
            }
          } catch (e) {
            debugPrint('Snap-to-road error: $e');
            // Use original position if snapping fails
            processedPosition = position;
          }
        }

        // Send processed position to navigation bloc (with optional snap/along-route data for native parity)
        navigationBloc.add(NavigationPositionUpdated(
          position: processedPosition,
          distanceToManeuverAlongRouteMeters:
              snapResultForBloc?.distanceToCurrentStepManeuverAlongRouteMeters,
          remainingDistanceAlongRouteMeters:
              snapResultForBloc?.remainingDistanceAlongRouteMeters,
          isOffRouteFromSnap: snapResultForBloc?.isOffRoute,
          needsRerouteFromSnap: snapResultForBloc?.needsReroute,
        ));

        // Reroute is triggered by bloc when it sees needsRerouteFromSnap on the event (single source of truth)

        // Notify implementing class of position update
        onPositionUpdate(processedPosition);

        // Update map camera when following user, or when in overview mode so overview moves with user
        final isNavigating = currentState is NavigationInProgress;
        final inOverview = isNavigating && currentState.isOverviewVisible;
        final nativeViewportDrives =
            useNativeNavViewport && isNavigating && !inOverview;
        if (_mapboxMapController != null &&
            (_cameraController.isFollowingUser || inOverview)) {
          if (nativeViewportDrives) {
            // Camera is driven natively by FollowPuckViewportState; Dart
            // only retunes zoom/pitch/bearing-mode when targets change.
            _updateNativeViewportDynamics(processedPosition, snapResultForBloc);
          } else {
            updateMapCamera(
              processedPosition,
              distanceToManeuverAlongRouteMeters: snapResultForBloc
                  ?.distanceToCurrentStepManeuverAlongRouteMeters,
              remainingDistanceAlongRouteMeters:
                  snapResultForBloc?.remainingDistanceAlongRouteMeters,
            );
          }
        }

        // Puck position is now driven by the built-in LocationComponent,
        // which reads directly from CoreLocation / FusedLocationProvider
        // and interpolates at 60fps. No manual per-frame update needed.
      },
      onError: (Object error) {
        debugPrint('Position stream error: $error');
      },
    );
  }

  /// Pause position tracking when the app goes to background.
  void pausePositionTracking() {
    _userPositionStream?.pause();
  }

  /// Resume tracking and immediately refresh navigation state when app resumes.
  ///
  /// This ensures the puck, route split, and maneuvers catch up after the app
  /// has been in the background for a while.
  Future<void> resumeTrackingAndRefreshNavigation(
      NavigationBloc navigationBloc) async {
    if (_userPositionStream == null) {
      // Stream was never started or was cancelled; set it up again.
      await setupPositionTracking();
    } else if (_userPositionStream!.isPaused) {
      _userPositionStream!.resume();
    }

    // Use the last known position if we have it; otherwise, query it.
    Position? lastPosition = _lastKnownUserPosition;
    if (lastPosition == null) {
      try {
        lastPosition = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint('Error getting last known position on resume: $e');
      }
    }

    if (lastPosition == null) return;

    // Notify subclass and bloc of this position so any dependent UI can update.
    onPositionUpdate(lastPosition);

    final currentState = navigationBloc.state;
    if (currentState is NavigationInProgress) {
      await updateRouteProgress(
        currentState.route,
        currentState.currentStepIndex,
        currentLegIndex: currentState.currentLegIndex,
        currentPosition: lastPosition,
        forceUpdate: true,
      );
    }
  }

  void updateMapCamera(
    Position position, {
    double? distanceToManeuverAlongRouteMeters,
    double? remainingDistanceAlongRouteMeters,
  }) {
    if (_mapboxMapController == null) return;

    final currentState = navigationBloc.state;
    final isOverviewMode =
        currentState is NavigationInProgress && currentState.isOverviewVisible;

    // When in overview, frame remaining route (native-style overview)
    final remainingRouteForOverview =
        isOverviewMode ? _snapToRoadService.getRemainingRoutePoints() : null;

    // Use camera controller for all camera updates (pass snap-based distances for native parity)
    _cameraController.updateCamera(
      userPosition: position,
      userBearing: position.heading >= 0 ? position.heading : null,
      isOverviewMode: isOverviewMode,
      distanceToManeuverAlongRouteMeters: distanceToManeuverAlongRouteMeters,
      remainingDistanceAlongRouteMeters: remainingDistanceAlongRouteMeters,
      remainingRouteForOverview: remainingRouteForOverview,
    );

    // Update report icons after camera change
    _debouncedUpdateReportIconSizes();
  }

  // Removed: _actuallyUpdateCamera - now handled by CameraController

  /// Handle map tap events - delegates to layer-specific tap interactions
  void onMapTap(mp.MapContentGestureContext context) async {
    // Saved places are the only tappable map content besides reports (which
    // have their own annotation tap handler).
    final place = await _savedPlaceAt(context);
    if (place != null) {
      onSavedPlaceTapped?.call(place);
    }
  }

  /// Debounced report icon size update to prevent excessive recreations
  void _debouncedUpdateReportIconSizes() {
    _reportIconUpdateTimer?.cancel();
    _reportIconUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      // _updateReportIconSizes(); // No longer needed with clustering layers
      // _updatePuckSize(); // No longer needed with SymbolLayer expressions
    });
  }

  /// Update navigation puck size based on zoom level
  // Future<void> _updatePuckSize() async {
  //   // Removed: Handled by SymbolLayer expression
  // }

  // Removed _updateReportIconSizes as layer handles sizing
  // Future<void> _updateReportIconSizes() async { ... }

  // Removed _updateMarkersForZoom — waypoint SymbolLayer now handles zoom
  // scaling via iconSizeExpression (see _addRouteMarkers), so no per-tick
  // repopulation is needed.

  // Removed: LineLayer handles zoom-based width automatically

  /// Force immediate navigation zoom without delays.
  ///
  /// [initialBearing] is the route's departure bearing so the map rotates
  /// course-up right away even when the car hasn't moved yet (GPS course
  /// is invalid at a standstill).
  void forceNavigationZoom({double? initialBearing}) async {
    if (_mapboxMapController == null) return;

    try {
      // Use the cached position so the camera responds instantly; only
      // block on a fresh fix when we have nothing at all.
      final currentPosition =
          _lastKnownUserPosition ?? await Geolocator.getCurrentPosition();

      await _cameraController.forceNavigationZoom(
        currentPosition,
        initialBearing: initialBearing,
      );
    } catch (e) {
      debugPrint('Error forcing navigation zoom: $e');
    }
  }

  /// Compute and apply the nav-mode viewport padding from the map's laid-out
  /// size. Top padding pushes the camera center down so the puck sits at
  /// ~70% of screen height and the viewport shows road ahead, matching
  /// Waze/Google framing. Mapbox expects physical pixels on Android and
  /// logical points on iOS.
  void updateNavigationViewportPadding(
      double mapHeightLogical, double devicePixelRatio) {
    final scale = Platform.isAndroid ? devicePixelRatio : 1.0;
    _cameraController.setNavigationPadding(
      mp.MbxEdgeInsets(
        top: mapHeightLogical * 0.4 * scale,
        left: 0,
        bottom: 0,
        right: 0,
      ),
    );
  }

  /// Initialize snap-to-road service with route data
  void initializeSnapToRoad(
    MapboxRoute route, {
    PlacesService? placesService,
    TravelMode mode = TravelMode.drive,
  }) {
    debugPrint('Initializing snap-to-road with Mapbox route (mode: $mode)');
    _snapToRoadService.setMapboxRoute(route);
    _snapToRoadService.applyTravelMode(mode);

    // Set PlacesService for Map Matching functionality
    if (placesService != null) {
      _snapToRoadService.setPlacesService(placesService);
      debugPrint('🗺️ Map Matching enabled for edge cases');
    }
  }

  /// Clear snap-to-road service
  void clearSnapToRoad() {
    debugPrint('Clearing snap-to-road service');
    _snapToRoadService.clearRoute();
  }

  /// Load location puck image from assets with proper resolution handling
  Future<Uint8List> _loadLocationPuckImage() async {
    // Travel mode wins over the vehicle preference: showing a car while
    // the user is walking is simply wrong, whatever they picked in
    // settings. Matches Google/Apple Maps.
    final mode = NavPuckPreference.mode.value;
    if (mode != NavPuckMode.vehicle) {
      final bytes = await PuckIconFactory.renderMode(mode);
      if (bytes != null) return bytes;
    }

    // Vehicle pucks (car/bus/truck) are rendered at runtime — the native
    // SDKs only ship the chevron, so these are ours (PuckIconFactory).
    final style = NavPuckPreference.style.value;
    if (style != NavPuckStyle.arrow) {
      final bytes = await PuckIconFactory.render(style);
      if (bytes != null) return bytes;
    }
    // Default arrow: force the 4.0x resolution for maximum sharpness.
    final ByteData byteData =
        await rootBundle.load('assets/icons/4.0x/CurrentPosition.png');
    return byteData.buffer.asUint8List();
  }

  /// Re-apply the location puck (e.g. after the user picks a different
  /// vehicle icon in settings).
  Future<void> refreshLocationPuck() => _setupLocationPuck();

  // /// Load destination marker image from assets with proper resolution handling
  // Future<Uint8List> _loadDestinationImage() async {
  //   // Force load the 4.0x resolution for maximum sharpness (same as CurrentPosition)
  //   final ByteData byteData =
  //       await rootBundle.load('assets/icons/destination.png');
  //   return byteData.buffer.asUint8List();
  // }

  // /// Add destination marker image to map style
  // Future<void> _addDestinationImageToStyle() async {
  //   if (_mapboxMapController == null) return;

  //   try {
  //     // Load the destination image
  //     final destinationImageBytes = await _loadDestinationImage();

  //     // Create MbxImage from the bytes (adjusted to match LocationPuck size)
  //     final mbxImage = mp.MbxImage(
  //       width: 48,
  //       height: 48,
  //       data: destinationImageBytes,
  //     );

  //     // Add image to map style with a unique ID
  //     await _mapboxMapController!.style.addStyleImage(
  //       'destination-marker',
  //       1.0, // Scale factor
  //       mbxImage,
  //       false, // SDF (Signed Distance Field) - false for bitmap images
  //       [], // StretchX - empty for normal images
  //       [], // StretchY - empty for normal images
  //       null, // Content - null for normal images
  //     );
  //   } catch (e) {
  //     debugPrint('Error adding destination image to style: $e');
  //   }
  // }

  Future<void> _addDestinationImageToStyle() async {
    if (_mapboxMapController == null || !mounted) return;

    try {
      // Highest-res variant (192×215 px) registered at its own 4.0 density,
      // so the pin's logical size is 48×54 pt regardless of screen DPR and
      // stays sharp when the zoom curve scales it up.
      final ByteData byteData =
          await rootBundle.load('assets/icons/4.0x/destination.png');
      final Uint8List imageBytes = byteData.buffer.asUint8List();

      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final mbxImage = mp.MbxImage(
        width: image.width,
        height: image.height,
        data: imageBytes,
      );

      if (!mounted || _mapboxMapController == null) return;

      await _mapboxMapController!.style.addStyleImage(
        'destination-marker',
        4.0, // asset's own density — NOT screen DPR (see comment above)
        mbxImage,
        false,
        [], // StretchX - empty for normal images
        [], // StretchY - empty for normal images
        null, // Content - null for normal images
      );
    } catch (e) {
      debugPrint('Error adding destination image to style: $e');
    }
  }

  /// Load and add report icons to map style
  Future<void> _addReportIconsToStyle() async {
    if (_mapboxMapController == null || !mounted) return;

    try {
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

      // Map of icon IDs to IconData and Color
      final icons = {
        'police-icon': (Icons.local_police, Colors.blue),
        'traffic-icon': (Icons.traffic, Colors.red),
        'accident-icon': (Icons.car_crash, Colors.orange),
        'photo-icon': (Icons.photo_camera, Colors.purple),
        'group-member-icon': (Icons.person_pin, Colors.green),
      };

      for (final entry in icons.entries) {
        final iconId = entry.key;
        final iconData = entry.value.$1;
        final color = entry.value.$2;

        try {
          // Generate icon image
          final image = await _generateReportIcon(iconData, color);

          if (image == null) continue;

          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) continue;

          final imageBytes = byteData.buffer.asUint8List();

          final mbxImage = mp.MbxImage(
            width: image.width,
            height: image.height,
            data: imageBytes,
          );

          if (!mounted || _mapboxMapController == null) return;

          await _mapboxMapController!.style.addStyleImage(
            iconId,
            devicePixelRatio,
            mbxImage,
            false,
            [],
            [],
            null,
          );
          debugPrint('✅ Added $iconId to map style');
        } catch (e) {
          debugPrint('❌ Error adding $iconId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error adding report icons to style: $e');
    }
  }

  /// Helper to generate report icon using Canvas
  Future<ui.Image?> _generateReportIcon(IconData icon, Color color,
      {Size size = const Size(64, 64)}) async {
    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

      final int width = (size.width * devicePixelRatio).toInt();
      final int height = (size.height * devicePixelRatio).toInt();

      // Scale canvas
      canvas.scale(devicePixelRatio);

      final double centerX = size.width / 2;
      final double centerY = size.height / 2;
      final double radius = size.width / 2;

      // Draw background circle
      final ui.Paint paint = ui.Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // The disc is deliberately smaller than the canvas: the glyph fills
      // most of it, so the icon reads as the symbol itself rather than a
      // symbol floating in a large white ring.
      final double discRadius = radius - 9;

      // Draw shadow
      canvas.drawCircle(
        Offset(centerX, centerY + 1.5),
        discRadius,
        ui.Paint()
          ..color = Colors.black.withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Draw white circle
      canvas.drawCircle(Offset(centerX, centerY), discRadius, paint);

      // Draw colored circle
      paint.color = color.withOpacity(0.1);
      canvas.drawCircle(Offset(centerX, centerY), discRadius, paint);

      // Draw Icon
      final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          // ~85% of the disc, so the padding around the glyph is a thin
          // ring instead of a wide margin.
          fontSize: discRadius * 1.7,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
            centerX - textPainter.width / 2, centerY - textPainter.height / 2),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(width, height);

      return image;
    } catch (e) {
      debugPrint('Error generating report icon: $e');
      return null;
    }
  }

  /// Refresh location puck to ensure it stays on top of route layers
  void _refreshLocationPuckOnTop() {
    if (_mapboxMapController == null || !mounted) return;
    try {
      // Re-enable the location component which brings it to the top layer
      _mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
          puckBearing: mp.PuckBearing.COURSE,
          pulsingEnabled: true,
          showAccuracyRing: false,
          pulsingColor: 0xFF4285F4, // Blue pulsing color
        ),
      );

      debugPrint('🎯 Location puck refreshed to stay on top of route layers');
    } catch (e) {
      debugPrint('Error refreshing location puck: $e');
    }
  }

  /// Setup location puck with custom image
  Future<void> _setupLocationPuck() async {
    if (_mapboxMapController == null || !mounted) return;
    try {
      final locationPuckBytes = await _loadLocationPuckImage();

      if (!mounted || _mapboxMapController == null) return;

      await _mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
          puckBearing: mp.PuckBearing.COURSE,
          locationPuck: mp.LocationPuck(
            locationPuck2D: mp.LocationPuck2D(
              topImage: locationPuckBytes,
              scaleExpression: json.encode([
                'interpolate',
                ['linear'],
                ['zoom'],
                10.0,
                1.0,
                16.0,
                1.2,
                20.0,
                1.3
              ]),
            ),
          ),
          pulsingColor: 0xFF4285F4, // Blue for default mode
          pulsingEnabled: true,
          showAccuracyRing: false,
        ),
      );
    } catch (e) {
      debugPrint('Error setting up location puck: $e');
      // Fallback to default location puck
      if (mounted && _mapboxMapController != null) {
        await _mapboxMapController?.location.updateSettings(
          mp.LocationComponentSettings(
            enabled: true,
            puckBearingEnabled: true,
            puckBearing: mp.PuckBearing.COURSE,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _userPositionStream?.cancel();
    _bearingFusion.dispose();
    _reportIconUpdateTimer?.cancel();
    reportAnnotationManager?.deleteAll();
    _cameraController.dispose(); // Clean up camera controller
    _routeVisualizationService
        .dispose(); // Clean up route visualization service
    // _mapboxMapController?.dispose(); // REMOVED: Managed by MapWidget
    super.dispose();
  }

  /// Display other users in the group on the map
  Future<void> displayGroupLocationsOnMap(
      Map<String, dynamic> groupLocations) async {
    if (groupAnnotationManager == null || !mounted) return;

    try {
      await groupAnnotationManager!.deleteAll();

      for (final entry in groupLocations.entries) {
        final loc = entry.value as Map<String, dynamic>;
        final lat = loc['lat'] as double?;
        final lng = loc['lng'] as double?;

        if (lat != null && lng != null) {
          await groupAnnotationManager!.create(
            mp.PointAnnotationOptions(
              geometry: mp.Point(
                coordinates: mp.Position(lng, lat),
              ),
              iconImage: 'group-member-icon',
              iconSize: 0.8,
              iconAnchor: mp.IconAnchor.BOTTOM,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error displaying group locations: $e');
    }
  }
}

/// Helper class for report clustering
class _ReportCluster {
  final List<ReportData> reports;
  final double latitude;
  final double longitude;
  final List<double> offset;

  _ReportCluster({
    required this.reports,
    required this.latitude,
    required this.longitude,
    required this.offset,
  });
}
