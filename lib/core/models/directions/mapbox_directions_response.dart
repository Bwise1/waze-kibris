import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;

class MapboxDirectionsResponse {
  final List<MapboxRoute> routes;
  final String code;

  MapboxDirectionsResponse({
    required this.routes,
    required this.code,
  });

  factory MapboxDirectionsResponse.fromJson(Map<String, dynamic> json) {
    return MapboxDirectionsResponse(
      routes: (json['routes'] as List<dynamic>?)
              ?.map((route) => MapboxRoute.fromJson(route as Map<String, dynamic>))
              .toList() ??
          [],
      code: json['code']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routes': routes.map((route) => route.toJson()).toList(),
      'code': code,
    };
  }
}

class MapboxRoute {
  final MapboxLineString geometry;
  final List<MapboxLeg> legs;
  final String weightName;
  final double weight;
  final double duration; // in seconds
  final double distance; // in meters

  MapboxRoute({
    required this.geometry,
    required this.legs,
    required this.weightName,
    required this.weight,
    required this.duration,
    required this.distance,
  });

  factory MapboxRoute.fromJson(Map<String, dynamic> json) {
    return MapboxRoute(
      geometry: MapboxLineString.fromJson(json['geometry'] as Map<String, dynamic>),
      legs: (json['legs'] as List<dynamic>?)
              ?.map((leg) => MapboxLeg.fromJson(leg as Map<String, dynamic>))
              .toList() ??
          [],
      weightName: json['weight_name']?.toString() ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'geometry': geometry.toJson(),
      'legs': legs.map((leg) => leg.toJson()).toList(),
      'weight_name': weightName,
      'weight': weight,
      'duration': duration,
      'distance': distance,
    };
  }
}

class MapboxLineString {
  final String type;
  final List<List<double>> coordinates; // [longitude, latitude] pairs

  MapboxLineString({
    required this.type,
    required this.coordinates,
  });

  factory MapboxLineString.fromJson(Map<String, dynamic> json) {
    return MapboxLineString(
      type: json['type']?.toString() ?? 'LineString',
      coordinates: (json['coordinates'] as List<dynamic>?)
              ?.map((coord) => (coord as List<dynamic>)
                  .map((c) => (c as num).toDouble())
                  .toList())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }

  // Get coordinates as List<Position> for direct Mapbox usage
  List<Position> get mapboxPositions {
    return coordinates.map((coord) => Position(coord[0], coord[1])).toList();
  }
  
  // Get coordinates as List<LatLng> if needed for other calculations  
  List<LatLng> get latLngPoints {
    return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
  }
  
  // Convert to LineString for direct Mapbox Maps usage
  Map<String, dynamic> get geoJsonLineString {
    return {
      'type': 'LineString',
      'coordinates': coordinates,
    };
  }
}

class MapboxLeg {
  final List<MapboxStep> steps;
  final String summary;
  final double weight;
  final double duration; // in seconds
  final double distance; // in meters

  MapboxLeg({
    required this.steps,
    required this.summary,
    required this.weight,
    required this.duration,
    required this.distance,
  });

  factory MapboxLeg.fromJson(Map<String, dynamic> json) {
    return MapboxLeg(
      steps: (json['steps'] as List<dynamic>?)
              ?.map((step) => MapboxStep.fromJson(step as Map<String, dynamic>))
              .toList() ??
          [],
      summary: json['summary']?.toString() ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps.map((step) => step.toJson()).toList(),
      'summary': summary,
      'weight': weight,
      'duration': duration,
      'distance': distance,
    };
  }
}

class MapboxStep {
  final List<MapboxIntersection> intersections;
  final MapboxLineString geometry;
  final MapboxManeuver maneuver;
  final String name;
  final double duration; // in seconds
  final double distance; // in meters
  final String mode;

  MapboxStep({
    required this.intersections,
    required this.geometry,
    required this.maneuver,
    required this.name,
    required this.duration,
    required this.distance,
    required this.mode,
  });

  factory MapboxStep.fromJson(Map<String, dynamic> json) {
    return MapboxStep(
      intersections: (json['intersections'] as List<dynamic>?)
              ?.map((intersection) =>
                  MapboxIntersection.fromJson(intersection as Map<String, dynamic>))
              .toList() ??
          [],
      geometry: MapboxLineString.fromJson(json['geometry'] as Map<String, dynamic>),
      maneuver: MapboxManeuver.fromJson(json['maneuver'] as Map<String, dynamic>),
      name: json['name']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      mode: json['mode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intersections': intersections.map((intersection) => intersection.toJson()).toList(),
      'geometry': geometry.toJson(),
      'maneuver': maneuver.toJson(),
      'name': name,
      'duration': duration,
      'distance': distance,
      'mode': mode,
    };
  }
}

class MapboxIntersection {
  final List<double> location; // [longitude, latitude]
  final List<int> bearings;
  final List<bool> entry;

  MapboxIntersection({
    required this.location,
    required this.bearings,
    required this.entry,
  });

  factory MapboxIntersection.fromJson(Map<String, dynamic> json) {
    return MapboxIntersection(
      location: (json['location'] as List<dynamic>?)
              ?.map((loc) => (loc as num).toDouble())
              .toList() ??
          [],
      bearings: (json['bearings'] as List<dynamic>?)
              ?.map((bearing) => (bearing as num).toInt())
              .toList() ??
          [],
      entry: (json['entry'] as List<dynamic>?)
              ?.map((e) => e as bool)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'bearings': bearings,
      'entry': entry,
    };
  }
}

class MapboxManeuver {
  final String type;
  final String instruction;
  final int bearingAfter;
  final int bearingBefore;
  final List<double> location; // [longitude, latitude]
  final String modifier;

  MapboxManeuver({
    required this.type,
    required this.instruction,
    required this.bearingAfter,
    required this.bearingBefore,
    required this.location,
    required this.modifier,
  });

  factory MapboxManeuver.fromJson(Map<String, dynamic> json) {
    return MapboxManeuver(
      type: json['type']?.toString() ?? '',
      instruction: json['instruction']?.toString() ?? '',
      bearingAfter: (json['bearing_after'] as num?)?.toInt() ?? 0,
      bearingBefore: (json['bearing_before'] as num?)?.toInt() ?? 0,
      location: (json['location'] as List<dynamic>?)
              ?.map((loc) => (loc as num).toDouble())
              .toList() ??
          [],
      modifier: json['modifier']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'instruction': instruction,
      'bearing_after': bearingAfter,
      'bearing_before': bearingBefore,
      'location': location,
      'modifier': modifier,
    };
  }
}