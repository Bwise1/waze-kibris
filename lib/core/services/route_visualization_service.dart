import 'dart:convert';
import 'dart:math' as math;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

/// Advanced route visualization service with progress tracking and directional arrows
class RouteVisualizationService {
  static const String _routeSourceId = 'route-source';
  static const String _routeLayerId = 'route-layer-main';
  static const String _routeBorderLayerId = 'route-layer-border';
  static const String _traveledRouteLayerId = 'route-layer-traveled'; // New layer for traveled route
  static const String _arrowSourceId = 'route-arrows-source';
  static const String _arrowLayerId = 'route-arrows-layer';

  MapboxMap? _mapboxMap;
  MapboxRoute? _currentRoute;
  bool _isInitialized = false;

  // Performance optimization
  int? _lastStepIndex;
  String? _lastRouteHash;
  geo.Position? _lastUpdatePosition;
  DateTime? _lastUpdateTime;

  // Arrow visualization settings
  static const double _arrowSpacingMeters = 50.0; // Distance between arrows
  static const String _arrowImageId = 'route-arrow-icon';

  // Zoom-based arrow spacing (more arrows when zoomed in)
  static const Map<int, double> _zoomToSpacing = {
    10: 200.0, // Far zoom: sparse arrows
    12: 150.0,
    14: 100.0,
    16: 50.0,  // Default
    18: 30.0,  // Close zoom: dense arrows
    20: 20.0,  // Very close: very dense
  };

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
      print('✅ RouteVisualizationService initialized successfully');
    } catch (e) {
      print('❌ RouteVisualizationService initialization failed: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Draw route with progress tracking
  Future<void> drawRoute(MapboxRoute route,
      {int? currentStepIndex, geo.Position? currentPosition}) async {
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
      final routeHash = _generateRouteHash(route);
      final bool isNewRoute = _lastRouteHash != routeHash;
      print('   - isNewRoute: $isNewRoute');

      _currentRoute = route;
      _lastRouteHash = routeHash;

      if (currentStepIndex != null && currentPosition != null) {
        print('🔄 Updating route split for navigation progress');
        // Show progress - split into traveled and remaining
        await _updateRouteSplit(route, currentStepIndex, currentPosition);
      } else {
        print('🗺️ Showing full route (no progress tracking)');
        // Show full route
        await _showFullRoute(route);
      }

      if (isNewRoute) {
        print('🎨 Updating route layer styling');
        await _updateRouteLayerStyling(route);
        // Add directional arrows
        await _updateRouteArrows(route);
      }

      print('✅ Route drawing completed successfully');
    } catch (e) {
      print('❌ Failed to draw route: $e');
      throw Exception('Failed to draw route: $e');
    }
  }

  /// Update route progress during navigation
  Future<void> updateRouteProgress(MapboxRoute route, int currentStepIndex,
      {geo.Position? currentPosition, bool forceUpdate = false}) async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      if (!forceUpdate && !_shouldUpdateRoute(currentStepIndex, currentPosition)) {
        return;
      }

      await _updateRouteSplit(route, currentStepIndex, currentPosition);
    } catch (e) {
      throw Exception('Failed to update route progress: $e');
    }
  }

  /// Show the full route without progress
  Future<void> _showFullRoute(MapboxRoute route) async {
    try {
      final fullRouteGeoJson = _createRouteGeoJson(route);
      print('📍 Creating route with ${route.geometry.coordinates.length} coordinates');

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

  /// Update route split between traveled and remaining portions
  Future<void> _updateRouteSplit(
      MapboxRoute route, int currentStepIndex, geo.Position? currentPosition) async {
    if (currentPosition == null) {
      await _showFullRoute(route);
      return;
    }

    try {
      final coordinates = route.geometry.coordinates;
      if (coordinates.isEmpty) return;

      // Find the closest point index on the route geometry
      int closestIndex = 0;
      double minDistance = double.infinity;

      // Search for closest point
      for (int i = 0; i < coordinates.length; i++) {
        final coord = coordinates[i];
        final dist = _calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          coord[1], // lat
          coord[0], // lng
        );
        
        if (dist < minDistance) {
          minDistance = dist;
          closestIndex = i;
        }
      }

      // Create features list
      List<Map<String, dynamic>> features = [];

      // 1. Traveled Route (Start to closestIndex)
      // We go up to closestIndex to ensure it connects with the remaining route
      if (closestIndex > 0) {
        final traveledCoordinates = coordinates.sublist(0, closestIndex + 1);
        if (traveledCoordinates.length >= 2) {
          features.add({
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': traveledCoordinates,
            },
            'properties': {
              'route_id': route.hashCode.toString(),
              'is_traveled': true,
              'is_remaining': false,
            },
          });
        }
      }

      // 2. Remaining Route (closestIndex - 1 to End)
      // We start from closestIndex - 1 (or 0) to ensure overlap and prevent gaps under the puck
      final startIndex = math.max(0, closestIndex - 1);
      final remainingCoordinates = coordinates.sublist(startIndex);

      if (remainingCoordinates.length >= 2) {
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': remainingCoordinates,
          },
          'properties': {
            'route_id': route.hashCode.toString(),
            'is_traveled': false,
            'is_remaining': true,
          },
        });
      }

      final routeGeoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Update main route source
      await _mapboxMap!.style.setStyleSourceProperty(
        _routeSourceId,
        'data',
        jsonEncode(routeGeoJson),
      );

      // Cache update info
      _lastStepIndex = currentStepIndex;
      _lastUpdatePosition = currentPosition;
      _lastUpdateTime = DateTime.now();
      
    } catch (e) {
      print('⚠️ Error updating route split: $e');
      // Fallback to full route
      await _showFullRoute(route);
    }
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
  bool _shouldUpdateRoute(int? currentStepIndex, geo.Position? currentPosition) {
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
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return geo.Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Clear route from map
  Future<void> clearRoute() async {
    if (!_isInitialized || _mapboxMap == null) return;

    try {
      const emptyGeoJson = {'type': 'FeatureCollection', 'features': []};

      await _mapboxMap!.style
          .setStyleSourceProperty(_routeSourceId, 'data', emptyGeoJson);

      _currentRoute = null;
    } catch (e) {
      throw Exception('Failed to clear route: $e');
    }
  }

  /// Setup route layers on the map
  Future<void> _setupRouteLayers() async {
    if (_mapboxMap == null) return;

    try {
      const emptyGeoJson = {'type': 'FeatureCollection', 'features': []};

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
          // Dynamic width based on zoom level (Waze-style)
          lineWidthExpression: [
            'interpolate',
            ['exponential', 1.5],
            ['zoom'],
            10.0, 5.0, // Far zoom: thin border
            13.0, 8.0, // Medium zoom
            16.0, 11.0, // Close zoom
            19.0, 16.0, // Very close
            22.0, 21.0, // Maximum zoom
          ],
          lineColor: 0xFF1565C0, // Darker blue border
          lineOpacity: 0.6,
        ),
      );
      print('✅ Added route border layer: $_routeBorderLayerId');

      // 2. Traveled Route Layer (Grey)
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
            10.0, 3.0,
            13.0, 6.0,
            16.0, 9.0,
            19.0, 14.0,
            22.0, 19.0,
          ],
          lineColor: routeTraveledColor,
          lineOpacity: routeTraveledOpacity,
          filter: ['==', ['get', 'is_traveled'], true], // Only show traveled segments
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
          lineColor: routeDefaultColor,
          lineOpacity: routeOpacity,
          filter: ['!=', ['get', 'is_traveled'], true], // Only show remaining segments
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
        print('🧹 Removed existing traveled route layer: $_traveledRouteLayerId');
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
        ...route.geometry.coordinates.skip(
            math.max(0, route.geometry.coordinates.length - 3)),
      ];

      for (final coord in coordsToHash) {
        if (coord.length >= 2) {
          buffer.write('_${coord[1].toStringAsFixed(6)}_${coord[0].toStringAsFixed(6)}');
        }
      }
    }

    return buffer.toString().hashCode.toString();
  }

  /// Setup arrow layers for route visualization
  Future<void> _setupArrowLayers() async {
    if (_mapboxMap == null) return;

    try {
      const emptyGeoJson = {'type': 'FeatureCollection', 'features': []};

      // Remove existing arrow layers if they exist
      if (await _mapboxMap!.style.styleLayerExists(_arrowLayerId)) {
        await _mapboxMap!.style.removeStyleLayer(_arrowLayerId);
      }
      if (await _mapboxMap!.style.styleSourceExists(_arrowSourceId)) {
        await _mapboxMap!.style.removeStyleSource(_arrowSourceId);
      }

      // Add arrow source
      await _mapboxMap!.style.addSource(
        GeoJsonSource(id: _arrowSourceId, data: jsonEncode(emptyGeoJson)),
      );

      // Add arrow symbol layer with expression-based properties
      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: _arrowLayerId,
          sourceId: _arrowSourceId,
          iconImage: 'triangle-11', // Use built-in Mapbox arrow
          iconSizeExpression: [
            'interpolate',
            ['linear'],
            ['zoom'],
            10.0, 0.3, // Small at far zoom
            13.0, 0.5,
            16.0, 0.7, // Medium at close zoom
            19.0, 1.0, // Large at very close zoom
          ],
          iconRotationAlignment: IconRotationAlignment.MAP,
          iconAllowOverlap: true,
          iconIgnorePlacement: false,
          iconRotateExpression: ['get', 'bearing'],
          iconColor: 0xFFFFFFFF, // White arrows
          iconOpacity: 0.9,
        ),
      );

      print('✅ Arrow layers setup completed');
    } catch (e) {
      print('❌ Failed to setup arrow layers: $e');
      // Non-critical, continue anyway
    }
  }

  /// Update route arrows based on route geometry
  Future<void> _updateRouteArrows(MapboxRoute route, {double? currentZoom}) async {
    if (_mapboxMap == null) return;

    try {
      final arrowPoints = await _generateArrowPoints(route, currentZoom: currentZoom);

      final arrowGeoJson = {
        'type': 'FeatureCollection',
        'features': arrowPoints.map((point) {
          return {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [point['lng'], point['lat']],
            },
            'properties': {
              'bearing': point['bearing'],
            },
          };
        }).toList(),
      };

      await _mapboxMap!.style.setStyleSourceProperty(
        _arrowSourceId,
        'data',
        jsonEncode(arrowGeoJson),
      );

      print('✅ Updated ${arrowPoints.length} route arrows');
    } catch (e) {
      print('⚠️ Failed to update route arrows: $e');
      // Non-critical error
    }
  }

  /// Update arrow density based on zoom level
  Future<void> updateArrowDensity(double zoom) async {
    if (_currentRoute == null) return;
    await _updateRouteArrows(_currentRoute!, currentZoom: zoom);
  }

  /// Generate arrow points along the route at regular intervals
  Future<List<Map<String, double>>> _generateArrowPoints(MapboxRoute route, {double? currentZoom}) async {
    final List<Map<String, double>> arrowPoints = [];
    final coordinates = route.geometry.coordinates;

    if (coordinates.length < 2) return arrowPoints;

    // Determine arrow spacing based on zoom level
    double arrowSpacing = _arrowSpacingMeters;
    if (currentZoom != null) {
      arrowSpacing = _getArrowSpacingForZoom(currentZoom);
    }

    double accumulatedDistance = 0.0;
    double nextArrowDistance = arrowSpacing;

    for (int i = 0; i < coordinates.length - 1; i++) {
      final start = coordinates[i];
      final end = coordinates[i + 1];

      final segmentDistance = _calculateDistance(
        start[1], start[0], // lat, lng
        end[1], end[0],
      );

      // Check if we should place arrow(s) in this segment
      while (accumulatedDistance + segmentDistance >= nextArrowDistance) {
        final distanceIntoSegment = nextArrowDistance - accumulatedDistance;
        final ratio = distanceIntoSegment / segmentDistance;

        // Interpolate position
        final arrowLng = start[0] + (end[0] - start[0]) * ratio;
        final arrowLat = start[1] + (end[1] - start[1]) * ratio;

        // Calculate bearing for arrow rotation
        final bearing = _calculateBearing(start[1], start[0], end[1], end[0]);

        arrowPoints.add({
          'lng': arrowLng,
          'lat': arrowLat,
          'bearing': bearing,
        });

        nextArrowDistance += arrowSpacing;
      }

      accumulatedDistance += segmentDistance;
    }

    return arrowPoints;
  }

  /// Calculate bearing between two points (in degrees)
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * (math.pi / 180);
    final lat1Rad = lat1 * (math.pi / 180);
    final lat2Rad = lat2 * (math.pi / 180);

    final y = math.sin(dLng) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);

    final bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  /// Get arrow spacing based on zoom level (more arrows when zoomed in)
  double _getArrowSpacingForZoom(double zoom) {
    final zoomInt = zoom.round();

    // Find closest zoom level in map
    if (_zoomToSpacing.containsKey(zoomInt)) {
      return _zoomToSpacing[zoomInt]!;
    }

    // Interpolate between zoom levels
    final lowerZoom = _zoomToSpacing.keys.where((z) => z <= zoomInt).fold<int?>(null, (max, z) => max == null || z > max ? z : max);
    final upperZoom = _zoomToSpacing.keys.where((z) => z >= zoomInt).fold<int?>(null, (min, z) => min == null || z < min ? z : min);

    if (lowerZoom != null && upperZoom != null && lowerZoom != upperZoom) {
      final t = (zoom - lowerZoom) / (upperZoom - lowerZoom);
      return _zoomToSpacing[lowerZoom]! + (_zoomToSpacing[upperZoom]! - _zoomToSpacing[lowerZoom]!) * t;
    }

    return _arrowSpacingMeters; // Default fallback
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

