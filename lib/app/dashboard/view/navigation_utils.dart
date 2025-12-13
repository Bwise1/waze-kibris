// Updated navigation_utils.dart - Waze-style camera constants

// navigation_utils.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';
import 'dart:math' as math;

class NavigationUtils {
  // Distance thresholds for navigation logic
  static const double stepAdvanceThreshold = 20.0; // meters
  static const double reroueThreshold = 100.0; // meters
  static const double destinationReachedThreshold = 30.0; // meters

  // Waze-style camera settings - ALL 2D, NO 3D
  static const double navigationZoom = 18.0; // Close zoom during navigation
  static const double overviewZoom = 14.0; // Wider view for route overview
  static const double normalModeZoom = 16.0; // Standard zoom for browsing
  static const double navigationPitch = 0.0; // Always flat like Waze
  static const double overviewPitch = 0.0; // Always flat
  static const double navigationBearing = 0.0; // Will be set to user's heading

  // Animation durations
  static const Duration cameraAnimationDuration = Duration(milliseconds: 800);
  static const Duration maneuverTransitionDuration =
      Duration(milliseconds: 300);
  static const Duration uiAnimationDuration = Duration(milliseconds: 200);

  /// Calculate bearing between two points
  static double calculateBearing(
      double lat1, double lon1, double lat2, double lon2) {
    double dLon = (lon2 - lon1) * math.pi / 180.0;
    double lat1Rad = lat1 * math.pi / 180.0;
    double lat2Rad = lat2 * math.pi / 180.0;

    double y = math.sin(dLon) * math.cos(lat2Rad);
    double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    double bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360.0) % 360.0;
  }

  /// Format distance for display (Waze-style)
  static String formatDistance(int distanceMeters) {
    if (distanceMeters < 1000) {
      // Round to nearest 10m for distances under 1km (like Waze)
      if (distanceMeters < 100) {
        return '${(distanceMeters / 10).round() * 10}m';
      }
      return '${distanceMeters}m';
    } else {
      final km = distanceMeters / 1000;
      if (km < 10) {
        return '${km.toStringAsFixed(1)}km';
      } else {
        return '${km.round()}km';
      }
    }
  }

  /// Format duration for display (Waze-style)
  static String formatDuration(int durationSeconds) {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '< 1m';
    }
  }

  /// Format ETA time (Waze-style 12-hour format)
  static String formatETA(int durationSeconds) {
    final now = DateTime.now();
    final eta = now.add(Duration(seconds: durationSeconds));
    final hour = eta.hour;
    final minute = eta.minute;

    // Convert to 12-hour format like Waze
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Get maneuver icon based on instruction (Waze-style icons)
  static IconData getManeuverIcon(String htmlInstruction) {
    final instruction = htmlInstruction.toLowerCase();

    if (instruction.contains('turn right') ||
        instruction.contains('right turn')) {
      return Icons.turn_right;
    } else if (instruction.contains('turn left') ||
        instruction.contains('left turn')) {
      return Icons.turn_left;
    } else if (instruction.contains('slight right')) {
      return Icons.turn_slight_right;
    } else if (instruction.contains('slight left')) {
      return Icons.turn_slight_left;
    } else if (instruction.contains('sharp right')) {
      return Icons.turn_sharp_right;
    } else if (instruction.contains('sharp left')) {
      return Icons.turn_sharp_left;
    } else if (instruction.contains('straight') ||
        instruction.contains('continue')) {
      return Icons.straight;
    } else if (instruction.contains('merge')) {
      return Icons.merge;
    } else if (instruction.contains('roundabout')) {
      return Icons.roundabout_right;
    } else if (instruction.contains('exit')) {
      return Icons.exit_to_app;
    } else if (instruction.contains('uturn') ||
        instruction.contains('u-turn')) {
      return Icons.u_turn_right;
    } else if (instruction.contains('ferry')) {
      return Icons.directions_boat;
    } else if (instruction.contains('fork')) {
      return Icons.call_split;
    } else {
      return Icons.navigation;
    }
  }

  /// Get maneuver color based on instruction (using project theme colors)
  static Color getManeuverColor(String htmlInstruction) {
    final instruction = htmlInstruction.toLowerCase();

    if (instruction.contains('turn')) {
      return const Color(0xFFFF0000); // Project primary red
    } else if (instruction.contains('straight') ||
        instruction.contains('continue')) {
      return const Color(0xff00CF00); // Project green
    } else if (instruction.contains('roundabout')) {
      return const Color(0xffFFC300); // Project yellow
    } else if (instruction.contains('merge')) {
      return const Color(0xffF05A5A); // Project red variant
    } else if (instruction.contains('exit')) {
      return const Color(0xFFFF0000); // Project primary red
    } else {
      return const Color(0xFFFF0000); // Default to project primary red
    }
  }

  /// Clean HTML instruction text
  static String cleanInstruction(String htmlInstruction) {
    String instruction = htmlInstruction;
    instruction =
        instruction.replaceAll(RegExp(r'<[^>]*>'), ''); // Remove HTML tags
    instruction =
        instruction.replaceAll('&nbsp;', ' '); // Replace HTML entities
    instruction = instruction.replaceAll('&amp;', '&');
    instruction = instruction.replaceAll('&lt;', '<');
    instruction = instruction.replaceAll('&gt;', '>');
    instruction = instruction.replaceAll('&quot;', '"');
    return instruction.trim();
  }

  /// Extract road name from instruction
  static String? extractRoadName(String htmlInstruction) {
    // Try to extract road name from common patterns
    final patterns = [
      RegExp(r'onto\s+(.+?)(?:\s|$)', caseSensitive: false),
      RegExp(r'on\s+(.+?)(?:\s|$)', caseSensitive: false),
      RegExp(r'toward\s+(.+?)(?:\s|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(htmlInstruction);
      if (match != null) {
        return cleanInstruction(match.group(1) ?? '');
      }
    }

    return null;
  }

  /// Calculate remaining distance from current position
  static double calculateRemainingDistance(
    Position currentPosition,
    DirectionsStep currentStep,
    List<DirectionsStep> allSteps,
    int currentStepIndex,
  ) {
    // Distance to current step end
    double totalDistance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      currentStep.endLoc.lat,
      currentStep.endLoc.lng,
    );

    // Add remaining steps
    for (int i = currentStepIndex + 1; i < allSteps.length; i++) {
      totalDistance += allSteps[i].distance.value;
    }

    return totalDistance;
  }

  /// Calculate estimated remaining time (Waze-style realistic estimation)
  static int calculateRemainingTime(
    double remainingDistanceMeters,
    double currentSpeedMps,
    List<DirectionsStep> remainingSteps,
  ) {
    // Always use route duration for initial calculation to avoid unrealistic times
    // Only use current speed if it's reasonable AND we're not just starting
    if (currentSpeedMps > 2.0 && currentSpeedMps < 50) {
      // Min 2 m/s (7.2 km/h) to avoid walking/stationary speeds
      final timeBasedOnSpeed = remainingDistanceMeters / currentSpeedMps;
      
      // Get route-based duration for comparison
      int totalDuration = 0;
      for (final step in remainingSteps) {
        totalDuration += step.duration.value;
      }
      
      // Use the more realistic estimate (not too different from route calculation)
      final speedBasedTime = timeBasedOnSpeed.round();
      if ((speedBasedTime - totalDuration).abs() < totalDuration * 0.5) {
        return speedBasedTime;
      }
    }

    // Fallback to step durations (from route calculation)
    int totalDuration = 0;
    for (final step in remainingSteps) {
      totalDuration += step.duration.value;
    }

    return totalDuration;
  }

  /// Check if user is off route (Waze-style tolerance)
  static bool isOffRoute(Position currentPosition, DirectionsStep currentStep,
      {double threshold = 50.0} // Waze-like tolerance
      ) {
    // Calculate distance to the step's polyline (simplified)
    final distanceToStepStart = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      currentStep.startLoc.lat,
      currentStep.startLoc.lng,
    );

    final distanceToStepEnd = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      currentStep.endLoc.lat,
      currentStep.endLoc.lng,
    );

    // Simple check: if too far from both start and end points
    return distanceToStepStart > threshold && distanceToStepEnd > threshold;
  }

  /// Generate voice instruction text (Waze-style announcements)
  static String generateVoiceInstruction(
    DirectionsStep step,
    int distanceToManeuver,
  ) {
    final instruction = cleanInstruction(step.htmlInstr);
    final roadName = extractRoadName(step.htmlInstr);

    String voiceText = '';

    // Waze-style distance announcements
    if (distanceToManeuver > 1000) {
      voiceText = 'In ${formatDistance(distanceToManeuver)}, $instruction';
    } else if (distanceToManeuver > 500) {
      voiceText = 'In half a kilometer, $instruction';
    } else if (distanceToManeuver > 100) {
      voiceText = 'In ${distanceToManeuver} meters, $instruction';
    } else if (distanceToManeuver > 50) {
      voiceText = 'In ${distanceToManeuver} meters, $instruction';
    } else {
      voiceText = instruction; // Immediate instruction
    }

    if (roadName != null && roadName.isNotEmpty) {
      voiceText += ' onto $roadName';
    }

    return voiceText;
  }

  /// Check if should announce maneuver (Waze-style timing)
  static bool shouldAnnounceManeuver(
    int distanceToManeuver,
    String stepId,
    Set<String> announcedSteps,
  ) {
    // Waze-style announcement distances
    final announceDistances = [1000, 500, 200, 100, 50];

    for (final distance in announceDistances) {
      if (distanceToManeuver <= distance &&
          distanceToManeuver > distance - 15 && // 15m tolerance
          !announcedSteps.contains('${stepId}_$distance')) {
        return true;
      }
    }

    return false;
  }

  /// Get step unique identifier
  static String getStepId(DirectionsStep step, int index) {
    return '${step.startLoc.lat}_${step.startLoc.lng}_$index';
  }
}

// Navigation constants (Waze-style)
class NavigationConstants {
  static const String navigationChannelName = 'waze_navigation';
  static const String voiceChannelName = 'waze_voice';

  // Notification constants
  static const String navigationNotificationChannelId = 'navigation_active';
  static const String navigationNotificationChannelName = 'Active Navigation';
  static const int navigationNotificationId = 1;

  // Preference keys
  static const String prefVoiceEnabled = 'voice_enabled';
  static const String prefVoiceLanguage = 'voice_language';
  static const String prefAvoidTolls = 'avoid_tolls';
  static const String prefAvoidHighways = 'avoid_highways';
  static const String prefAvoidFerries = 'avoid_ferries';

  // Default values (Waze-style defaults)
  static const bool defaultVoiceEnabled = true;
  static const String defaultVoiceLanguage = 'en';
  static const bool defaultAvoidTolls = false;
  static const bool defaultAvoidHighways = false;
  static const bool defaultAvoidFerries = false;

  // Waze-style map behavior
  static const double wazeNavigationZoom = 18.0;
  static const double wazeOverviewZoom = 14.0;
  static const Duration wazeAnimationDuration = Duration(milliseconds: 800);

  // Distance thresholds for navigation logic
  static const double stepAdvanceThreshold = 20.0; // meters
  static const double reroueThreshold = 100.0; // meters
  static const double destinationReachedThreshold = 30.0; // meters

  // Waze-style camera settings - ALL 2D, NO 3D
  static const double navigationZoom = 18.0; // Close zoom during navigation
  static const double overviewZoom = 14.0; // Wider view for route overview
  static const double normalModeZoom = 16.0; // Standard zoom for browsing
  static const double navigationPitch = 0.0; // Always flat like Waze
  static const double overviewPitch = 0.0; // Flat for route overview
  static const double normalPitch = 0.0; // Flat for normal browsing
  static const double navigationBearing = 0.0; // Will be set to user's heading

  // Animation durations
  static const Duration cameraAnimationDuration = Duration(milliseconds: 800);
  static const Duration maneuverTransitionDuration =
      Duration(milliseconds: 300);
  static const Duration uiAnimationDuration = Duration(milliseconds: 200);
}
