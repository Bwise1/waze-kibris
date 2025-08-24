import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';

/// Utilities for Mapbox Navigation following industry best practices
class MapboxNavigationUtils {
  static const Distance _distance = Distance();

  /// Format distance in user-friendly format
  static String formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      if (km >= 10) {
        return '${km.round()} km';
      } else {
        return '${km.toStringAsFixed(1)} km';
      }
    } else if (meters >= 100) {
      return '${(meters / 10).round() * 10} m';
    } else {
      return '${meters.round()} m';
    }
  }

  /// Format duration in user-friendly format
  static String formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Format ETA (Estimated Time of Arrival)
  static String formatETA(double seconds) {
    final now = DateTime.now();
    final eta = now.add(Duration(seconds: seconds.round()));
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  /// Clean and format navigation instructions
  static String cleanInstruction(String instruction) {
    // Remove HTML tags and clean up Mapbox instructions
    return instruction
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Extract road name from instruction or step name
  static String? extractRoadName(String? stepName) {
    if (stepName == null || stepName.isEmpty) return null;
    
    // For Mapbox, step.name already contains the road name
    return stepName.isNotEmpty ? stepName : null;
  }

  /// Classify route types based on Mapbox route properties
  static RouteType classifyRoute(MapboxRoute route) {
    // Mapbox doesn't explicitly categorize routes like "fastest" vs "shortest"
    // But we can infer based on duration vs distance ratios
    
    final avgSpeed = route.distance / route.duration; // m/s
    final avgSpeedKmh = avgSpeed * 3.6; // km/h
    
    if (avgSpeedKmh > 50) {
      return RouteType.fastest; // Highway/high-speed route
    } else if (avgSpeedKmh < 30) {
      return RouteType.scenic; // City/local roads
    } else {
      return RouteType.balanced; // Mixed route
    }
  }

  /// Get route summary for display
  static String getRouteSummary(MapboxRoute route) {
    final duration = formatDuration(route.duration);
    final distance = formatDistance(route.distance);
    final type = classifyRoute(route);
    
    String summary = '$duration ($distance)';
    
    switch (type) {
      case RouteType.fastest:
        summary += ' • via highways';
        break;
      case RouteType.scenic:
        summary += ' • city route';
        break;
      case RouteType.balanced:
        summary += ' • mixed route';
        break;
    }
    
    return summary;
  }

  /// Calculate bearing between two points
  static double calculateBearing(LatLng from, LatLng to) {
    return _distance.bearing(from, to);
  }

  /// Calculate distance between two points
  static double calculateDistanceMeters(LatLng from, LatLng to) {
    return _distance.distance(from, to);
  }

  /// Check if user is close enough to a waypoint
  static bool isUserNearPoint(LatLng userLocation, LatLng targetPoint, {double thresholdMeters = 20}) {
    final distance = calculateDistanceMeters(userLocation, targetPoint);
    return distance <= thresholdMeters;
  }

  /// Find closest point on route to user location
  static int findClosestPointIndex(LatLng userLocation, List<List<double>> routeCoordinates) {
    double minDistance = double.infinity;
    int closestIndex = 0;
    
    for (int i = 0; i < routeCoordinates.length; i++) {
      final routePoint = LatLng(routeCoordinates[i][1], routeCoordinates[i][0]); // [lng, lat] -> LatLng
      final distance = calculateDistanceMeters(userLocation, routePoint);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    return closestIndex;
  }

  /// Calculate remaining distance from current position
  static double calculateRemainingDistance(
    LatLng userLocation, 
    List<List<double>> routeCoordinates,
    int currentIndex,
  ) {
    if (currentIndex >= routeCoordinates.length - 1) return 0;
    
    double remainingDistance = 0;
    
    // Distance from current position to next route point
    final nextPoint = LatLng(routeCoordinates[currentIndex + 1][1], routeCoordinates[currentIndex + 1][0]);
    remainingDistance += calculateDistanceMeters(userLocation, nextPoint);
    
    // Distance for remaining route segments
    for (int i = currentIndex + 1; i < routeCoordinates.length - 1; i++) {
      final from = LatLng(routeCoordinates[i][1], routeCoordinates[i][0]);
      final to = LatLng(routeCoordinates[i + 1][1], routeCoordinates[i + 1][0]);
      remainingDistance += calculateDistanceMeters(from, to);
    }
    
    return remainingDistance;
  }

  /// Get turn instruction icon based on maneuver type
  static String getManeuverIcon(String maneuverType, String? modifier) {
    switch (maneuverType.toLowerCase()) {
      case 'depart':
        return '🚗';
      case 'arrive':
        return '🏁';
      case 'turn':
        switch (modifier?.toLowerCase()) {
          case 'left':
            return '↰';
          case 'right':
            return '↱';
          case 'sharp left':
            return '↰';
          case 'sharp right':
            return '↱';
          case 'slight left':
            return '↖';
          case 'slight right':
            return '↗';
          default:
            return '➡';
        }
      case 'merge':
        return '🔀';
      case 'on ramp':
        return '⤴';
      case 'off ramp':
        return '⤵';
      case 'fork':
        return '🔱';
      case 'roundabout':
        return '🔄';
      case 'continue':
      default:
        return '➡';
    }
  }

  /// Sort routes by preference (fastest first, then shortest)
  static List<MapboxRoute> sortRoutesByPreference(List<MapboxRoute> routes) {
    final sortedRoutes = List<MapboxRoute>.from(routes);
    
    // Sort by duration (fastest first), then by distance if duration is similar
    sortedRoutes.sort((a, b) {
      final durationDiff = a.duration.compareTo(b.duration);
      if (durationDiff.abs() < 300) { // If within 5 minutes, prefer shorter distance
        return a.distance.compareTo(b.distance);
      }
      return durationDiff;
    });
    
    return sortedRoutes;
  }
}

enum RouteType {
  fastest,   // Highway/high-speed route
  scenic,    // City/local roads  
  balanced,  // Mixed route
}

/// Route option data class
class RouteOption {
  final MapboxRoute route;
  final RouteType type;
  final String title;
  final String subtitle;
  final bool isRecommended;

  RouteOption({
    required this.route,
    required this.type,
    required this.title,
    required this.subtitle,
    this.isRecommended = false,
  });

  factory RouteOption.fromMapboxRoute(MapboxRoute route, {bool isRecommended = false}) {
    final type = MapboxNavigationUtils.classifyRoute(route);
    final duration = MapboxNavigationUtils.formatDuration(route.duration);
    final distance = MapboxNavigationUtils.formatDistance(route.distance);
    
    String title;
    String subtitle;
    
    switch (type) {
      case RouteType.fastest:
        title = 'Fastest Route';
        subtitle = '$duration • $distance via highways';
        break;
      case RouteType.scenic:
        title = 'City Route'; 
        subtitle = '$duration • $distance through city';
        break;
      case RouteType.balanced:
        title = 'Balanced Route';
        subtitle = '$duration • $distance mixed roads';
        break;
    }
    
    return RouteOption(
      route: route,
      type: type,
      title: title,
      subtitle: subtitle,
      isRecommended: isRecommended,
    );
  }
}