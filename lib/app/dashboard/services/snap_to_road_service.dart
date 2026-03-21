import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';

class SnapToRoadService {
  static const double _snapDistanceThreshold = 50.0; // meters
  static const double _offRouteThreshold = 100.0; // meters  
  static const double _rerouteThreshold = 150.0; // meters - when to trigger reroute
  static const double _smoothingFactor = 0.15; // for position smoothing - reduced for more responsive snapping
  static const double _stickySnapThreshold = 5.0; // meters - force puck within this distance when on-route

  // Cache for route points and Mapbox route for along-route distances
  List<PointLatLng>? _currentRoutePoints;
  MapboxRoute? _currentMapboxRoute;
  List<double>? _cumulativeDistances; // cumulative meters from route start to each point index
  double? _totalRouteLengthMeters;
  PointLatLng? _lastSnappedPoint;
  int _lastNearestIndex = 0;
  
  // Rerouting detection
  DateTime? _firstOffRouteTime;
  int _consecutiveOffRouteUpdates = 0;
  static const int _offRouteUpdatesThreshold = 3; // consecutive updates needed
  static const Duration _offRouteDurationThreshold = Duration(seconds: 10);

  // GPS jump detection for connectivity issues
  geo.Position? _lastGpsPosition;
  DateTime? _lastGpsTime;
  static const double _gpsJumpThreshold = 200.0; // meters - suspicious GPS jump
  static const Duration _gpsTimeThreshold = Duration(seconds: 30); // time gap indicating issues

  // Map Matching integration for edge cases
  PlacesService? _placesService;
  List<geo.Position> _gpsTraceBuffer = [];
  DateTime? _lastMapMatchingCall;
  static const Duration _mapMatchingCooldown = Duration(minutes: 2); // Minimize API usage
  static const int _maxTraceBufferSize = 10; // Max GPS points to buffer
  static const double _mapMatchingThreshold = 300.0; // meters - when to trigger map matching

  /// Initialize with current route (Google format; no along-route to maneuver)
  void setRoute(DirectionsRoute route) {
    _currentMapboxRoute = null;
    _currentRoutePoints = _decodeRoutePolyline(route);
    _cumulativeDistances = _buildCumulativeDistances(_currentRoutePoints!);
    _totalRouteLengthMeters = _cumulativeDistances != null && _cumulativeDistances!.isNotEmpty
        ? _cumulativeDistances!.last
        : null;
    _lastNearestIndex = 0;
    _lastSnappedPoint = null;
  }

  /// Initialize with Mapbox route (stores route for along-route distance to step maneuver)
  void setMapboxRoute(MapboxRoute route) {
    _currentMapboxRoute = route;
    _currentRoutePoints = _decodeMapboxRouteGeometry(route);
    _cumulativeDistances = _buildCumulativeDistances(_currentRoutePoints!);
    _totalRouteLengthMeters = _cumulativeDistances != null && _cumulativeDistances!.isNotEmpty
        ? _cumulativeDistances!.last
        : null;
    _lastNearestIndex = 0;
    _lastSnappedPoint = null;
  }

  /// Set PlacesService for Map Matching functionality
  void setPlacesService(PlacesService placesService) {
    _placesService = placesService;
  }

  /// Clear route data
  void clearRoute() {
    _currentRoutePoints = null;
    _currentMapboxRoute = null;
    _cumulativeDistances = null;
    _totalRouteLengthMeters = null;
    _lastSnappedPoint = null;
    _lastNearestIndex = 0;
    _clearGpsHistory();
    _resetOffRouteTracking();
    _clearMapMatchingBuffer();
  }

  /// Returns route points from current snap position to end (for overview framing). Null if no route.
  List<PointLatLng>? getRemainingRoutePoints() {
    if (_currentRoutePoints == null || _currentRoutePoints!.isEmpty) return null;
    if (_lastNearestIndex >= _currentRoutePoints!.length) return null;
    return _currentRoutePoints!.sublist(_lastNearestIndex);
  }

  /// Snap GPS position to nearest point on route with rerouting detection.
  /// When [currentLegIndex] and [currentStepIndex] are provided and a Mapbox route is set,
  /// [SnapToRoadResult] includes along-route distances for navigation (distance to maneuver, etc.).
  Future<SnapToRoadResult> snapToRoad(
    geo.Position gpsPosition, {
    int? currentLegIndex,
    int? currentStepIndex,
  }) async {
    if (_currentRoutePoints == null || _currentRoutePoints!.isEmpty) {
      return SnapToRoadResult(
        snappedPosition:
            PointLatLng(gpsPosition.latitude, gpsPosition.longitude),
        isOnRoute: false,
        distanceFromRoute: 0,
        routeProgress: 0,
        bearing: gpsPosition.heading,
      );
    }

    final gpsPoint = PointLatLng(gpsPosition.latitude, gpsPosition.longitude);

    // Detect GPS jumps (potential connectivity issues)
    final hasGpsJump = _detectGpsJump(gpsPosition);
    if (hasGpsJump) {
      debugPrint('🛰️ GPS jump detected - using conservative snapping');
    }

    // Add GPS position to trace buffer for potential Map Matching
    _addToGpsTraceBuffer(gpsPosition);

    // Find nearest point on route
    var nearestResult = _findNearestPointOnRoute(gpsPoint);

    // Check if Map Matching should be triggered for edge cases
    final shouldUseMapMatching = _shouldTriggerMapMatching(nearestResult.distance, gpsPosition);
    
    if (shouldUseMapMatching) {
      // Try Map Matching for better accuracy in edge cases
      final mapMatchedResult = await _tryMapMatching(gpsPosition);
      if (mapMatchedResult != null) {
        // Use map matched position and recalculate nearest point
        final mapMatchedPoint = PointLatLng(mapMatchedResult.latitude, mapMatchedResult.longitude);
        nearestResult = _findNearestPointOnRoute(mapMatchedPoint);
        debugPrint('🗺️ Used Map Matching: improved accuracy by ${(nearestResult.distance - _calculateDistance(gpsPoint, nearestResult.point)).abs().toStringAsFixed(1)}m');
      }
    }

    // Determine route status
    final isOnRoute = nearestResult.distance <= _snapDistanceThreshold;
    final isOffRoute = nearestResult.distance > _offRouteThreshold;
    final needsReroute = _shouldTriggerReroute(nearestResult.distance, gpsPosition);

    PointLatLng snappedPoint;
    double bearing = gpsPosition.heading;

    if (isOnRoute && !hasGpsJump) {
      // User is on route and GPS is stable - snap with smoothing and sticky snap
      snappedPoint = _smoothSnapPosition(nearestResult.point, gpsPoint);
      
      // Sticky snap: force puck within threshold when on-route
      final distanceToSnapped = _calculateDistance(gpsPoint, snappedPoint);
      if (distanceToSnapped > _stickySnapThreshold) {
        // If puck would escape beyond threshold, clamp it to threshold distance
        snappedPoint = _movePointTowards(snappedPoint, gpsPoint, _stickySnapThreshold);
      }
      
      bearing = _calculateRouteBearing(nearestResult.index);
      _lastSnappedPoint = snappedPoint;
      _lastNearestIndex = nearestResult.index;
      
      // Reset off-route tracking
      _resetOffRouteTracking();
      
    } else if (isOnRoute && hasGpsJump) {
      // GPS jump but still on route - use less aggressive snapping with sticky snap
      snappedPoint = _blendPositions(gpsPoint, nearestResult.point, 0.3);
      
      // Apply sticky snap even during GPS jumps
      final distanceToSnapped = _calculateDistance(gpsPoint, snappedPoint);
      if (distanceToSnapped > _stickySnapThreshold) {
        snappedPoint = _movePointTowards(snappedPoint, gpsPoint, _stickySnapThreshold);
      }
      
      bearing = _interpolateBearing(gpsPosition.heading, _calculateRouteBearing(nearestResult.index), 0.3);
      _lastSnappedPoint = snappedPoint;
      _lastNearestIndex = nearestResult.index;
      
    } else if (isOffRoute && !needsReroute) {
      // User is off route but not far enough for reroute yet - ALWAYS snap to nearest route point
      // Don't use raw GPS - this prevents visible "escape" from route
      snappedPoint = nearestResult.point;
      bearing = _calculateRouteBearing(nearestResult.index);
      _lastSnappedPoint = snappedPoint;
      _lastNearestIndex = nearestResult.index;
      
    } else if (needsReroute) {
      // User needs rerouting - use GPS position (reroute will handle this)
      snappedPoint = gpsPoint;
      bearing = gpsPosition.heading;
      
      debugPrint('🔄 REROUTE NEEDED: Distance from route: ${nearestResult.distance.toStringAsFixed(1)}m');
      
    } else {
      // User is close to route - blend positions for smooth transition
      final blendWeight = hasGpsJump ? 0.2 : 0.4; // Less blending for GPS jumps
      snappedPoint = _blendPositions(gpsPoint, nearestResult.point, blendWeight);
      bearing = _interpolateBearing(gpsPosition.heading, _calculateRouteBearing(nearestResult.index), 0.6);
    }

    // Update position history for GPS jump detection
    _updatePositionHistory(gpsPosition);

    // Along-route distances (for navigation parity with native SDK)
    double? distanceTraveledAlongRouteMeters;
    double? distanceToCurrentStepManeuverAlongRouteMeters;
    double? remainingDistanceAlongRouteMeters;
    if (_cumulativeDistances != null &&
        _currentRoutePoints != null &&
        _currentRoutePoints!.isNotEmpty) {
      final idx = nearestResult.index.clamp(0, _currentRoutePoints!.length - 1);
      final partialSegment = idx < _currentRoutePoints!.length - 1
          ? _calculateDistance(_currentRoutePoints![idx], nearestResult.point)
          : 0.0;
      distanceTraveledAlongRouteMeters =
          (_cumulativeDistances![idx] + partialSegment).clamp(0.0, _totalRouteLengthMeters ?? 0.0);

      if (currentLegIndex != null &&
          currentStepIndex != null &&
          _currentMapboxRoute != null &&
          currentLegIndex < _currentMapboxRoute!.legs.length) {
        final leg = _currentMapboxRoute!.legs[currentLegIndex];
        if (currentStepIndex < leg.steps.length) {
          final step = leg.steps[currentStepIndex];
          if (step.maneuver.location.length >= 2) {
            final maneuverLat = step.maneuver.location[1];
            final maneuverLng = step.maneuver.location[0];
            final maneuverPoint = PointLatLng(maneuverLat, maneuverLng);
            final maneuverRouteIndex = _findNearestRouteIndex(maneuverPoint);
            final distanceToManeuverAlongRoute = maneuverRouteIndex != null
                ? (_cumulativeDistances![maneuverRouteIndex] - distanceTraveledAlongRouteMeters)
                : null;
            if (distanceToManeuverAlongRoute != null) {
              distanceToCurrentStepManeuverAlongRouteMeters =
                  distanceToManeuverAlongRoute.clamp(-50.0, double.infinity);
            }
          }
        }
      }

      if (_totalRouteLengthMeters != null) {
        final total = _totalRouteLengthMeters!;
        remainingDistanceAlongRouteMeters =
            (total - distanceTraveledAlongRouteMeters).clamp(0.0, total);
      }
    }

    return SnapToRoadResult(
      snappedPosition: snappedPoint,
      isOnRoute: isOnRoute,
      distanceFromRoute: nearestResult.distance,
      routeProgress: _calculateRouteProgress(nearestResult.index),
      bearing: bearing,
      isOffRoute: isOffRoute,
      needsReroute: needsReroute,
      routeIndex: nearestResult.index,
      distanceTraveledAlongRouteMeters: distanceTraveledAlongRouteMeters,
      distanceToCurrentStepManeuverAlongRouteMeters:
          distanceToCurrentStepManeuverAlongRouteMeters,
      remainingDistanceAlongRouteMeters: remainingDistanceAlongRouteMeters,
    );
  }

  /// Snap polyline points to roads using Google Roads API
  Future<List<PointLatLng>> snapPolylineToRoads(
    List<PointLatLng> points,
    String apiKey,
  ) async {
    try {
      // Split into chunks of 100 points (Google Roads API limit)
      const chunkSize = 100;
      List<PointLatLng> snappedPoints = [];

      for (int i = 0; i < points.length; i += chunkSize) {
        final chunk = points.sublist(
          i,
          math.min(i + chunkSize, points.length),
        );

        final snappedChunk = await _snapChunkToRoads(chunk, apiKey);
        snappedPoints.addAll(snappedChunk);
      }

      return snappedPoints;
    } catch (e) {
      debugPrint('Error snapping to roads: $e');
      return points; // Return original points on error
    }
  }

  /// Find nearest point on route
  _NearestPointResult _findNearestPointOnRoute(PointLatLng gpsPoint) {
    if (_currentRoutePoints == null || _currentRoutePoints!.isEmpty) {
      return _NearestPointResult(gpsPoint, 0, double.infinity);
    }

    double minDistance = double.infinity;
    PointLatLng nearestPoint = _currentRoutePoints![0];
    int nearestIndex = 0;

    // First try efficient local search from last known position
    final localResult = _localSearch(gpsPoint);
    
    // If local search finds a good result (within reasonable distance), use it
    if (localResult.distance < _offRouteThreshold * 2) {
      return localResult;
    }

    // Local search failed or result is too far - fallback to full route search
    debugPrint('🔍 Local search failed (${localResult.distance.toStringAsFixed(1)}m), performing full route search');
    
    for (int i = 0; i < _currentRoutePoints!.length - 1; i++) {
      final segmentResult = _nearestPointOnSegment(
        gpsPoint,
        _currentRoutePoints![i],
        _currentRoutePoints![i + 1],
      );

      if (segmentResult.distance < minDistance) {
        minDistance = segmentResult.distance;
        nearestPoint = segmentResult.point;
        nearestIndex = i;
      }
    }

    return _NearestPointResult(nearestPoint, nearestIndex, minDistance);
  }

  /// Efficient local search around last known position
  _NearestPointResult _localSearch(PointLatLng gpsPoint) {
    double minDistance = double.infinity;
    PointLatLng nearestPoint = _currentRoutePoints![0];
    int nearestIndex = 0;

    // Expanded search window for better coverage - increased to prevent escape
    final startIndex = math.max(0, _lastNearestIndex - 50);
    final endIndex = math.min(
      _currentRoutePoints!.length,
      _lastNearestIndex + 200,
    );

    for (int i = startIndex; i < endIndex - 1; i++) {
      final segmentResult = _nearestPointOnSegment(
        gpsPoint,
        _currentRoutePoints![i],
        _currentRoutePoints![i + 1],
      );

      if (segmentResult.distance < minDistance) {
        minDistance = segmentResult.distance;
        nearestPoint = segmentResult.point;
        nearestIndex = i;
      }
    }

    return _NearestPointResult(nearestPoint, nearestIndex, minDistance);
  }

  /// Find nearest point on a line segment
  _SegmentResult _nearestPointOnSegment(
    PointLatLng point,
    PointLatLng segmentStart,
    PointLatLng segmentEnd,
  ) {
    final dx = segmentEnd.longitude - segmentStart.longitude;
    final dy = segmentEnd.latitude - segmentStart.latitude;

    if (dx == 0 && dy == 0) {
      // Segment is a point
      final distance = _calculateDistance(point, segmentStart);
      return _SegmentResult(segmentStart, distance);
    }

    final t = ((point.longitude - segmentStart.longitude) * dx +
            (point.latitude - segmentStart.latitude) * dy) /
        (dx * dx + dy * dy);

    final clampedT = math.max(0.0, math.min(1.0, t));

    final nearestPoint = PointLatLng(
      segmentStart.latitude + clampedT * dy,
      segmentStart.longitude + clampedT * dx,
    );

    final distance = _calculateDistance(point, nearestPoint);
    return _SegmentResult(nearestPoint, distance);
  }

  /// Smooth snap position to reduce jitter
  PointLatLng _smoothSnapPosition(
      PointLatLng snappedPoint, PointLatLng gpsPoint) {
    if (_lastSnappedPoint == null) {
      return snappedPoint;
    }

    // Apply smoothing factor
    final lat = _lastSnappedPoint!.latitude * _smoothingFactor +
        snappedPoint.latitude * (1 - _smoothingFactor);
    final lng = _lastSnappedPoint!.longitude * _smoothingFactor +
        snappedPoint.longitude * (1 - _smoothingFactor);

    return PointLatLng(lat, lng);
  }

  /// Blend two positions based on weight
  PointLatLng _blendPositions(
      PointLatLng point1, PointLatLng point2, double weight) {
    final lat = point1.latitude * (1 - weight) + point2.latitude * weight;
    final lng = point1.longitude * (1 - weight) + point2.longitude * weight;
    return PointLatLng(lat, lng);
  }

  /// Move a point towards another point by a maximum distance (for sticky snap)
  PointLatLng _movePointTowards(PointLatLng from, PointLatLng to, double maxDistance) {
    final distance = _calculateDistance(from, to);
    if (distance <= maxDistance) {
      return from; // Already within threshold
    }
    
    // Calculate direction vector
    final bearing = _calculateBearing(from, to);
    final bearingRad = bearing * math.pi / 180.0;
    
    // Move from point towards to point by maxDistance
    final lat1Rad = from.latitude * math.pi / 180.0;
    final dLat = maxDistance / 111320.0; // meters to degrees (approximate)
    final dLng = maxDistance / (111320.0 * math.cos(lat1Rad));
    
    final newLat = from.latitude + (dLat * math.cos(bearingRad));
    final newLng = from.longitude + (dLng * math.sin(bearingRad));
    
    return PointLatLng(newLat, newLng);
  }

  /// Calculate bearing along route
  double _calculateRouteBearing(int routeIndex) {
    if (_currentRoutePoints == null ||
        routeIndex >= _currentRoutePoints!.length - 1) {
      return 0.0;
    }

    final current = _currentRoutePoints![routeIndex];
    final next = _currentRoutePoints![routeIndex + 1];

    return _calculateBearing(current, next);
  }

  /// Calculate bearing between two points
  double _calculateBearing(PointLatLng from, PointLatLng to) {
    final dLng = (to.longitude - from.longitude) * math.pi / 180.0;
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(PointLatLng point1, PointLatLng point2) {
    return geo.Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Determine if rerouting should be triggered
  bool _shouldTriggerReroute(double distanceFromRoute, geo.Position gpsPosition) {
    final now = DateTime.now();
    
    if (distanceFromRoute > _rerouteThreshold) {
      _firstOffRouteTime ??= now;
      _consecutiveOffRouteUpdates++;
      
      // Check if user has been off route long enough AND moving in wrong direction
      final timeOffRoute = now.difference(_firstOffRouteTime!);
      final isMovingAwayFromRoute = _isMovingAwayFromRoute(gpsPosition);
      
      if (_consecutiveOffRouteUpdates >= _offRouteUpdatesThreshold &&
          timeOffRoute >= _offRouteDurationThreshold &&
          isMovingAwayFromRoute) {
        
        debugPrint('🚨 REROUTE TRIGGERED: ${distanceFromRoute.toStringAsFixed(1)}m away, '
            '${timeOffRoute.inSeconds}s off route, moving away: $isMovingAwayFromRoute');
        
        return true;
      }
    } else {
      _resetOffRouteTracking();
    }
    
    return false;
  }

  /// Check if user is moving away from the route
  bool _isMovingAwayFromRoute(geo.Position gpsPosition) {
    if (_currentRoutePoints == null || _lastNearestIndex >= _currentRoutePoints!.length - 1) {
      return false;
    }

    // final userPoint = PointLatLng(gpsPosition.latitude, gpsPosition.longitude); // Currently unused
    final nearestRoutePoint = _currentRoutePoints![_lastNearestIndex];
    final nextRoutePoint = _currentRoutePoints![_lastNearestIndex + 1];

    // Calculate angle between user heading and route direction
    final routeBearing = _calculateBearing(nearestRoutePoint, nextRoutePoint);
    final userBearing = gpsPosition.heading;
    
    final bearingDifference = _calculateBearingDifference(userBearing, routeBearing);
    
    // If user is heading more than 90 degrees away from route direction, they're moving away
    return bearingDifference > 90;
  }

  /// Calculate the difference between two bearings
  double _calculateBearingDifference(double bearing1, double bearing2) {
    double diff = (bearing1 - bearing2).abs();
    if (diff > 180) {
      diff = 360 - diff;
    }
    return diff;
  }

  /// Reset off-route tracking when user returns to route
  void _resetOffRouteTracking() {
    _firstOffRouteTime = null;
    _consecutiveOffRouteUpdates = 0;
  }

  /// Interpolate between two bearings for smooth transitions
  double _interpolateBearing(double bearing1, double bearing2, double weight) {
    // Handle bearing wraparound (0° = 360°)
    double diff = bearing2 - bearing1;
    
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }
    
    double result = bearing1 + (diff * weight);
    
    // Normalize to 0-360 range
    if (result < 0) {
      result += 360;
    } else if (result >= 360) {
      result -= 360;
    }
    
    return result;
  }

  /// Calculate route progress (0.0 to 1.0)
  double _calculateRouteProgress(int currentIndex) {
    if (_currentRoutePoints == null || _currentRoutePoints!.isEmpty) {
      return 0.0;
    }
    return currentIndex / _currentRoutePoints!.length;
  }

  /// Build cumulative distances from route start to each point index (meters).
  List<double>? _buildCumulativeDistances(List<PointLatLng> points) {
    if (points.isEmpty) return null;
    final cumul = <double>[0.0];
    for (int i = 1; i < points.length; i++) {
      cumul.add(cumul.last + _calculateDistance(points[i - 1], points[i]));
    }
    return cumul;
  }

  /// Find the route point index nearest to [point] (for mapping maneuver to route).
  int? _findNearestRouteIndex(PointLatLng point) {
    if (_currentRoutePoints == null || _currentRoutePoints!.isEmpty) {
      return null;
    }
    double minDist = double.infinity;
    int best = 0;
    for (int i = 0; i < _currentRoutePoints!.length; i++) {
      final d = _calculateDistance(_currentRoutePoints![i], point);
      if (d < minDist) {
        minDist = d;
        best = i;
      }
    }
    return best;
  }

  /// Decode route polyline to points
  List<PointLatLng> _decodeRoutePolyline(DirectionsRoute route) {
    final points = <PointLatLng>[];
    final polylinePoints = PolylinePoints();

    for (final leg in route.legs) {
      for (final step in leg.steps) {
        final decoded = polylinePoints.decodePolyline(step.polyline.points);
        points.addAll(decoded);
      }
    }

    return points;
  }

  /// Decode Mapbox route geometry to points
  List<PointLatLng> _decodeMapboxRouteGeometry(MapboxRoute route) {
    final points = <PointLatLng>[];

    for (final coordinate in route.geometry.coordinates) {
      if (coordinate.length >= 2) {
        // Mapbox geometry format: [lng, lat]
        points.add(PointLatLng(coordinate[1], coordinate[0]));
      }
    }

    return points;
  }

  /// Snap a chunk of points to roads using Google Roads API
  Future<List<PointLatLng>> _snapChunkToRoads(
    List<PointLatLng> points,
    String apiKey,
  ) async {
    // This would typically make an HTTP request to Google Roads API
    // For now, return the original points
    // You can implement the actual API call here
    return points;
  }

  /// Detect GPS jumps that might indicate connectivity issues
  bool _detectGpsJump(geo.Position currentPosition) {
    final now = DateTime.now();
    
    if (_lastGpsPosition == null || _lastGpsTime == null) {
      return false; // First position, no jump possible
    }

    // Check time gap - long gaps might indicate connectivity issues
    final timeDiff = now.difference(_lastGpsTime!);
    if (timeDiff > _gpsTimeThreshold) {
      debugPrint('🕐 GPS time gap detected: ${timeDiff.inSeconds}s');
      return true;
    }

    // Check distance jump - sudden large movements might be GPS errors
    final distance = geo.Geolocator.distanceBetween(
      _lastGpsPosition!.latitude,
      _lastGpsPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    // Calculate expected maximum distance based on time and reasonable speed
    final maxReasonableSpeed = 150.0; // km/h - very generous upper limit
    final timeInHours = timeDiff.inMilliseconds / (1000 * 60 * 60);
    final maxExpectedDistance = maxReasonableSpeed * 1000 * timeInHours; // meters

    // Improved threshold: detect jumps more aggressively (1.5x instead of 2x)
    if (distance > _gpsJumpThreshold && distance > maxExpectedDistance * 1.5) {
      debugPrint('📍 GPS jump detected: ${distance.toStringAsFixed(1)}m in ${timeDiff.inSeconds}s');
      return true;
    }

    return false;
  }

  /// Update position history for GPS jump detection
  void _updatePositionHistory(geo.Position position) {
    _lastGpsPosition = position;
    _lastGpsTime = DateTime.now();
  }

  /// Clear GPS history when route changes
  void _clearGpsHistory() {
    _lastGpsPosition = null;
    _lastGpsTime = null;
  }

  /// Add GPS position to trace buffer for Map Matching
  void _addToGpsTraceBuffer(geo.Position position) {
    _gpsTraceBuffer.add(position);
    
    // Keep buffer size limited to prevent excessive API usage
    if (_gpsTraceBuffer.length > _maxTraceBufferSize) {
      _gpsTraceBuffer.removeAt(0);
    }
  }

  /// Determine if Map Matching should be triggered
  bool _shouldTriggerMapMatching(double distanceFromRoute, geo.Position gpsPosition) {
    // Don't use Map Matching if places service is not available
    if (_placesService == null) return false;

    // Don't trigger if we called Map Matching recently (cooldown)
    final now = DateTime.now();
    if (_lastMapMatchingCall != null && 
        now.difference(_lastMapMatchingCall!) < _mapMatchingCooldown) {
      return false;
    }

    // Don't trigger if GPS trace buffer is too small
    if (_gpsTraceBuffer.length < 3) return false;

    // Trigger Map Matching in these edge cases:
    return distanceFromRoute > _mapMatchingThreshold || // Very far from route
           _detectPotentialTunnelOrUrbanCanyon() ||      // GPS quality issues
           _consecutiveOffRouteUpdates > 5;              // Persistent off-route
  }

  /// Try Map Matching with current GPS trace buffer
  Future<LatLng?> _tryMapMatching(geo.Position currentPosition) async {
    if (_placesService == null || _gpsTraceBuffer.isEmpty) return null;

    try {
      // Convert GPS trace buffer to MapMatchingCoordinates
      final coordinates = _gpsTraceBuffer.map((pos) => 
        MapMatchingCoordinate(
          lat: pos.latitude,
          lng: pos.longitude,
          timestamp: pos.timestamp,
        )
      ).toList();

      // Call Map Matching API with minimal coordinates to reduce cost
      final matchedCoordinates = await _placesService!.mapMatchGpsTrace(
        coordinates: coordinates.take(5).toList(), // Limit to 5 points max
        radiuses: List.filled(coordinates.length, 50.0), // 50m search radius
      );

      if (matchedCoordinates.isNotEmpty) {
        _lastMapMatchingCall = DateTime.now();
        
        // Return the most relevant matched coordinate (usually the last one)
        return matchedCoordinates.last;
      }
    } catch (e) {
      debugPrint('Map Matching failed: $e');
    }
    
    return null;
  }

  /// Detect potential GPS quality issues (tunnels, urban canyons)
  bool _detectPotentialTunnelOrUrbanCanyon() {
    if (_gpsTraceBuffer.length < 3) return false;

    // Check for erratic GPS behavior patterns
    double totalAccuracy = 0;
    int lowAccuracyCount = 0;
    
    final recentPositions = _gpsTraceBuffer.length > 5 
        ? _gpsTraceBuffer.sublist(_gpsTraceBuffer.length - 5)
        : _gpsTraceBuffer;
    
    for (final position in recentPositions) {
      totalAccuracy += position.accuracy;
      if (position.accuracy > 20.0) { // Poor accuracy
        lowAccuracyCount++;
      }
    }

    final avgAccuracy = totalAccuracy / recentPositions.length;
    
    // Trigger if average accuracy is poor or many low accuracy readings
    return avgAccuracy > 25.0 || lowAccuracyCount >= 3;
  }

  /// Clear Map Matching buffer
  void _clearMapMatchingBuffer() {
    _gpsTraceBuffer.clear();
    _lastMapMatchingCall = null;
  }
}

/// Result of snap-to-road operation
class SnapToRoadResult {
  final PointLatLng snappedPosition;
  final bool isOnRoute;
  final double distanceFromRoute;
  final double routeProgress;
  final double bearing;
  final bool isOffRoute;
  final bool needsReroute;
  final int routeIndex;
  /// Distance traveled along route from start to projected point (meters). Present when route has geometry.
  final double? distanceTraveledAlongRouteMeters;
  /// Distance along route from projected point to current step's maneuver (meters). Negative if passed. Present when leg/step indices provided.
  final double? distanceToCurrentStepManeuverAlongRouteMeters;
  /// Remaining distance along route to destination (meters). Present when route length is known.
  final double? remainingDistanceAlongRouteMeters;

  SnapToRoadResult({
    required this.snappedPosition,
    required this.isOnRoute,
    required this.distanceFromRoute,
    required this.routeProgress,
    required this.bearing,
    this.isOffRoute = false,
    this.needsReroute = false,
    this.routeIndex = 0,
    this.distanceTraveledAlongRouteMeters,
    this.distanceToCurrentStepManeuverAlongRouteMeters,
    this.remainingDistanceAlongRouteMeters,
  });
}

/// Internal class for nearest point result
class _NearestPointResult {
  final PointLatLng point;
  final int index;
  final double distance;

  _NearestPointResult(this.point, this.index, this.distance);
}

/// Internal class for segment calculation result
class _SegmentResult {
  final PointLatLng point;
  final double distance;

  _SegmentResult(this.point, this.distance);
}
