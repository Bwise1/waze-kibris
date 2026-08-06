import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

/// Advanced route visualization service with progress tracking and directional arrows
class RouteVisualizationService {
  static const String _routeSourceId = 'route-source';
  static const String _routeLayerId = 'route-layer-main';
  static const String _routeBorderLayerId = 'route-layer-border';
  static const String _traveledRouteLayerId =
      'route-layer-traveled'; // New layer for traveled route
  // Maneuver arrow — mirrors mapbox-navigation-{android,ios} which draw a
  // single arrow at the *next* turn (shaft + head, with dark blue casings).
  // NOT walking chevrons along the whole route — that's a Google/Waze pattern,
  // not a Mapbox one. See RouteArrowUtils.kt / ManeuverArrowMapFeatures.swift.
  static const String _arrowShaftSourceId =
      'mapbox-navigation-arrow-shaft-source';
  static const String _arrowHeadSourceId =
      'mapbox-navigation-arrow-head-source';
  static const String _arrowShaftLayerId =
      'mapbox-navigation-arrow-shaft-layer';
  static const String _arrowShaftCasingLayerId =
      'mapbox-navigation-arrow-shaft-casing-layer';
  static const String _arrowHeadLayerId = 'mapbox-navigation-arrow-head-layer';
  static const String _arrowHeadCasingLayerId =
      'mapbox-navigation-arrow-head-casing-layer';
  // Legacy — kept only for cleanup / dispose. Not created anymore.
  static const String _arrowSourceId = 'route-arrows-source';
  static const String _arrowLayerId = 'route-arrows-layer';
  static const String _laneGuidanceSourceId = 'lane-guidance-source';
  static const String _laneGuidanceLayerId = 'lane-guidance-layer';

  static const String _altSource0 = 'route-alt-src-0';
  static const String _altLayer0 = 'route-alt-layer-0';
  static const String _altSource1 = 'route-alt-src-1';
  static const String _altLayer1 = 'route-alt-layer-1';

  MapboxMap? _mapboxMap;
  MapboxRoute? _currentRoute;
  bool _isInitialized = false;

  // Performance optimization
  int? _lastStepIndex;
  String? _lastRouteHash;
  geo.Position? _lastUpdatePosition;
  DateTime? _lastUpdateTime;

  // Arrow visualization settings. Two images per Mapbox convention: a filled
  // white triangle for the arrowhead, and a slightly larger dark-blue triangle
  // sitting beneath it for the outline (casing).
  static const String _arrowHeadImageId = 'mapbox-navigation-arrow-head';
  static const String _arrowHeadCasingImageId =
      'mapbox-navigation-arrow-head-casing';
  // Mapbox reference colours (RouteLayerConstants.kt).
  static const int _maneuverArrowColor = 0xFFFFFFFF;
  static const int _maneuverArrowCasingColor = 0xFF054AAD;
  // Show arrow only from this zoom up; matches Android's ARROW_HIDDEN_ZOOM_LEVEL=14.
  // In debug builds we drop the gate to zoom 5 so the arrow is visible at
  // route-overview zoom too — makes it easy to eyeball on a stationary
  // simulator without having to fake GPS motion. Native behaviour returns in
  // release builds.
  static final double _maneuverArrowMinZoom = kDebugMode ? 5.0 : 14.0;
  // Half-length of the shaft in meters (30m before + 30m after the maneuver).
  static const double _shaftHalfLengthMeters = 30.0;

  /// Route visualization constants
  static const int routeDefaultColor = 0xFF2196F3;
  static const int routeTraveledColor = 0xFFB0BEC5; // Grey for traveled route
  static const double routeOpacity = 0.95;
  static const double routeTraveledOpacity = 0.6;
  static const int routeUpdateIntervalMs = 100;

  // Traffic colors
  static const int trafficSevereColor = 0xFFDC143C;
  static const int trafficHeavyColor = 0xFFFF6347;
  static const int trafficModerateColor = 0xFFFFD700;
  static const int trafficLightColor = 0xFF32CD32;

  /// Initialize the service with a Mapbox map. Re-runnable after a style
  /// reload — layers/sources are recreated and the geometry hash is
  /// invalidated so the next drawRoute re-uploads.
  Future<void> initialize(MapboxMap mapboxMap) async {
    print('🔧 Initializing RouteVisualizationService');
    _mapboxMap = mapboxMap;
    _isInitialized = true;
    _lastRouteHash = null;

    try {
      await _setupRouteLayers();
      await _setupArrowLayers();
      await _setupLaneGuidanceLayers();
      print('✅ RouteVisualizationService initialized successfully');
    } catch (e) {
      print('❌ RouteVisualizationService initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Mapbox may replace the active style (config updates, lifecycle), which
  /// drops runtime-added sources. Re-apply route/arrow/lane layers if needed.
  Future<void> _ensureRouteStyleReady() async {
    if (_mapboxMap == null) return;
    try {
      final exists = await _mapboxMap!.style.styleSourceExists(_routeSourceId);
      if (exists) return;
      print(
        '⚠️ route-source missing from style; re-applying layers (style reload)',
      );
      await _setupRouteLayers();
      await _setupArrowLayers();
      await _setupLaneGuidanceLayers();
    } catch (e) {
      print('❌ Failed to restore route layers after style change: $e');
      rethrow;
    }
  }

  /// Draw route with progress tracking
  Future<void> drawRoute(
    MapboxRoute route, {
    int? currentStepIndex,
    geo.Position? currentPosition,
    List<MapboxRoute>? alternativeRoutes,
  }) async {
    print('🚀 RouteVisualizationService.drawRoute called');
    print('   - isInitialized: $_isInitialized');
    print('   - mapboxMap is null: ${_mapboxMap == null}');
    print('   - currentStepIndex: $currentStepIndex');
    print('   - currentPosition: ${currentPosition != null}');

    if (!_isInitialized || _mapboxMap == null) {
      print('❌ RouteVisualizationService not initialized or map is null');
      return;
    }

    try {
      await _ensureRouteStyleReady();
      final routeHash = _generateRouteHash(route);
      final bool isNewRoute = _lastRouteHash != routeHash;
      print('   - isNewRoute: $isNewRoute');

      _currentRoute = route;
      _lastRouteHash = routeHash;

      // Geometry is uploaded ONCE per route; per-tick progress is a
      // line-trim-offset property write, never a source re-upload.
      if (isNewRoute) {
        _precomputeCumulativeDistances(route);
        _lastTrimFraction = 0;
        await _showFullRoute(route);
        await _setTrimOffset(0);
      }

      if (currentStepIndex != null && currentPosition != null) {
        await _updateRouteSplit(
            route, currentStepIndex, 0, currentPosition); // leg 0 when from drawRoute
      }

      // Grey alternative routes (preview only — not while stepping through navigation)
      if (currentStepIndex == null &&
          alternativeRoutes != null &&
          alternativeRoutes.isNotEmpty) {
        await setAlternativeRoutes(alternativeRoutes);
      } else if (currentStepIndex == null) {
        await clearAlternativeRoutes();
      }

      // Draw lane guidance on the map at the upcoming intersection (native-style)
      if (currentStepIndex != null) {
        await _drawLaneGuidanceOnMap(
            route, currentStepIndex, 0); // leg 0 when from drawRoute
      } else {
        await _clearLaneGuidanceOnMap();
      }

      // Populate the maneuver arrow immediately so it's visible before the
      // first GPS position update — otherwise a stationary tester (or the
      // simulator with no location) never sees an arrow.
      await _updateManeuverArrow(route, currentStepIndex ?? 0, 0);

      print('✅ Route drawing completed successfully');
    } catch (e) {
      print('❌ Failed to draw route: $e');
      throw Exception('Failed to draw route: $e');
    }
  }

  /// Update route progress during navigation
  Future<void> updateRouteProgress(MapboxRoute route, int currentStepIndex,
      {int currentLegIndex = 0,
      geo.Position? currentPosition,
      bool forceUpdate = false}) async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      await _ensureRouteStyleReady();
      if (!forceUpdate &&
          !_shouldUpdateRoute(currentStepIndex, currentPosition)) {
        await _drawLaneGuidanceOnMap(route, currentStepIndex, currentLegIndex);
        await _updateManeuverArrow(route, currentStepIndex, currentLegIndex);
        return;
      }

      await _updateRouteSplit(
          route, currentStepIndex, currentLegIndex, currentPosition);
      await _drawLaneGuidanceOnMap(route, currentStepIndex, currentLegIndex);
      await _updateManeuverArrow(route, currentStepIndex, currentLegIndex);
    } catch (e) {
      throw Exception('Failed to update route progress: $e');
    }
  }

  /// Show the full route without progress
  Future<void> _showFullRoute(MapboxRoute route) async {
    try {
      final fullRouteGeoJson = _createRouteGeoJson(route);
      print(
          '📍 Creating route with ${route.geometry.coordinates.length} coordinates');

      // Update main route source with full route
      await _mapboxMap!.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        jsonEncode(fullRouteGeoJson),
      );
      print('✅ Route data updated successfully');
    } catch (e) {
      print('❌ Failed to show full route: $e');
      throw e;
    }
  }

  // Cumulative meters from route start to each coordinate index, computed
  // once per route in [drawRoute]. Enables O(window) fraction-traveled math.
  List<double>? _cumulativeMeters;
  int _lastTrimSegmentIndex = 0;

  void _precomputeCumulativeDistances(MapboxRoute route) {
    final coords = route.geometry.coordinates;
    final cumul = List<double>.filled(coords.length, 0);
    for (var i = 1; i < coords.length; i++) {
      cumul[i] = cumul[i - 1] +
          _calculateDistance(
              coords[i - 1][1], coords[i - 1][0], coords[i][1], coords[i][0]);
    }
    _cumulativeMeters = cumul;
    _lastTrimSegmentIndex = 0;
  }

  /// Native vanishing-route-line: write a single `line-trim-offset` scalar on
  /// the main + casing layers. The trimmed (traveled) part of the line simply
  /// isn't rendered — no GeoJSON re-upload, no filters, GPU-side.
  ///
  /// Guards mirror the SDK (MapboxRouteLineApi.kt:615-659 /
  /// VanishingRouteLine.kt:83): skip when the puck is >10 m off the line, and
  /// never move the trim backwards.
  double _lastTrimFraction = 0;

  Future<void> _updateRouteSplit(
    MapboxRoute route,
    int currentStepIndex,
    int currentLegIndex,
    geo.Position? currentPosition,
  ) async {
    if (currentPosition == null) return;

    try {
      final coordinates = route.geometry.coordinates;
      if (coordinates.length < 2 ||
          _cumulativeMeters == null ||
          _cumulativeMeters!.length != coordinates.length) {
        return;
      }
      final total = _cumulativeMeters!.last;
      if (total <= 0) return;

      // Project the puck onto the line, scanning a window around the last
      // known segment (the SDK slices the previous 10 points + upcoming).
      final windowStart = math.max(0, _lastTrimSegmentIndex - 10);
      final windowEnd =
          math.min(coordinates.length - 2, _lastTrimSegmentIndex + 40);

      int closestSegmentIndex = _lastTrimSegmentIndex;
      double minDistance = double.infinity;
      List<double> projectedPoint = coordinates[windowStart];

      for (int i = windowStart; i <= windowEnd; i++) {
        final proj = _projectPointOnSegment(
          [currentPosition.longitude, currentPosition.latitude],
          coordinates[i],
          coordinates[i + 1],
        );
        final dist = _calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          proj[1],
          proj[0],
        );
        if (dist < minDistance) {
          minDistance = dist;
          closestSegmentIndex = i;
          projectedPoint = proj;
        }
      }

      // Off the line — don't advance the trim (native 10 m guard).
      if (minDistance > 10.0) return;

      final distanceTraveled = _cumulativeMeters![closestSegmentIndex] +
          _calculateDistance(
            coordinates[closestSegmentIndex][1],
            coordinates[closestSegmentIndex][0],
            projectedPoint[1],
            projectedPoint[0],
          );
      var fraction = (distanceTraveled / total).clamp(0.0, 1.0);

      // Monotonic: the traveled line never un-eats itself.
      if (fraction < _lastTrimFraction) return;

      _lastTrimSegmentIndex = closestSegmentIndex;
      _lastTrimFraction = fraction;

      await _setTrimOffset(fraction);

      _lastStepIndex = currentStepIndex;
      _lastUpdatePosition = currentPosition;
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      print('❌ Failed to update route trim: $e');
    }
  }

  Future<void> _setTrimOffset(double fraction) async {
    final value = [0.0, fraction];
    for (final layerId in [_routeLayerId, _routeBorderLayerId]) {
      await _mapboxMap!.style.setStyleLayerProperty(
        layerId,
        'line-trim-offset',
        value,
      );
    }
  }

  /// Project point p onto segment v-w
  List<double> _projectPointOnSegment(
      List<double> p, List<double> v, List<double> w) {
    final l2 = _distSq(v, w);
    if (l2 == 0) return v;

    final t =
        ((p[0] - v[0]) * (w[0] - v[0]) + (p[1] - v[1]) * (w[1] - v[1])) / l2;

    if (t < 0) return v;
    if (t > 1) return w;

    return [
      v[0] + t * (w[0] - v[0]),
      v[1] + t * (w[1] - v[1]),
    ];
  }

  double _distSq(List<double> v, List<double> w) {
    return math.pow(v[0] - w[0], 2) + math.pow(v[1] - w[1], 2).toDouble();
  }

  /// Create GeoJSON for full route
  Map<String, dynamic> _createRouteGeoJson(MapboxRoute route) {
    final coordinates = route.geometry.coordinates;

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates,
          },
          'properties': {
            'route_id': route.hashCode.toString(),
            'is_traveled': false,
            'is_remaining': true,
          },
        }
      ],
    };
  }

  /// Determine if route update is needed
  bool _shouldUpdateRoute(
      int? currentStepIndex, geo.Position? currentPosition) {
    if (_lastStepIndex == null || currentStepIndex != _lastStepIndex) {
      return true;
    }

    final now = DateTime.now();
    if (_lastUpdateTime != null) {
      final timeDiff = now.difference(_lastUpdateTime!).inMilliseconds;
      if (timeDiff < routeUpdateIntervalMs) {
        return false;
      }
    }

    if (currentPosition != null && _lastUpdatePosition != null) {
      final distance = _calculateDistance(
        _lastUpdatePosition!.latitude,
        _lastUpdatePosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );

      if (distance > 1.0) {
        return true;
      }
    }

    return false;
  }

  /// Calculate distance between two points
  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    return geo.Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  Future<void> clearAlternativeRoutes() async {
    if (_mapboxMap == null) return;
    try {
      for (final entry in [
        (_altLayer0, _altSource0),
        (_altLayer1, _altSource1),
      ]) {
        if (await _mapboxMap!.style.styleLayerExists(entry.$1)) {
          await _mapboxMap!.style.removeStyleLayer(entry.$1);
        }
        if (await _mapboxMap!.style.styleSourceExists(entry.$2)) {
          await _mapboxMap!.style.removeStyleSource(entry.$2);
        }
      }
    } catch (e) {
      print('⚠️ clearAlternativeRoutes: $e');
    }
  }

  /// Up to two non-selected routes as muted lines below the primary route.
  Future<void> setAlternativeRoutes(List<MapboxRoute> routes) async {
    if (!_isInitialized || _mapboxMap == null) return;
    await clearAlternativeRoutes();
    final take = routes.take(2).toList();
    for (var i = 0; i < take.length; i++) {
      final sid = i == 0 ? _altSource0 : _altSource1;
      final lid = i == 0 ? _altLayer0 : _altLayer1;
      try {
        final geoJson = _createRouteGeoJson(take[i]);
        await _mapboxMap!.style.addSource(
          GeoJsonSource(id: sid, data: jsonEncode(geoJson)),
        );
        await _mapboxMap!.style.addLayer(
          LineLayer(
            id: lid,
            sourceId: sid,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
            lineColor: 0xFF78909C,
            lineWidth: 5,
            lineOpacity: 0.8,
          ),
        );
        await _mapboxMap!.style.moveStyleLayer(
          lid,
          LayerPosition(below: _routeBorderLayerId),
        );
      } catch (e) {
        print('⚠️ setAlternativeRoutes[$i]: $e');
      }
    }
  }

  /// Clear route from map
  Future<void> clearRoute() async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      await clearAlternativeRoutes();
      // Check if source exists before trying to clear it
      final sourceExists =
          await _mapboxMap!.style.styleSourceExists(_routeSourceId);

      if (!sourceExists) {
        print('⚠️ Route source does not exist, skipping clear');
        _currentRoute = null;
        return;
      }

      final emptyGeoJson = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      await _mapboxMap!.style
          .setStyleSourceProperty(_routeSourceId, 'data', jsonEncode(emptyGeoJson));
      await _setTrimOffset(0);
      _lastTrimFraction = 0;
      _lastTrimSegmentIndex = 0;
      // The source is now empty — invalidate the hash so the next drawRoute
      // re-uploads geometry even for the "same" route. Without this, a
      // clear-then-redraw of an unchanged route skips the upload and the
      // line disappears until the geometry happens to change.
      _lastRouteHash = null;
      await _clearLaneGuidanceOnMap();
      await _clearManeuverArrow();

      _currentRoute = null;
      print('✅ Route cleared successfully');
    } catch (e) {
      print('⚠️ Failed to clear route (non-critical): $e');
      // Don't throw - clearing a non-existent route is not a critical error
      _currentRoute = null;
    }
  }

  /// Setup route layers on the map
  Future<void> _setupRouteLayers() async {
    if (_mapboxMap == null) return;

    try {
      final emptyGeoJson = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      // Remove existing layers and source if they exist
      await _removeExistingRouteLayers();

      // Single source, uploaded ONCE per route. lineMetrics is required for
      // line-trim-offset (the native vanishing-route-line mechanism) — the
      // traveled portion is trimmed away GPU-side with a single scalar
      // property write per tick instead of re-uploading split GeoJSON.
      await _mapboxMap!.style.addSource(
        GeoJsonSource(
          id: _routeSourceId,
          data: jsonEncode(emptyGeoJson),
          lineMetrics: true,
        ),
      );
      print('✅ Added route source: $_routeSourceId');

      // 1. Casing (border) — native color #2F7AC6 and casing width curve
      // (RouteLineScaleExpressions.kt: 10→7, 14→10.5, 16.5→15.5, 19→24, 22→29).
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeBorderLayerId,
          sourceId: _routeSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            10.0, 7.0,
            14.0, 10.5,
            16.5, 15.5,
            19.0, 24.0,
            22.0, 29.0,
          ],
          lineColor: 0xFF2F7AC6, // native route casing
          lineOpacity: 1.0,
          lineEmissiveStrength: 1.0,
        ),
      );
      print('✅ Added route border layer: $_routeBorderLayerId');

      // 2. Main route — native color #56A8FB and main width curve
      // (RouteLineScaleExpressions.kt: 4→3, 10→4, 13→6, 16→10, 19→14, 22→18).
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            4.0, 3.0,
            10.0, 4.0,
            13.0, 6.0,
            16.0, 10.0,
            19.0, 14.0,
            22.0, 18.0,
          ],
          lineColor: 0xFF56A8FB, // native main route blue
          lineOpacity: 1.0,
          lineEmissiveStrength: 1.0,
        ),
      );
      print('✅ Added route main layer: $_routeLayerId');

      await _ensureLocationPuckOnTop();
      print('✅ Route layers setup completed successfully');
    } catch (e) {
      print('❌ Failed to setup route layers: $e');
      throw Exception('Failed to setup route layers: $e');
    }
  }

  /// Remove existing route layers to avoid conflicts
  Future<void> _removeExistingRouteLayers() async {
    if (_mapboxMap == null) return;

    try {
      // Check and remove layers if they exist
      if (await _mapboxMap!.style.styleLayerExists(_routeLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_routeLayerId);
        print('🧹 Removed existing route layer: $_routeLayerId');
      }

      if (await _mapboxMap!.style.styleLayerExists(_traveledRouteLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_traveledRouteLayerId);
        print(
            '🧹 Removed existing traveled route layer: $_traveledRouteLayerId');
      }

      if (await _mapboxMap!.style.styleLayerExists(_routeBorderLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_routeBorderLayerId);
        print('🧹 Removed existing border layer: $_routeBorderLayerId');
      }

      // Check and remove source if it exists
      if (await _mapboxMap!.style.styleSourceExists(_routeSourceId)) {
        await _mapboxMap!.style.removeStyleSource(_routeSourceId);
        print('🧹 Removed existing route source: $_routeSourceId');
      }
    } catch (e) {
      print('⚠️ Error removing existing route layers: $e');
      // Continue anyway - this is not critical
    }
  }

  /// Ensure location puck stays on top
  Future<void> _ensureLocationPuckOnTop() async {
    // Removed: This logic conflicts with the custom navigation puck layer ordering.
    // Layer ordering is now handled explicitly in MapControllerMixin.
  }

  /// Update route styling based on traffic
  /// Generate route hash for change detection
  String _generateRouteHash(MapboxRoute route) {
    final buffer = StringBuffer();
    buffer.write('${route.distance}_${route.duration}');

    if (route.geometry.coordinates.isNotEmpty) {
      final coordsToHash = [
        ...route.geometry.coordinates.take(3),
        ...route.geometry.coordinates
            .skip(math.max(0, route.geometry.coordinates.length - 3)),
      ];

      for (final coord in coordsToHash) {
        if (coord.length >= 2) {
          buffer.write(
              '_${coord[1].toStringAsFixed(6)}_${coord[0].toStringAsFixed(6)}');
        }
      }
    }

    return buffer.toString().hashCode.toString();
  }

  /// Setup arrow layers on the map
  Future<void> _setupArrowLayers() async {
    if (_mapboxMap == null) return;

    try {
      // Load the two triangle images (white head + dark blue casing).
      await _createManeuverArrowImages();

      // Remove any legacy layer/source from earlier attempts at this feature.
      for (final id in [
        _arrowLayerId,
        _arrowShaftLayerId,
        _arrowShaftCasingLayerId,
        _arrowHeadLayerId,
        _arrowHeadCasingLayerId,
      ]) {
        if (await _mapboxMap!.style.styleLayerExists(id)) {
          await _mapboxMap!.style.removeStyleLayer(id);
        }
      }
      for (final id in [
        _arrowSourceId,
        _arrowShaftSourceId,
        _arrowHeadSourceId,
      ]) {
        if (await _mapboxMap!.style.styleSourceExists(id)) {
          await _mapboxMap!.style.removeStyleSource(id);
        }
      }

      // Two empty sources up-front; populated per maneuver by
      // [_updateManeuverArrow] on each route-progress update.
      final emptyGeoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      });
      await _mapboxMap!.style
          .addSource(GeoJsonSource(id: _arrowShaftSourceId, data: emptyGeoJson));
      await _mapboxMap!.style
          .addSource(GeoJsonSource(id: _arrowHeadSourceId, data: emptyGeoJson));

      // Order (bottom → top): shaft casing → shaft → head casing → head.
      // Mirrors RouteArrowUtils.kt's stacking so the light shape always sits
      // on top of its darker outline.

      // Widths follow the SAME exponential curve as the route line
      // (RouteLineUtils setup), scaled so the fill sits ~65% of the route
      // width and the casing peeks out ~90%. This keeps the blue road
      // visible on both sides of the arrow, which is the visual convention
      // native Mapbox and Google Maps use — the arrow reads as a HIGHLIGHT
      // over the road, not a replacement for it.

      // 1. Shaft casing (dark blue outline underneath the white fill).
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _arrowShaftCasingLayerId,
          sourceId: _arrowShaftSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineColor: _maneuverArrowCasingColor,
          minZoom: _maneuverArrowMinZoom,
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            10.0, 2.7, // route 3.0 × 0.9
            13.0, 5.4,
            16.0, 8.1,
            19.0, 12.6,
            22.0, 17.1,
          ],
        ),
      );

      // 2. Shaft fill (white line on top of the casing).
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _arrowShaftLayerId,
          sourceId: _arrowShaftSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineColor: _maneuverArrowColor,
          minZoom: _maneuverArrowMinZoom,
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            10.0, 2.0, // route 3.0 × 0.65
            13.0, 3.9,
            16.0, 5.9,
            19.0, 9.1,
            22.0, 12.4,
          ],
        ),
      );

      // 3. Arrowhead casing (larger dark blue triangle). No iconOffset —
      // the head's anchor point IS the shaft tip (see _updateManeuverArrow,
      // which computes the head position as the last shaft coord, not the
      // maneuver point). Centering the icon there lets the triangle overlap
      // the shaft's end for a seamless join.
      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: _arrowHeadCasingLayerId,
          sourceId: _arrowHeadSourceId,
          iconImage: _arrowHeadCasingImageId,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconRotationAlignment: IconRotationAlignment.MAP,
          iconPitchAlignment: IconPitchAlignment.MAP,
          minZoom: _maneuverArrowMinZoom,
          iconRotateExpression: ['get', 'bearing'],
          // Casing must render LARGER than the fill so the dark-blue outline
          // peeks out around the white triangle (native uses a bigger casing
          // drawable; our two images are identical, so the size ratio does it).
          iconSizeExpression: [
            'interpolate',
            ['linear'],
            ['zoom'],
            10.0, 0.19,
            22.0, 0.72,
          ],
        ),
      );

      // 4. Arrowhead fill (smaller white triangle on top of the casing).
      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: _arrowHeadLayerId,
          sourceId: _arrowHeadSourceId,
          iconImage: _arrowHeadImageId,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconRotationAlignment: IconRotationAlignment.MAP,
          iconPitchAlignment: IconPitchAlignment.MAP,
          minZoom: _maneuverArrowMinZoom,
          iconRotateExpression: ['get', 'bearing'],
          iconSizeExpression: [
            'interpolate',
            ['linear'],
            ['zoom'],
            10.0, 0.16,
            22.0, 0.62,
          ],
        ),
      );

      // Move all four to the top of the style so they render above the route
      // line but below the user puck (which is added after these).
      for (final id in [
        _arrowShaftCasingLayerId,
        _arrowShaftLayerId,
        _arrowHeadCasingLayerId,
        _arrowHeadLayerId,
      ]) {
        try {
          await _mapboxMap!.style.moveStyleLayer(id, null);
        } catch (_) {
          // Ignore ordering failures — a broken order still renders.
        }
      }

      print('✅ Maneuver arrow layers setup');
    } catch (e) {
      print('❌ Failed to setup maneuver arrow layers: $e');
    }
  }

  /// Rebuild the shaft (LineString) and head (Point + bearing) for the *next*
  /// maneuver. Skipped on the final "arrive" step and when indices are out of
  /// range. Called from [updateRouteProgress] on every position tick and once
  /// from [drawRoute] so the arrow is populated before the first GPS fix.
  Future<void> _updateManeuverArrow(
    MapboxRoute route,
    int currentStepIndex,
    int currentLegIndex,
  ) async {
    if (_mapboxMap == null) return;
    try {
      if (route.legs.isEmpty ||
          currentLegIndex < 0 ||
          currentLegIndex >= route.legs.length) {
        print('⚠️ Maneuver arrow: invalid leg index $currentLegIndex');
        await _clearManeuverArrow();
        return;
      }
      final leg = route.legs[currentLegIndex];
      final steps = leg.steps;
      if (steps.isEmpty ||
          currentStepIndex < 0 ||
          currentStepIndex >= steps.length - 1) {
        // No upcoming maneuver (either invalid or on the arrival step).
        print(
            '⚠️ Maneuver arrow: no upcoming maneuver (stepIndex=$currentStepIndex, steps=${steps.length})');
        await _clearManeuverArrow();
        return;
      }
      final currentStep = steps[currentStepIndex];
      final nextStep = steps[currentStepIndex + 1];
      if (nextStep.maneuver.location.length < 2) {
        print('⚠️ Maneuver arrow: next step has no location');
        await _clearManeuverArrow();
        return;
      }

      // Shaft = last ~30m of the current step + first ~30m of the next step.
      // Matches Android's obtainArrowPointsFrom (TurfMisc.lineSliceAlong)
      // and iOS's polylineAroundManeuver — the canonical native Mapbox nav
      // rendering. Note: `_sliceLineFromStart/End` interpolate along the
      // final segment for an exact 30m cut, so the shaft is precisely 60m
      // even when the step's raw geometry only has 2-3 vertices.
      final before = _sliceLineFromEnd(
        currentStep.geometry.coordinates,
        _shaftHalfLengthMeters,
      );
      final after = _sliceLineFromStart(
        nextStep.geometry.coordinates,
        _shaftHalfLengthMeters,
      );
      final shaftCoords = <List<double>>[
        ...before,
        // Drop `after`'s leading coord if it duplicates `before`'s trailing
        // coord (they should — both are the maneuver point).
        ...(after.isNotEmpty &&
                before.isNotEmpty &&
                after.first[0] == before.last[0] &&
                after.first[1] == before.last[1]
            ? after.skip(1)
            : after),
      ];
      // Need at least 2 points to draw a LineString.
      if (shaftCoords.length < 2) {
        await _clearManeuverArrow();
        return;
      }

      // Arrowhead bearing: direction of travel at the tip, taken from the
      // last two shaft points. This orients the triangle to point along the
      // turn direction.
      final b = shaftCoords[shaftCoords.length - 2];
      final t = shaftCoords[shaftCoords.length - 1];
      final bearingDeg = _bearingBetween(b[1], b[0], t[1], t[0]);

      final shaftFeature = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': shaftCoords,
            },
            'properties': <String, dynamic>{},
          },
        ],
      };
      // Anchor the head at the shaft's tip (i.e. slightly past the maneuver
      // into the outgoing road), not at the raw maneuver point. Matches
      // ManeuverArrowMapFeatures.swift which uses `shaftStrokeCoordinates.last`.
      final headLng = t[0];
      final headLat = t[1];
      final headFeature = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [headLng, headLat],
            },
            'properties': {'bearing': bearingDeg},
          },
        ],
      };

      await _mapboxMap!.style.setStyleSourceProperty(
          _arrowShaftSourceId, 'data', jsonEncode(shaftFeature));
      await _mapboxMap!.style.setStyleSourceProperty(
          _arrowHeadSourceId, 'data', jsonEncode(headFeature));

      // Length assertion — if the slicer is broken we'll see this way over
      // the requested 60m (30 before + 30 after).
      double actualLenM = 0;
      for (int i = 0; i < shaftCoords.length - 1; i++) {
        actualLenM += _calculateDistance(
          shaftCoords[i][1],
          shaftCoords[i][0],
          shaftCoords[i + 1][1],
          shaftCoords[i + 1][0],
        );
      }
      final beforeLenM = _pathLengthMeters(before);
      final afterLenM = _pathLengthMeters(after);
      print(
          '➡️  Maneuver arrow: shaft=${actualLenM.toStringAsFixed(1)}m (before=${beforeLenM.toStringAsFixed(1)}m + after=${afterLenM.toStringAsFixed(1)}m), pts=${shaftCoords.length}, bearing=${bearingDeg.toStringAsFixed(0)}° | currentStep pts=${currentStep.geometry.coordinates.length} dist=${currentStep.distance.toStringAsFixed(0)}m, nextStep pts=${nextStep.geometry.coordinates.length} dist=${nextStep.distance.toStringAsFixed(0)}m');
    } catch (e) {
      print('⚠️ Failed to update maneuver arrow: $e');
    }
  }

  Future<void> _clearManeuverArrow() async {
    if (_mapboxMap == null) return;
    final empty = jsonEncode({
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[],
    });
    try {
      if (await _mapboxMap!.style.styleSourceExists(_arrowShaftSourceId)) {
        await _mapboxMap!.style
            .setStyleSourceProperty(_arrowShaftSourceId, 'data', empty);
      }
      if (await _mapboxMap!.style.styleSourceExists(_arrowHeadSourceId)) {
        await _mapboxMap!.style
            .setStyleSourceProperty(_arrowHeadSourceId, 'data', empty);
      }
    } catch (_) {
      // Non-critical.
    }
  }

  /// Return the last [meters] of a polyline, walking backwards from the end.
  /// Result is ordered start→end (i.e. it terminates at the polyline's last
  /// coordinate). Interpolates along the final segment for an exact length
  /// when the tail is longer than [meters].
  List<List<double>> _sliceLineFromEnd(
      List<List<double>> coords, double meters) {
    if (coords.length < 2 || meters <= 0) return const <List<double>>[];
    final reversed = coords.reversed.toList();
    final slice = _sliceLineFromStart(reversed, meters);
    return slice.reversed.toList();
  }

  /// Return the first [meters] of a polyline. Interpolates along the last
  /// segment when the head is longer than [meters].
  List<List<double>> _sliceLineFromStart(
      List<List<double>> coords, double meters) {
    if (coords.length < 2 || meters <= 0) return const <List<double>>[];
    final out = <List<double>>[coords.first];
    double accumulated = 0;
    for (int i = 0; i < coords.length - 1; i++) {
      final a = coords[i];
      final b = coords[i + 1];
      final segLen = _calculateDistance(a[1], a[0], b[1], b[0]);
      if (accumulated + segLen >= meters) {
        // Interpolate the exact endpoint on this segment.
        final remaining = meters - accumulated;
        final t = segLen == 0 ? 0.0 : (remaining / segLen);
        out.add([
          a[0] + (b[0] - a[0]) * t,
          a[1] + (b[1] - a[1]) * t,
        ]);
        return out;
      }
      out.add(b);
      accumulated += segLen;
    }
    return out;
  }

  /// Total length in meters of a polyline (coords in [lng, lat] order).
  double _pathLengthMeters(List<List<double>> coords) {
    if (coords.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < coords.length - 1; i++) {
      total += _calculateDistance(
        coords[i][1],
        coords[i][0],
        coords[i + 1][1],
        coords[i + 1][0],
      );
    }
    return total;
  }

  /// Initial bearing from (lat1,lon1) to (lat2,lon2), degrees clockwise from
  /// north, normalised to [0, 360). Same formula the puck bearing code uses.
  double _bearingBetween(
      double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
    final deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }

  /// Register the two triangle images used by the maneuver arrow: a filled
  /// white triangle (head) and a slightly larger dark-blue triangle (casing).
  /// Path spec matches mapbox_ic_arrow_head.xml so the shape is visually
  /// identical to Android's native maneuver arrow.
  Future<void> _createManeuverArrowImages() async {
    if (_mapboxMap == null) return;
    try {
      await _addTriangleImage(
        id: _arrowHeadImageId,
        color: const ui.Color(_maneuverArrowColor),
      );
      await _addTriangleImage(
        id: _arrowHeadCasingImageId,
        color: const ui.Color(_maneuverArrowCasingColor),
      );
      print('✅ Loaded maneuver arrow images');
    } catch (e) {
      print('❌ Failed to load maneuver arrow images: $e');
    }
  }

  /// Rasterise Mapbox's rounded-corner triangle at 96px and register with the
  /// style. The path is straight from mapbox_ic_arrow_head.xml (36×36
  /// viewport) scaled up; the base sits at the bottom and the tip points up,
  /// so an `icon-rotate` of 0° means "aligned with the line direction" when
  /// iconRotationAlignment=map.
  Future<void> _addTriangleImage({
    required String id,
    required ui.Color color,
  }) async {
    const double vbSize = 36.0;
    const int pxSize = 96;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final scale = pxSize / vbSize;
    canvas.scale(scale);

    final path = ui.Path()
      // M3.06,32.176
      ..moveTo(3.06, 32.176)
      // C1.398,32.177 0.358,30.374 1.192,28.94
      ..cubicTo(1.398, 32.177, 0.358, 30.374, 1.192, 28.94)
      // L16.156,3.017
      ..lineTo(16.156, 3.017)
      // C16.988,1.573 19.066,1.572 19.895,3.015
      ..cubicTo(16.988, 1.573, 19.066, 1.572, 19.895, 3.015)
      // L34.859,28.933
      ..lineTo(34.859, 28.933)
      // C35.688,30.376 34.65,32.171 32.988,32.171
      ..cubicTo(35.688, 30.376, 34.65, 32.171, 32.988, 32.171)
      // C23.012,32.176 13.036,32.169 3.06,32.176
      ..cubicTo(23.012, 32.176, 13.036, 32.169, 3.06, 32.176)
      ..close();

    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);

    final image = await recorder.endRecording().toImage(pxSize, pxSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    await _mapboxMap!.style.addStyleImage(
      id,
      2.0, // pixel ratio
      MbxImage(width: pxSize, height: pxSize, data: byteData.buffer.asUint8List()),
      false,
      [],
      [],
      null,
    );
  }

  /// Load lane guidance SVG images
  Future<void> _loadLaneImages() async {
    if (_mapboxMap == null) return;

    final laneIcons = {
      'lane_straight': 'assets/icons/lane_straight.svg',
      'lane_left': 'assets/icons/lane_left.svg',
      'lane_right': 'assets/icons/lane_right.svg',
      'lane_straight_left': 'assets/icons/lane_straight_left.svg',
      'lane_straight_right': 'assets/icons/lane_straight_right.svg',
    };

    for (final entry in laneIcons.entries) {
      try {
        final String svgString = await rootBundle.loadString(entry.value);

        // Use flutter_svg to compile the SVG (no PathOps required on-device),
        // then render it into a fixed-size PNG for Mapbox style images.
        final fsvg.PictureInfo pictureInfo = await fsvg.vg.loadPicture(
          fsvg.SvgStringLoader(svgString),
          null,
        );

        const double targetSize = 48.0; // Consistent size
        final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
        final ui.Canvas canvas = ui.Canvas(pictureRecorder);
        final double scale = targetSize / pictureInfo.size.width;
        canvas.scale(scale);
        canvas.drawPicture(pictureInfo.picture);

        final ui.Image image = await pictureRecorder
            .endRecording()
            .toImage(targetSize.toInt(), targetSize.toInt());
        pictureInfo.picture.dispose();
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final Uint8List list = byteData.buffer.asUint8List();
          await _mapboxMap!.style.addStyleImage(
              entry.key,
              2.0, // Scale
              MbxImage(
                  width: targetSize.toInt(),
                  height: targetSize.toInt(),
                  data: list),
              false,
              [],
              [],
              null);
        }
      } catch (e) {
        print('⚠️ Failed to load lane icon ${entry.key}: $e');
      }
    }
    print('✅ Loaded lane guidance icons');
  }

  /// Setup lane guidance layers
  Future<void> _setupLaneGuidanceLayers() async {
    if (_mapboxMap == null) return;

    try {
      await _loadLaneImages();

      final emptyGeoJson = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      if (await _mapboxMap!.style.styleLayerExists(_laneGuidanceLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_laneGuidanceLayerId);
      }
      if (await _mapboxMap!.style.styleSourceExists(_laneGuidanceSourceId)) {
        await _mapboxMap!.style.removeStyleSource(_laneGuidanceSourceId);
      }

      await _mapboxMap!.style.addSource(
        GeoJsonSource(
            id: _laneGuidanceSourceId, data: jsonEncode(emptyGeoJson)),
      );

      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: _laneGuidanceLayerId,
          sourceId: _laneGuidanceSourceId,
          iconSize: 1.0, // Larger size for maneuvers
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconOpacity: 1.0,
          iconAnchor: IconAnchor.CENTER,
          iconRotationAlignment:
              IconRotationAlignment.MAP, // Align with map/road
        ),
      );

      // Data-driven icon from feature property "icon" (required for per-lane images)
      await _mapboxMap!.style.setStyleLayerProperty(
        _laneGuidanceLayerId,
        'icon-image',
        jsonEncode(["get", "icon"]),
      );
      // Set data-driven rotation
      await _mapboxMap!.style.setStyleLayerProperty(
        _laneGuidanceLayerId,
        'icon-rotate',
        jsonEncode(["get", "rotation"]),
      );

      print('✅ Lane guidance layers setup');
    } catch (e) {
      print('❌ Failed to setup lane guidance layers: $e');
    }
  }

  /// Map lane indications to style image id (must match _loadLaneImages keys).
  /// Handles Mapbox values: left, slight_left, sharp_left, straight, right, etc.
  static String _laneIconFromIndications(List<String> indications) {
    final lower = indications.map((e) => e.toLowerCase()).toList();
    final hasStraight = lower.any((e) => e == 'straight');
    final hasLeft = lower.any((e) => e.contains('left'));
    final hasRight = lower.any((e) => e.contains('right'));
    if (hasStraight && hasLeft) return 'lane_straight_left';
    if (hasStraight && hasRight) return 'lane_straight_right';
    if (hasLeft) return 'lane_left';
    if (hasRight) return 'lane_right';
    return 'lane_straight';
  }

  /// Draw lane guidance symbols on the map at the upcoming intersection (native iOS/Android style).
  Future<void> _drawLaneGuidanceOnMap(
      MapboxRoute route, int currentStepIndex, int currentLegIndex) async {
    if (_mapboxMap == null || route.legs.isEmpty) return;
    if (currentLegIndex >= route.legs.length) return;
    final leg = route.legs[currentLegIndex];
    if (currentStepIndex >= leg.steps.length) {
      await _clearLaneGuidanceOnMap();
      return;
    }
    final step = leg.steps[currentStepIndex];
    final withLanes = step.intersections
        .where((i) => i.lanes.isNotEmpty)
        .toList();
    if (withLanes.isEmpty) {
      debugPrint(
          'Lane guidance: no lane data for step $currentStepIndex (API may not return lanes for this intersection).');
      await _clearLaneGuidanceOnMap();
      return;
    }
    final intersection = withLanes.last;
    if (intersection.location.length < 2) {
      await _clearLaneGuidanceOnMap();
      return;
    }
    final lon = intersection.location[0].toDouble();
    final lat = intersection.location[1].toDouble();
    final bearingDeg = step.maneuver.bearingAfter.toDouble();
    final bearingRad = bearingDeg * math.pi / 180;
    final perpRad = bearingRad + math.pi / 2;
    const double laneSpacingMeters = 5.0;
    const double metersToDegLat = 1 / 111320.0;
    final cosLat = math.cos(lat * math.pi / 180);
    final metersToDegLon = 1 / (111320.0 * (cosLat > 0.0001 ? cosLat : 0.0001));
    final n = intersection.lanes.length;
    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < n; i++) {
      final offsetM = (i - (n - 1) / 2) * laneSpacingMeters;
      final dLon = offsetM * math.sin(perpRad) * metersToDegLon;
      final dLat = offsetM * math.cos(perpRad) * metersToDegLat;
      final iconName = _laneIconFromIndications(intersection.lanes[i].indications);
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lon + dLon, lat + dLat],
        },
        'properties': {
          'icon': iconName,
          'rotation': bearingDeg,
        },
      });
    }
    final geoJson = {'type': 'FeatureCollection', 'features': features};
    try {
      await _mapboxMap!.style.setStyleSourceProperty(
        _laneGuidanceSourceId,
        'data',
        jsonEncode(geoJson),
      );
    } catch (e) {
      print('⚠️ Failed to update lane guidance on map: $e');
    }
  }

  /// Clear lane guidance symbols from the map.
  Future<void> _clearLaneGuidanceOnMap() async {
    if (_mapboxMap == null) return;
    try {
      if (!await _mapboxMap!.style.styleSourceExists(_laneGuidanceSourceId)) return;
      await _mapboxMap!.style.setStyleSourceProperty(
        _laneGuidanceSourceId,
        'data',
        jsonEncode(<String, dynamic>{
          'type': 'FeatureCollection',
          'features': <Map<String, dynamic>>[],
        }),
      );
    } catch (e) {
      print('⚠️ Failed to clear lane guidance: $e');
    }
  }

  /// Update arrow density based on zoom level
  Future<void> updateArrowDensity(double zoom) async {
    // With SymbolPlacement.LINE, symbolSpacing handles density automatically.
    // We could dynamically update symbolSpacing here if needed, but fixed spacing usually works well.
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    if (_isInitialized && _mapboxMap != null) {
      await clearRoute();

      // Clean up arrow layers
      try {
        if (await _mapboxMap!.style.styleLayerExists(_arrowLayerId)) {
          await _mapboxMap!.style.removeStyleLayer(_arrowLayerId);
        }
        if (await _mapboxMap!.style.styleSourceExists(_arrowSourceId)) {
          await _mapboxMap!.style.removeStyleSource(_arrowSourceId);
        }
        if (await _mapboxMap!.style.styleLayerExists(_laneGuidanceLayerId)) {
          await _mapboxMap!.style.removeStyleLayer(_laneGuidanceLayerId);
        }
        if (await _mapboxMap!.style.styleSourceExists(_laneGuidanceSourceId)) {
          await _mapboxMap!.style.removeStyleSource(_laneGuidanceSourceId);
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    _mapboxMap = null;
    _currentRoute = null;
    _isInitialized = false;
  }

  /// Getters
  MapboxRoute? get currentRoute => _currentRoute;
  bool get isInitialized => _isInitialized;
}

/// Custom BytesLoader for in-memory ByteData
class MemoryBytesLoader extends vg.BytesLoader {
  final ByteData _data;
  const MemoryBytesLoader(this._data);

  @override
  Future<ByteData> loadBytes(BuildContext? context) async => _data;

  @override
  int get hashCode => _data.hashCode;

  @override
  bool operator ==(Object other) =>
      other is MemoryBytesLoader && other._data == _data;
}
