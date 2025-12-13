// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_location_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SavedLocationResponse _$SavedLocationResponseFromJson(
        Map<String, dynamic> json) =>
    SavedLocationResponse(
      name: json['name'] as String,
      longitude: json['longitude'] as String,
      latitude: json['latitude'] as String,
    );

Map<String, dynamic> _$SavedLocationResponseToJson(
        SavedLocationResponse instance) =>
    <String, dynamic>{
      'name': instance.name,
      'longitude': instance.longitude,
      'latitude': instance.latitude,
    };
