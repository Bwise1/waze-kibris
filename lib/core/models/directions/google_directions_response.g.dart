// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'google_directions_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DirectionsResponse _$DirectionsResponseFromJson(Map<String, dynamic> json) =>
    DirectionsResponse(
      routes: (json['routes'] as List<dynamic>)
          .map((e) => DirectionsRoute.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String,
    );

Map<String, dynamic> _$DirectionsResponseToJson(DirectionsResponse instance) =>
    <String, dynamic>{
      'routes': instance.routes.map((e) => e.toJson()).toList(),
      'status': instance.status,
    };

DirectionsRoute _$DirectionsRouteFromJson(Map<String, dynamic> json) =>
    DirectionsRoute(
      summary: json['summary'] as String,
      legs: (json['legs'] as List<dynamic>)
          .map((e) => DirectionsLeg.fromJson(e as Map<String, dynamic>))
          .toList(),
      overviewPolyline: DirectionsPolyline.fromJson(
          json['overview_polyline'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DirectionsRouteToJson(DirectionsRoute instance) =>
    <String, dynamic>{
      'summary': instance.summary,
      'legs': instance.legs.map((e) => e.toJson()).toList(),
      'overview_polyline': instance.overviewPolyline.toJson(),
    };

DirectionsLeg _$DirectionsLegFromJson(Map<String, dynamic> json) =>
    DirectionsLeg(
      distance: DirectionsTextValue.fromJson(
          json['distance'] as Map<String, dynamic>),
      duration: DirectionsTextValue.fromJson(
          json['duration'] as Map<String, dynamic>),
      startAddress: json['start_address'] as String,
      endAddress: json['end_address'] as String,
      startLocation: DirectionsLatLng.fromJson(
          json['start_location'] as Map<String, dynamic>),
      endLocation: DirectionsLatLng.fromJson(
          json['end_location'] as Map<String, dynamic>),
      steps: (json['steps'] as List<dynamic>)
          .map((e) => DirectionsStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DirectionsLegToJson(DirectionsLeg instance) =>
    <String, dynamic>{
      'distance': instance.distance.toJson(),
      'duration': instance.duration.toJson(),
      'start_address': instance.startAddress,
      'end_address': instance.endAddress,
      'start_location': instance.startLocation.toJson(),
      'end_location': instance.endLocation.toJson(),
      'steps': instance.steps.map((e) => e.toJson()).toList(),
    };

DirectionsStep _$DirectionsStepFromJson(Map<String, dynamic> json) =>
    DirectionsStep(
      distance: DirectionsTextValue.fromJson(
          json['distance'] as Map<String, dynamic>),
      duration: DirectionsTextValue.fromJson(
          json['duration'] as Map<String, dynamic>),
      htmlInstr: json['html_instructions'] as String,
      polyline:
          DirectionsPolyline.fromJson(json['polyline'] as Map<String, dynamic>),
      startLoc: DirectionsLatLng.fromJson(
          json['start_location'] as Map<String, dynamic>),
      endLoc: DirectionsLatLng.fromJson(
          json['end_location'] as Map<String, dynamic>),
      travelMode: json['travel_mode'] as String,
    );

Map<String, dynamic> _$DirectionsStepToJson(DirectionsStep instance) =>
    <String, dynamic>{
      'distance': instance.distance,
      'duration': instance.duration,
      'html_instructions': instance.htmlInstr,
      'polyline': instance.polyline,
      'start_location': instance.startLoc,
      'end_location': instance.endLoc,
      'travel_mode': instance.travelMode,
    };

DirectionsPolyline _$DirectionsPolylineFromJson(Map<String, dynamic> json) =>
    DirectionsPolyline(
      points: json['points'] as String,
    );

Map<String, dynamic> _$DirectionsPolylineToJson(DirectionsPolyline instance) =>
    <String, dynamic>{
      'points': instance.points,
    };

DirectionsTextValue _$DirectionsTextValueFromJson(Map<String, dynamic> json) =>
    DirectionsTextValue(
      text: json['text'] as String,
      value: (json['value'] as num).toInt(),
    );

Map<String, dynamic> _$DirectionsTextValueToJson(
        DirectionsTextValue instance) =>
    <String, dynamic>{
      'text': instance.text,
      'value': instance.value,
    };

DirectionsLatLng _$DirectionsLatLngFromJson(Map<String, dynamic> json) =>
    DirectionsLatLng(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );

Map<String, dynamic> _$DirectionsLatLngToJson(DirectionsLatLng instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
    };
