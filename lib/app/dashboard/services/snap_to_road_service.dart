import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';

class SnapToRoadService {
  static const double _snapDistanceThreshold = 50.0; // meters
  static const double _offRouteThreshold = 100.0; // meters
  static const double _smoothingFactor = 0.7; // for position smoothing
  
  // Cache for route points
  List<PointLatLng>? _currentRoutePoints;
  PointLatLng? _lastSnappedPoint;
  int _lastNearestIndex = 0;

  /// Initialize with current route
  void setRoute(DirectionsRoute route) {
    _currentRoutePoints = _decodeRoutePolyline(route);
    _lastNearestIndex = 0;
    _lastSnappedPoint = null;
  }

  /// Clear route data
  void clearRoute() {
    _currentRoutePoints = null;
    _lastSnappedPoint = null;
    _lastNearestIndex = 0;
  }

  /// Snap GPS position to nearest point on route
  SnapToRoadResult snapToRoad(Position gpsPosition) {
    if (_currentRoutePoints == null || _currentRoutePoints!.isEmpty) {
      return SnapToRoadResult(
        snappedPosition: PointLatLng(gpsPosition.latitude, gpsPosition.longitude),
        isOnRoute: false,
        distanceFromRoute: 0,
        routeProgress: 0,
        bearing: gpsPosition.heading,
      );
    }

    final gpsPoint = PointLatLng(gpsPosition.latitude, gpsPosition.longitude);
    
    // Find nearest point on route
    final nearestResult = _findNearestPointOnRoute(gpsPoint);
    
    // Determine if user is on route
    final isOnRoute = nearestResult.distance <= _snapDistanceThreshold;
    final isOffRoute = nearestResult.distance > _offRouteThreshold;

    PointLatLng snappedPoint;
    double bearing = gpsPosition.heading;

    if (isOnRoute) {
      // Snap to route with smoothing
      snappedPoint = _smoothSnapPosition(nearestResult.point, gpsPoint);
      bearing = _calculateRouteBearing(nearestResult.index);
      _lastSnappedPoint = snappedPoint;
      _lastNearestIndex = nearestResult.index;
    } else if (isOffRoute) {
      // User is off route - use GPS position
      snappedPoint = gpsPoint;
    } else {
      // User is close to route - blend GPS and snapped position
      snappedPoint = _blendPositions(gpsPoint, nearestResult.point, 0.3);
      bearing = _calculateRouteBearing(nearestResult.index);
    }

    return SnapToRoadResult(
      snappedPosition: snappedPoint,
      isOnRoute: isOnRoute,
      distanceFromRoute: nearestResult.distance,
      routeProgress: _calculateRouteProgress(nearestResult.index),
      bearing: bearing,
      isOffRoute: isOffRoute,
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

    // Start search from last known position for efficiency
    final startIndex = math.max(0, _lastNearestIndex - 10);
    final endIndex = math.min(
      _currentRoutePoints!.length, 
      _lastNearestIndex + 50,
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
  PointLatLng _smoothSnapPosition(PointLatLng snappedPoint, PointLatLng gpsPoint) {
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
  PointLatLng _blendPositions(PointLatLng point1, PointLatLng point2, double weight) {
    final lat = point1.latitude * (1 - weight) + point2.latitude * weight;
    final lng = point1.longitude * (1 - weight) + point2.longitude * weight;
    return PointLatLng(lat, lng);
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
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculate route progress (0.0 to 1.0)
  double _calculateRouteProgress(int currentIndex) {
    if (_currentRoutePoints == null || _currentRoutePoints!.isEmpty) {
      return 0.0;
    }
    return currentIndex / _currentRoutePoints!.length;
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
}

/// Result of snap-to-road operation
class SnapToRoadResult {
  final PointLatLng snappedPosition;
  final bool isOnRoute;
  final double distanceFromRoute;
  final double routeProgress;
  final double bearing;
  final bool isOffRoute;

  SnapToRoadResult({
    required this.snappedPosition,
    required this.isOnRoute,
    required this.distanceFromRoute,
    required this.routeProgress,
    required this.bearing,
    this.isOffRoute = false,
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