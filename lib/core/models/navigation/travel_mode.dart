import 'package:flutter/material.dart';

/// How the user is travelling. Drives the Mapbox `profile` sent on Directions
/// requests, off-route thresholds, camera zoom, voice cadence, and which
/// driver-only UI (speed limit, lane guidance) is shown.
enum TravelMode {
  drive,
  walk,
  cycle;

  /// Mapbox Directions API `profile` value.
  String get mapboxProfile {
    switch (this) {
      case TravelMode.drive:
        return 'driving-traffic';
      case TravelMode.walk:
        return 'walking';
      case TravelMode.cycle:
        return 'cycling';
    }
  }

  /// Icon shown in the mode selector.
  IconData get icon {
    switch (this) {
      case TravelMode.drive:
        return Icons.directions_car;
      case TravelMode.walk:
        return Icons.directions_walk;
      case TravelMode.cycle:
        return Icons.directions_bike;
    }
  }

  String get label {
    switch (this) {
      case TravelMode.drive:
        return 'Drive';
      case TravelMode.walk:
        return 'Walk';
      case TravelMode.cycle:
        return 'Cycle';
    }
  }

  /// True when driver-only chrome (speed limit sign, lane guidance strip,
  /// congestion colouring, speeding TTS) is meaningful.
  bool get isVehicle => this == TravelMode.drive;

  /// Distance (meters) the user can drift from the route before we consider
  /// them off-route. Pedestrians cut through squares/parks; drivers can't.
  double get offRouteThresholdMeters {
    switch (this) {
      case TravelMode.drive:
        return 100;
      case TravelMode.cycle:
        return 60;
      case TravelMode.walk:
        return 40;
    }
  }

  /// Distance (meters) that triggers a reroute request.
  double get rerouteThresholdMeters {
    switch (this) {
      case TravelMode.drive:
        return 150;
      case TravelMode.cycle:
        return 90;
      case TravelMode.walk:
        return 60;
    }
  }

  /// Snap-to-road radius. Walking snaps loose so the puck doesn't jitter on
  /// footpaths that OSM tags imprecisely.
  double get snapDistanceThresholdMeters {
    switch (this) {
      case TravelMode.drive:
        return 50;
      case TravelMode.cycle:
        return 30;
      case TravelMode.walk:
        return 20;
    }
  }

  /// Camera zoom during active guidance. Walking is tighter because turn-by-
  /// turn happens at side-street scale.
  double get activeGuidanceZoom {
    switch (this) {
      case TravelMode.drive:
        return 17.0;
      case TravelMode.cycle:
        return 17.5;
      case TravelMode.walk:
        return 18.5;
    }
  }

  /// TTS speech rate. Walking gets slower/clearer speech since users have
  /// more time between maneuvers and often have earbuds in noisy streets.
  double get voiceSpeechRate {
    switch (this) {
      case TravelMode.drive:
        return 0.5;
      case TravelMode.cycle:
        return 0.45;
      case TravelMode.walk:
        return 0.4;
    }
  }
}
