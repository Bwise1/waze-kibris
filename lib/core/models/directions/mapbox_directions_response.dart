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
              ?.map((route) =>
                  MapboxRoute.fromJson(route as Map<String, dynamic>))
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
      geometry:
          MapboxLineString.fromJson(json['geometry'] as Map<String, dynamic>),
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
  final MapboxLegAnnotations? annotations; // Speed and other annotation data

  MapboxLeg({
    required this.steps,
    required this.summary,
    required this.weight,
    required this.duration,
    required this.distance,
    this.annotations,
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
      annotations: json['annotation'] != null
          ? MapboxLegAnnotations.fromJson(
              json['annotation'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'steps': steps.map((step) => step.toJson()).toList(),
      'summary': summary,
      'weight': weight,
      'duration': duration,
      'distance': distance,
      if (annotations != null) 'annotation': annotations!.toJson(),
    };
  }

  /// Get average speed from annotations (in m/s)
  double? get averageSpeed {
    if (annotations?.speed == null || annotations!.speed!.isEmpty) {
      return null;
    }
    final speeds = annotations!.speed!;
    final sum = speeds.reduce((a, b) => a + b);
    return sum / speeds.length;
  }

  /// Get average speed limit estimate (in km/h) - uses average speed as proxy
  /// Note: This is average speed, not actual speed limit, but better than hardcoded value
  double? get estimatedSpeedLimitKmh {
    final avgSpeed = averageSpeed;
    if (avgSpeed == null) return null;
    // Convert m/s to km/h and add 20% buffer as speed limit estimate
    return (avgSpeed * 3.6 * 1.2).roundToDouble();
  }

  /// Get expected average speed from route (in m/s) - alias for averageSpeed for clarity
  double? get expectedAverageSpeed => averageSpeed;
}

class MapboxLegAnnotations {
  final List<double>? speed; // Speed in m/s for each coordinate point
  final List<double>? distance; // Distance in meters
  final List<double>? duration; // Duration in seconds
  final List<double>?
      congestionNumeric; // Congestion level 0-100 for each coordinate pair (only available for driving-traffic profile)

  MapboxLegAnnotations({
    this.speed,
    this.distance,
    this.duration,
    this.congestionNumeric,
  });

  factory MapboxLegAnnotations.fromJson(Map<String, dynamic> json) {
    return MapboxLegAnnotations(
      speed: json['speed'] != null
          ? (json['speed'] as List<dynamic>)
              .map((s) => (s as num).toDouble())
              .toList()
          : null,
      distance: json['distance'] != null
          ? (json['distance'] as List<dynamic>)
              .map((d) => (d as num).toDouble())
              .toList()
          : null,
      duration: json['duration'] != null
          ? (json['duration'] as List<dynamic>)
              .map((d) => (d as num).toDouble())
              .toList()
          : null,
      congestionNumeric: json['congestion_numeric'] != null
          ? (json['congestion_numeric'] as List<dynamic>)
              .map((c) => (c as num).toDouble())
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (speed != null) 'speed': speed,
      if (distance != null) 'distance': distance,
      if (duration != null) 'duration': duration,
      if (congestionNumeric != null) 'congestion_numeric': congestionNumeric,
    };
  }

  /// Calculate average congestion for the leg (0-100 scale)
  double? get averageCongestion {
    if (congestionNumeric == null || congestionNumeric!.isEmpty) {
      return null;
    }
    final sum = congestionNumeric!.reduce((a, b) => a + b);
    return sum / congestionNumeric!.length;
  }

  /// Map congestion value (0-100) to time multiplier
  /// 0-30 (low) = 1.0x, 31-60 (moderate) = 1.2x, 61-80 (heavy) = 1.5x, 81-100 (severe) = 2.0x
  static double congestionToMultiplier(double congestionValue) {
    if (congestionValue <= 30) {
      return 1.0; // Low congestion
    } else if (congestionValue <= 60) {
      return 1.2; // Moderate congestion
    } else if (congestionValue <= 80) {
      return 1.5; // Heavy congestion
    } else {
      return 2.0; // Severe congestion
    }
  }

  /// Get congestion multiplier for a specific congestion value
  double getCongestionMultiplier(int index) {
    if (congestionNumeric == null ||
        index < 0 ||
        index >= congestionNumeric!.length) {
      return 1.0; // Default to no delay if no congestion data
    }
    return congestionToMultiplier(congestionNumeric![index]);
  }

  /// Get average congestion multiplier for remaining segments starting from index
  double getAverageCongestionMultiplier(int startIndex) {
    if (congestionNumeric == null ||
        startIndex < 0 ||
        startIndex >= congestionNumeric!.length) {
      return 1.0; // Default to no delay if no congestion data
    }

    final remainingCongestion = congestionNumeric!.sublist(startIndex);
    if (remainingCongestion.isEmpty) return 1.0;

    final sum = remainingCongestion.fold(
        0.0, (sum, value) => sum + congestionToMultiplier(value));
    return sum / remainingCongestion.length;
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
  final List<MapboxVoiceInstruction> voiceInstructions;
  final List<MapboxBannerInstruction> bannerInstructions;
  final String? ref; // Road reference/number
  final String? destinations; // Destination signage
  final String? exits; // Exit numbers
  final String? pronunciation;
  final String? rotaryName;
  final String? rotaryPronunciation;

  MapboxStep({
    required this.intersections,
    required this.geometry,
    required this.maneuver,
    required this.name,
    required this.duration,
    required this.distance,
    required this.mode,
    this.voiceInstructions = const [],
    this.bannerInstructions = const [],
    this.ref,
    this.destinations,
    this.exits,
    this.pronunciation,
    this.rotaryName,
    this.rotaryPronunciation,
  });

  factory MapboxStep.fromJson(Map<String, dynamic> json) {
    return MapboxStep(
      intersections: (json['intersections'] as List<dynamic>?)
              ?.map((intersection) => MapboxIntersection.fromJson(
                  intersection as Map<String, dynamic>))
              .toList() ??
          [],
      geometry:
          MapboxLineString.fromJson(json['geometry'] as Map<String, dynamic>),
      maneuver:
          MapboxManeuver.fromJson(json['maneuver'] as Map<String, dynamic>),
      name: json['name']?.toString() ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      mode: json['mode']?.toString() ?? '',
      voiceInstructions: (json['voice_instructions'] as List<dynamic>?)
              ?.map((vi) =>
                  MapboxVoiceInstruction.fromJson(vi as Map<String, dynamic>))
              .toList() ??
          [],
      bannerInstructions: (json['banner_instructions'] as List<dynamic>?)
              ?.map((bi) =>
                  MapboxBannerInstruction.fromJson(bi as Map<String, dynamic>))
              .toList() ??
          [],
      ref: json['ref']?.toString(),
      destinations: json['destinations']?.toString(),
      exits: json['exits']?.toString(),
      pronunciation: json['pronunciation']?.toString(),
      rotaryName: json['rotary_name']?.toString(),
      rotaryPronunciation: json['rotary_pronunciation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'intersections':
          intersections.map((intersection) => intersection.toJson()).toList(),
      'geometry': geometry.toJson(),
      'maneuver': maneuver.toJson(),
      'name': name,
      'duration': duration,
      'distance': distance,
      'mode': mode,
    };

    if (voiceInstructions.isNotEmpty) {
      json['voice_instructions'] =
          voiceInstructions.map((vi) => vi.toJson()).toList();
    }
    if (bannerInstructions.isNotEmpty) {
      json['banner_instructions'] =
          bannerInstructions.map((bi) => bi.toJson()).toList();
    }
    if (ref != null) json['ref'] = ref!;
    if (destinations != null) json['destinations'] = destinations!;
    if (exits != null) json['exits'] = exits!;
    if (pronunciation != null) json['pronunciation'] = pronunciation!;
    if (rotaryName != null) json['rotary_name'] = rotaryName!;
    if (rotaryPronunciation != null) {
      json['rotary_pronunciation'] = rotaryPronunciation!;
    }

    return json;
  }
}

class MapboxIntersection {
  final List<double> location; // [longitude, latitude]
  final List<int> bearings;
  final List<bool> entry;
  final int? inIndex; // Entry bearing index
  final int? outIndex; // Exit bearing index
  final List<MapboxLane> lanes; // Lane guidance information
  final List<String> classes; // Road classification

  MapboxIntersection({
    required this.location,
    required this.bearings,
    required this.entry,
    this.inIndex,
    this.outIndex,
    this.lanes = const [],
    this.classes = const [],
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
      entry:
          (json['entry'] as List<dynamic>?)?.map((e) => e as bool).toList() ??
              [],
      inIndex: (json['in'] as num?)?.toInt(),
      outIndex: (json['out'] as num?)?.toInt(),
      lanes: (json['lanes'] as List<dynamic>?)
              ?.map((lane) => MapboxLane.fromJson(lane as Map<String, dynamic>))
              .toList() ??
          [],
      classes: (json['classes'] as List<dynamic>?)
              ?.map((c) => c.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'location': location,
      'bearings': bearings,
      'entry': entry,
    };

    if (inIndex != null) json['in'] = inIndex!;
    if (outIndex != null) json['out'] = outIndex!;
    if (lanes.isNotEmpty) {
      json['lanes'] = lanes.map((lane) => lane.toJson()).toList();
    }
    if (classes.isNotEmpty) json['classes'] = classes;

    return json;
  }
}

class MapboxManeuver {
  final String type;
  final String instruction;
  final int bearingAfter;
  final int bearingBefore;
  final List<double> location; // [longitude, latitude]
  final String modifier;
  final int? exit; // Roundabout exit number
  final int? roundaboutExits; // Total exits in roundabout

  MapboxManeuver({
    required this.type,
    required this.instruction,
    required this.bearingAfter,
    required this.bearingBefore,
    required this.location,
    required this.modifier,
    this.exit,
    this.roundaboutExits,
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
      exit: (json['exit'] as num?)?.toInt(),
      roundaboutExits: (json['roundabout_exits'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'type': type,
      'instruction': instruction,
      'bearing_after': bearingAfter,
      'bearing_before': bearingBefore,
      'location': location,
      'modifier': modifier,
    };

    if (exit != null) json['exit'] = exit!;
    if (roundaboutExits != null) json['roundabout_exits'] = roundaboutExits!;

    return json;
  }
}

// Voice instruction for turn-by-turn navigation
class MapboxVoiceInstruction {
  final double distanceAlongGeometry; // Distance from start of step
  final String announcement; // Text to be spoken
  final String? ssmlAnnouncement; // SSML formatted text

  MapboxVoiceInstruction({
    required this.distanceAlongGeometry,
    required this.announcement,
    this.ssmlAnnouncement,
  });

  factory MapboxVoiceInstruction.fromJson(Map<String, dynamic> json) {
    return MapboxVoiceInstruction(
      distanceAlongGeometry:
          (json['distance_along_geometry'] as num?)?.toDouble() ?? 0.0,
      announcement: json['announcement']?.toString() ?? '',
      ssmlAnnouncement: json['ssml_announcement']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'distance_along_geometry': distanceAlongGeometry,
      'announcement': announcement,
    };
    if (ssmlAnnouncement != null) json['ssml_announcement'] = ssmlAnnouncement!;
    return json;
  }
}

// Banner instruction for visual guidance
class MapboxBannerInstruction {
  final double distanceAlongGeometry; // Distance from start of step
  final MapboxBannerContent primary; // Primary instruction text
  final MapboxBannerContent? secondary; // Secondary instruction text
  final MapboxBannerContent? sub; // Sub instruction text

  MapboxBannerInstruction({
    required this.distanceAlongGeometry,
    required this.primary,
    this.secondary,
    this.sub,
  });

  factory MapboxBannerInstruction.fromJson(Map<String, dynamic> json) {
    return MapboxBannerInstruction(
      distanceAlongGeometry:
          (json['distance_along_geometry'] as num?)?.toDouble() ?? 0.0,
      primary:
          MapboxBannerContent.fromJson(json['primary'] as Map<String, dynamic>),
      secondary: json['secondary'] != null
          ? MapboxBannerContent.fromJson(
              json['secondary'] as Map<String, dynamic>)
          : null,
      sub: json['sub'] != null
          ? MapboxBannerContent.fromJson(json['sub'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'distance_along_geometry': distanceAlongGeometry,
      'primary': primary.toJson(),
    };
    if (secondary != null) json['secondary'] = secondary!.toJson();
    if (sub != null) json['sub'] = sub!.toJson();
    return json;
  }
}

// Banner content with instruction text and components
class MapboxBannerContent {
  final String text; // Display text
  final List<MapboxBannerComponent> components; // Text components
  final String type; // Instruction type
  final String? modifier; // Direction modifier
  final double? degrees; // Turn angle
  final String? drivingSide; // left/right

  MapboxBannerContent({
    required this.text,
    required this.components,
    required this.type,
    this.modifier,
    this.degrees,
    this.drivingSide,
  });

  factory MapboxBannerContent.fromJson(Map<String, dynamic> json) {
    return MapboxBannerContent(
      text: json['text']?.toString() ?? '',
      components: (json['components'] as List<dynamic>?)
              ?.map((comp) =>
                  MapboxBannerComponent.fromJson(comp as Map<String, dynamic>))
              .toList() ??
          [],
      type: json['type']?.toString() ?? '',
      modifier: json['modifier']?.toString(),
      degrees: (json['degrees'] as num?)?.toDouble(),
      drivingSide: json['driving_side']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'text': text,
      'components': components.map((comp) => comp.toJson()).toList(),
      'type': type,
    };
    if (modifier != null) json['modifier'] = modifier!;
    if (degrees != null) json['degrees'] = degrees!;
    if (drivingSide != null) json['driving_side'] = drivingSide!;
    return json;
  }
}

// Component of banner instruction text
class MapboxBannerComponent {
  final String text;
  final String type; // "text", "icon", "delimiter", "exit-number", etc.
  final String? abbreviation;
  final int? abbreviationPriority;

  MapboxBannerComponent({
    required this.text,
    required this.type,
    this.abbreviation,
    this.abbreviationPriority,
  });

  factory MapboxBannerComponent.fromJson(Map<String, dynamic> json) {
    return MapboxBannerComponent(
      text: json['text']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      abbreviation: json['abbr']?.toString(),
      abbreviationPriority: (json['abbr_priority'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'text': text,
      'type': type,
    };
    if (abbreviation != null) json['abbr'] = abbreviation!;
    if (abbreviationPriority != null) {
      json['abbr_priority'] = abbreviationPriority!;
    }
    return json;
  }
}

// Lane guidance information
class MapboxLane {
  final bool valid; // Whether this lane can be used
  final bool active; // Whether this lane is recommended
  final List<String>
      indications; // Lane markings: "left", "straight", "right", etc.

  MapboxLane({
    required this.valid,
    required this.active,
    required this.indications,
  });

  factory MapboxLane.fromJson(Map<String, dynamic> json) {
    return MapboxLane(
      valid: json['valid'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      indications: (json['indications'] as List<dynamic>?)
              ?.map((ind) => ind.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'valid': valid,
      'active': active,
      'indications': indications,
    };
  }
}
