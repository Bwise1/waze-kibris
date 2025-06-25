import 'package:json_annotation/json_annotation.dart';

part 'google_directions_response.g.dart';

@JsonSerializable(explicitToJson: true)
class DirectionsResponse {
  final List<DirectionsRoute> routes;
  final String status;

  DirectionsResponse({required this.routes, required this.status});

  factory DirectionsResponse.fromJson(Map<String, dynamic> json) =>
      _$DirectionsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$DirectionsResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DirectionsRoute {
  final String summary;
  final List<DirectionsLeg> legs;
  @JsonKey(name: 'overview_polyline')
  final DirectionsPolyline overviewPolyline;

  DirectionsRoute({
    required this.summary,
    required this.legs,
    required this.overviewPolyline,
  });

  factory DirectionsRoute.fromJson(Map<String, dynamic> json) =>
      _$DirectionsRouteFromJson(json);
  Map<String, dynamic> toJson() => _$DirectionsRouteToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DirectionsLeg {
  final DirectionsTextValue distance;
  final DirectionsTextValue duration;
  @JsonKey(name: 'start_address')
  final String startAddress;
  @JsonKey(name: 'end_address')
  final String endAddress;
  @JsonKey(name: 'start_location')
  final DirectionsLatLng startLocation;
  @JsonKey(name: 'end_location')
  final DirectionsLatLng endLocation;
  final List<DirectionsStep> steps;

  DirectionsLeg({
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    required this.startLocation,
    required this.endLocation,
    required this.steps,
  });

  factory DirectionsLeg.fromJson(Map<String, dynamic> json) =>
      _$DirectionsLegFromJson(json);
  Map<String, dynamic> toJson() => _$DirectionsLegToJson(this);
}

@JsonSerializable()
class DirectionsStep {
  final DirectionsTextValue distance;
  final DirectionsTextValue duration;
  @JsonKey(name: 'html_instructions')
  final String htmlInstr;
  final DirectionsPolyline polyline;
  @JsonKey(name: 'start_location')
  final DirectionsLatLng startLoc;
  @JsonKey(name: 'end_location')
  final DirectionsLatLng endLoc;
  @JsonKey(name: 'travel_mode')
  final String travelMode;

  DirectionsStep({
    required this.distance,
    required this.duration,
    required this.htmlInstr,
    required this.polyline,
    required this.startLoc,
    required this.endLoc,
    required this.travelMode,
  });

  factory DirectionsStep.fromJson(Map<String, dynamic> json) =>
      _$DirectionsStepFromJson(json);
  Map<String, dynamic> toJson() => _$DirectionsStepToJson(this);
}

@JsonSerializable()
class DirectionsPolyline {
  final String points;

  DirectionsPolyline({required this.points});

  factory DirectionsPolyline.fromJson(Map<String, dynamic> json) =>
      _$DirectionsPolylineFromJson(json);
  Map<String, dynamic> toJson() => _$DirectionsPolylineToJson(this);
}

@JsonSerializable()
class DirectionsTextValue {
  final String text;
  final int value;

  DirectionsTextValue({required this.text, required this.value});

  factory DirectionsTextValue.fromJson(Map<String, dynamic> json) =>
      _$DirectionsTextValueFromJson(json);
  Map<String, dynamic> toJson() => _$DirectionsTextValueToJson(this);
}

@JsonSerializable()
class DirectionsLatLng {
  final double lat;
  final double lng;

  DirectionsLatLng({required this.lat, required this.lng});

  factory DirectionsLatLng.fromJson(Map<String, dynamic> json) =>
      _$DirectionsLatLngFromJson(json);
  Map<String, dynamic> toJson() => _$DirectionsLatLngToJson(this);
}
