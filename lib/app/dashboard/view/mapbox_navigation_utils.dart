import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/services/nav_settings.dart';

/// Utilities for Mapbox Navigation following industry best practices
class MapboxNavigationUtils {
  static const Distance _distance = Distance();

  /// Format distance using the native SDK's rounding bands
  /// (MapboxDistanceUtil.kt / DistanceFormatter.swift). Metric:
  ///   < 25 m  → steps of 5 (floor-clamped to 5 — never shows "0 m")
  ///   < 100 m → steps of 25
  ///   < 1 km  → steps of 50
  ///   < 3 km  → km with 1 decimal
  ///   ≥ 3 km  → whole km
  /// Imperial mirrors it in feet/miles (the native SDKs' UnitType.IMPERIAL).
  /// Exact readouts ("87 m") churn every second and read as noise; banded
  /// values are stable and glanceable while driving.
  static String formatDistance(double meters) {
    if (meters < 0 || meters.isNaN) return '';
    if (NavSettings.units.value == DistanceUnit.imperial) {
      return _formatDistanceImperial(meters);
    }
    if (meters < 25) {
      final v = ((meters / 5).round() * 5).clamp(5, 25);
      return '$v m';
    } else if (meters < 100) {
      final v = ((meters / 25).round() * 25).clamp(25, 100);
      return '$v m';
    } else if (meters < 1000) {
      final v = ((meters / 50).round() * 50).clamp(50, 1000);
      return '$v m';
    } else if (meters < 3000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${(meters / 1000).round()} km';
    }
  }

  static const double _feetPerMeter = 3.28084;
  static const double _metersPerMile = 1609.344;

  static String _formatDistanceImperial(double meters) {
    final feet = meters * _feetPerMeter;
    // Switch to miles at ~0.1 mi, matching the native imperial formatter.
    if (feet < 100) {
      final v = ((feet / 10).round() * 10).clamp(10, 100);
      return '$v ft';
    } else if (feet < 500) {
      final v = ((feet / 50).round() * 50).clamp(100, 500);
      return '$v ft';
    } else if (meters < _metersPerMile * 0.2) {
      final v = ((feet / 100).round() * 100).clamp(500, 1100);
      return '$v ft';
    } else if (meters < _metersPerMile * 3) {
      return '${(meters / _metersPerMile).toStringAsFixed(1)} mi';
    } else {
      return '${(meters / _metersPerMile).round()} mi';
    }
  }

  /// Format duration in user-friendly format
  static String formatDuration(double seconds) {
    // Normalize negatives / already-arrived cases
    if (seconds <= 0) return '0m';

    // For anything under 1 minute, show at least "1m"
    // This avoids ever displaying "0m" while there is still remaining time.
    if (seconds < 60) return '1m';

    // Round up to the next full minute
    final totalMinutes = (seconds / 60).ceil();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${totalMinutes}m';
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
  static bool isUserNearPoint(LatLng userLocation, LatLng targetPoint,
      {double thresholdMeters = 20}) {
    final distance = calculateDistanceMeters(userLocation, targetPoint);
    return distance <= thresholdMeters;
  }

  /// Find closest point on route to user location
  static int findClosestPointIndex(
      LatLng userLocation, List<List<double>> routeCoordinates) {
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < routeCoordinates.length; i++) {
      final routePoint = LatLng(routeCoordinates[i][1],
          routeCoordinates[i][0]); // [lng, lat] -> LatLng
      final distance = calculateDistanceMeters(userLocation, routePoint);

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  /// Calculate remaining distance from current position along route geometry
  static double calculateRemainingDistanceFromGeometry(
    LatLng userLocation,
    List<List<double>> routeCoordinates,
    int currentIndex,
  ) {
    if (currentIndex >= routeCoordinates.length - 1) return 0;

    double remainingDistance = 0;

    // Distance from current position to next route point
    final nextPoint = LatLng(routeCoordinates[currentIndex + 1][1],
        routeCoordinates[currentIndex + 1][0]);
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
      if (durationDiff.abs() < 300) {
        // If within 5 minutes, prefer shorter distance
        return a.distance.compareTo(b.distance);
      }
      return durationDiff;
    });

    return sortedRoutes;
  }

  // Navigation-specific constants and methods
  static const double stepAdvanceThreshold = 20.0; // meters
  static const double destinationReachedThreshold = 15.0; // meters
  static const double offRouteThreshold = 50.0; // meters

  /// Calculate remaining distance from position along route steps.
  /// When [remainingDistanceAlongRoute] is provided (e.g. from snap/route matching), returns it for native parity; otherwise uses straight-line for first segment.
  static double calculateRemainingDistance(
    Position position,
    MapboxStep currentStep,
    List<MapboxStep> allSteps,
    int currentStepIndex, {
    double? remainingDistanceAlongRoute,
  }) {
    if (remainingDistanceAlongRoute != null) {
      return remainingDistanceAlongRoute;
    }
    double remainingDistance = 0.0;
    // Fallback: straight-line to end of current step + remaining step distances
    remainingDistance += Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      currentStep.maneuver.location[1], // lat
      currentStep.maneuver.location[0], // lng
    );
    for (int i = currentStepIndex + 1; i < allSteps.length; i++) {
      remainingDistance += allSteps[i].distance;
    }
    return remainingDistance;
  }

  /// Calculate remaining time based on remaining distance and current speed
  /// Enhanced with congestion data and progress tracking
  static double calculateRemainingTime(
    double remainingDistance,
    double? currentSpeed,
    List<MapboxStep> remainingSteps, {
    List<double>? congestionNumericData,
    double? actualAverageSpeed,
    double? expectedAverageSpeed,
  }) {
    // Calculate base route time from step durations
    double routeBasedTime =
        remainingSteps.fold(0.0, (total, step) => total + step.duration);

    // Apply congestion multipliers if congestion data is available
    if (congestionNumericData != null && congestionNumericData.isNotEmpty) {
      // Map congestion values to multipliers and apply weighted average
      double congestionAdjustedTime = 0.0;

      // Calculate congestion-adjusted time for each step
      // Use average congestion multiplier for remaining route segments
      final avgCongestion = congestionNumericData.reduce((a, b) => a + b) /
          congestionNumericData.length;
      final congestionMultiplier =
          MapboxLegAnnotations.congestionToMultiplier(avgCongestion);

      // Apply congestion multiplier to each step's duration
      for (final step in remainingSteps) {
        congestionAdjustedTime += step.duration * congestionMultiplier;
      }

      // Blend congestion-adjusted time with base route time (80% congestion-adjusted, 20% base)
      routeBasedTime = (congestionAdjustedTime * 0.8) + (routeBasedTime * 0.2);
    }

    // Apply progress tracking adjustment if available
    double progressAdjustment = 1.0;
    if (actualAverageSpeed != null &&
        expectedAverageSpeed != null &&
        expectedAverageSpeed > 0) {
      // Calculate speed ratio: if user is slower than expected, increase time estimate
      final speedRatio = actualAverageSpeed / expectedAverageSpeed;
      // Apply adjustment: if speed ratio is 0.8 (20% slower), multiply time by 1.25
      progressAdjustment = speedRatio > 0 ? (1.0 / speedRatio) : 1.0;
      // Smooth the adjustment to prevent wild swings (use exponential moving average)
      // Limit adjustment to reasonable range (0.5x to 2.0x)
      progressAdjustment = progressAdjustment.clamp(0.5, 2.0);
    }

    routeBasedTime *= progressAdjustment;

    // Blend with current speed if reasonable
    if (currentSpeed != null && currentSpeed > 2.0 && currentSpeed < 50.0) {
      // 2-50 m/s (7-180 km/h)
      final speedBasedTime = remainingDistance / currentSpeed;
      // Blend route time (with congestion and progress adjustments) with speed time
      // Use 70% adjusted route time, 30% current speed for stability
      return (routeBasedTime * 0.7) + (speedBasedTime * 0.3);
    } else {
      // Use congestion and progress-adjusted route time
      return routeBasedTime;
    }
  }

  /// Check if user is off the designated route (straight-line to current step maneuver).
  /// For reroute decisions use snap result (needsRerouteFromSnap) as single source of truth.
  static bool isOffRoute(Position position, MapboxStep currentStep) {
    final distanceToManeuver = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      currentStep.maneuver.location[1], // lat
      currentStep.maneuver.location[0], // lng
    );

    return distanceToManeuver > offRouteThreshold;
  }
}

enum RouteType {
  fastest, // Highway/high-speed route
  scenic, // City/local roads
  balanced, // Mixed route
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

  factory RouteOption.fromMapboxRoute(MapboxRoute route,
      {bool isRecommended = false}) {
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
