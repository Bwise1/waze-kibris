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
  static const String _arrowSourceId = 'route-arrows-source';
  static const String _arrowLayerId = 'route-arrows-layer';
  static const String _laneGuidanceSourceId = 'lane-guidance-source';
  static const String _laneGuidanceLayerId = 'lane-guidance-layer';

  MapboxMap? _mapboxMap;
  MapboxRoute? _currentRoute;
  bool _isInitialized = false;

  // Performance optimization
  int? _lastStepIndex;
  String? _lastRouteHash;
  geo.Position? _lastUpdatePosition;
  DateTime? _lastUpdateTime;

  // Arrow visualization settings
  static const String _arrowImageId = 'route-arrow-icon';

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

  /// Initialize the service with a Mapbox map
  Future<void> initialize(MapboxMap mapboxMap) async {
    print('🔧 Initializing RouteVisualizationService');
    _mapboxMap = mapboxMap;
    _isInitialized = true;

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

      if (currentStepIndex != null && currentPosition != null) {
        print('🔄 Updating route split for navigation progress');
        await _updateRouteSplit(
            route, currentStepIndex, 0, currentPosition); // leg 0 when from drawRoute
      } else {
        print('🗺️ Showing full route (no progress tracking)');
        // Show full route
        await _showFullRoute(route);
      }

      if (isNewRoute) {
        print('🎨 Updating route layer styling');
        await _updateRouteLayerStyling(route);
      }

      // Draw lane guidance on the map at the upcoming intersection (native-style)
      if (currentStepIndex != null) {
        await _drawLaneGuidanceOnMap(
            route, currentStepIndex, 0); // leg 0 when from drawRoute
      } else {
        await _clearLaneGuidanceOnMap();
      }

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
        return;
      }

      await _updateRouteSplit(
          route, currentStepIndex, currentLegIndex, currentPosition);
      await _drawLaneGuidanceOnMap(route, currentStepIndex, currentLegIndex);
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

  /// Returns the maximum segment index (in route geometry) that may be used for
  /// the split, so the split cannot be ahead of the current step. Returns null
  /// if legs/steps are missing or indices are out of range (no cap).
  int? _getMaxSegmentIndexForStep(
    MapboxRoute route,
    int currentLegIndex,
    int currentStepIndex,
  ) {
    if (route.legs.isEmpty ||
        currentLegIndex < 0 ||
        currentLegIndex >= route.legs.length) {
      return null;
    }
    final leg = route.legs[currentLegIndex];
    if (leg.steps.isEmpty ||
        currentStepIndex < 0 ||
        currentStepIndex >= leg.steps.length) {
      return null;
    }
    final maneuverLocation = leg.steps[currentStepIndex].maneuver.location;
    if (maneuverLocation.length < 2) return null;

    final coordinates = route.geometry.coordinates;
    if (coordinates.length < 2) return null;

    final mLng = maneuverLocation[0];
    final mLat = maneuverLocation[1];
    int bestSegment = 0;
    double minDist = double.infinity;

    for (int i = 0; i < coordinates.length - 1; i++) {
      final p1 = coordinates[i];
      final p2 = coordinates[i + 1];
      final proj = _projectPointOnSegment([mLng, mLat], p1, p2);
      final dist = _calculateDistance(mLat, mLng, proj[1], proj[0]);
      if (dist < minDist) {
        minDist = dist;
        bestSegment = i;
      }
    }
    // Allow one segment past the step so split can sit slightly ahead of step start
    final cap = (bestSegment + 1).clamp(0, coordinates.length - 1);
    return cap;
  }

  /// Update route split between traveled and remaining portions
  Future<void> _updateRouteSplit(
    MapboxRoute route,
    int currentStepIndex,
    int currentLegIndex,
    geo.Position? currentPosition,
  ) async {
    if (currentPosition == null) {
      await _showFullRoute(route);
      return;
    }

    try {
      final coordinates = route.geometry.coordinates;
      if (coordinates.isEmpty) return;

      final maxSegmentIndex =
          _getMaxSegmentIndexForStep(route, currentLegIndex, currentStepIndex);
      final maxSeg = maxSegmentIndex ?? (coordinates.length - 1);

      // Find the closest point on the route geometry (projected), only up to maxSeg
      // so the split cannot be ahead of the current step
      int closestSegmentIndex = 0;
      double minDistance = double.infinity;
      List<double> projectedPoint = coordinates[0];

      for (int i = 0; i <= maxSeg && i < coordinates.length - 1; i++) {
        final p1 = coordinates[i];
        final p2 = coordinates[i + 1];

        final proj = _projectPointOnSegment(
          [currentPosition.longitude, currentPosition.latitude],
          p1,
          p2,
        );

        final dist = _calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          proj[1], // lat
          proj[0], // lng
        );

        if (dist < minDistance) {
          minDistance = dist;
          closestSegmentIndex = i;
          projectedPoint = proj;
        }
      }

      // 1. Traveled Route (Start -> ... -> SegmentStart -> ProjectedPoint)
      List<List<double>> traveledCoords = [];
      if (closestSegmentIndex >= 0) {
        traveledCoords.addAll(coordinates.sublist(0, closestSegmentIndex + 1));
        traveledCoords.add(projectedPoint);
      } else {
        traveledCoords.add(projectedPoint);
      }

      List<Map<String, dynamic>> features = [];
      if (traveledCoords.length >= 2) {
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': traveledCoords,
          },
          'properties': {
            'route_id': route.hashCode.toString(),
            'is_traveled': true,
            'is_remaining': false,
          },
        });
      }

      // 2. Remaining Route (ProjectedPoint -> SegmentEnd -> ... -> End)
      List<List<double>> remainingCoords = [];
      remainingCoords.add(projectedPoint);
      if (closestSegmentIndex + 1 < coordinates.length) {
        remainingCoords.addAll(coordinates.sublist(closestSegmentIndex + 1));
      }

      // Fallback: if remaining would be empty or a single point, show full route
      // so the line never disappears in front of the puck
      if (remainingCoords.length < 2) {
        await _showFullRoute(route);
        _lastStepIndex = currentStepIndex;
        _lastUpdatePosition = currentPosition;
        _lastUpdateTime = DateTime.now();
        return;
      }

      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': remainingCoords,
        },
        'properties': {
          'route_id': route.hashCode.toString(),
          'is_traveled': false,
          'is_remaining': true,
        },
      });

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      await _mapboxMap!.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        jsonEncode(geoJson),
      );

      _lastStepIndex = currentStepIndex;
      _lastUpdatePosition = currentPosition;
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      print('❌ Failed to update route split: $e');
      await _showFullRoute(route);
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

  /// Clear route from map
  Future<void> clearRoute() async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
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
      await _clearLaneGuidanceOnMap();

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

      // Add single source (like the old code)
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _routeSourceId, data: jsonEncode(emptyGeoJson)),
      );
      print('✅ Added route source: $_routeSourceId');

      // 1. Route border layer (shared for both)
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeBorderLayerId,
          sourceId: _routeSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          // Thicker casing for professional look (Main width + ~4px)
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            10.0, 7.0, // 3 + 4
            13.0, 10.0, // 6 + 4
            16.0, 13.0, // 9 + 4
            19.0, 18.0, // 14 + 4
            22.0, 23.0, // 19 + 4
          ],
          lineColor: 0xFF1556B8, // Professional Dark Blue Border
          lineOpacity: 1.0, // Solid opacity
          filter: [
            '!=',
            ['get', 'is_traveled'],
            true
          ], // Only border the remaining route
        ),
      );
      print('✅ Added route border layer: $_routeBorderLayerId');

      // 2. Traveled Route Layer (Faded Blue)
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _traveledRouteLayerId,
          sourceId: _routeSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            10.0,
            3.0,
            13.0,
            6.0,
            16.0,
            9.0,
            19.0,
            14.0,
            22.0,
            19.0,
          ],
          lineColor: 0xFF89CFF0, // Faded/Baby Blue
          lineOpacity: 0.6, // Slightly transparent for "faded" look
          filter: [
            '==',
            ['get', 'is_traveled'],
            true
          ], // Only show traveled segments
        ),
      );
      print('✅ Added traveled route layer: $_traveledRouteLayerId');

      // 3. Main Route Layer (Active/Remaining)
      await _mapboxMap!.style.addLayer(
        LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
          // Dynamic width based on zoom level (Waze-style)
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            10.0, 3.0, // Far zoom: thin line
            13.0, 6.0, // Medium zoom
            16.0, 9.0, // Close zoom
            19.0, 14.0, // Very close: thick navigation line
            22.0, 19.0, // Maximum zoom: very thick
          ],
          lineColor: 0xFF4A90E2, // Vibrant Professional Blue
          lineOpacity: 1.0, // Solid opacity
          filter: [
            '!=',
            ['get', 'is_traveled'],
            true
          ], // Only show remaining segments
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
  Future<void> _updateRouteLayerStyling(MapboxRoute route) async {
    if (_mapboxMap == null) return;

    try {
      // Calculate traffic-aware color but don't override expressions
      final avgSpeed = route.distance / route.duration * 3.6; // km/h
      int routeColor = routeDefaultColor;

      if (avgSpeed > 60) {
        routeColor = trafficLightColor; // Fast route - green
      } else if (avgSpeed > 40) {
        routeColor = routeDefaultColor; // Normal - blue
      } else if (avgSpeed > 20) {
        routeColor = trafficModerateColor; // Slow - yellow
      } else {
        routeColor = trafficHeavyColor; // Very slow - red
      }

      // Only update color, don't override width expressions
      await _mapboxMap!.style.setStyleLayerProperty(
        _routeLayerId,
        'line-color',
        routeColor,
      );
    } catch (e) {
      // Ignore styling errors - this is not critical
      print('Route styling update failed: $e');
    }
  }

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
      // Create arrow image programmatically
      await _createChevronImage();

      final emptyGeoJson = <String, dynamic>{
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      if (await _mapboxMap!.style.styleLayerExists(_arrowLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_arrowLayerId);
      }
      if (await _mapboxMap!.style.styleSourceExists(_arrowSourceId)) {
        await _mapboxMap!.style.removeStyleSource(_arrowSourceId);
      }

      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _arrowSourceId, data: jsonEncode(emptyGeoJson)),
      );

      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: _arrowLayerId,
          sourceId: _arrowSourceId,
          iconImage: _arrowImageId,
          iconSize: 0.8, // Good size for 64px image
          symbolPlacement: SymbolPlacement.LINE,
          symbolSpacing: 100.0,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
      );

      // Ensure it's on top
      try {
        await _mapboxMap!.style.moveStyleLayer(_arrowLayerId, null);
      } catch (e) {
        // Ignore if already on top or fails
      }

      print('✅ Arrow layers setup');
    } catch (e) {
      print('❌ Failed to setup arrow layers: $e');
    }
  }

  /// Create a chevron image programmatically using Canvas
  Future<void> _createChevronImage() async {
    if (_mapboxMap == null) return;

    try {
      const double size = 64.0;
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(pictureRecorder);

      // Draw a white filled triangle (chevron)
      final ui.Paint paint = ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..style = ui.PaintingStyle.fill;

      final ui.Path path = ui.Path();
      // Pointing right (0 degrees) to align with line direction
      path.moveTo(size * 0.2, size * 0.2); // Top left
      path.lineTo(size * 0.8, size * 0.5); // Middle right (tip)
      path.lineTo(size * 0.2, size * 0.8); // Bottom left
      path.close();

      canvas.drawPath(path, paint);

      // Add a black outline for better visibility on light roads
      final ui.Paint strokePaint = ui.Paint()
        ..color = const ui.Color(0xFF000000)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeJoin = ui.StrokeJoin.round;

      canvas.drawPath(path, strokePaint);

      final ui.Image image = await pictureRecorder
          .endRecording()
          .toImage(size.toInt(), size.toInt());
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List list = byteData.buffer.asUint8List();
        await _mapboxMap!.style.addStyleImage(
            _arrowImageId,
            2.0, // Scale
            MbxImage(width: size.toInt(), height: size.toInt(), data: list),
            false,
            [],
            [],
            null);
        print('✅ Created and loaded programmatic chevron image');
      }
    } catch (e) {
      print('❌ Failed to create chevron image: $e');
    }
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
