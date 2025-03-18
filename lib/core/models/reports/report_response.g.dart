// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateReport _$CreateReportFromJson(Map<String, dynamic> json) => CreateReport(
      type: json['type'] as String,
      longitude: json['longitude'] as String,
      latitude: json['latitude'] as String,
    );

Map<String, dynamic> _$CreateReportToJson(CreateReport instance) =>
    <String, dynamic>{
      'type': instance.type,
      'longitude': instance.longitude,
      'latitude': instance.latitude,
    };

NearByReport _$NearByReportFromJson(Map<String, dynamic> json) => NearByReport(
      radius: json['radius'] as String,
      longitude: json['longitude'] as String,
      latitude: json['latitude'] as String,
    );

Map<String, dynamic> _$NearByReportToJson(NearByReport instance) =>
    <String, dynamic>{
      'radius': instance.radius,
      'longitude': instance.longitude,
      'latitude': instance.latitude,
    };

SubmitReportData _$SubmitReportDataFromJson(Map<String, dynamic> json) =>
    SubmitReportData(
      radius: json['radius'] as String,
      longitude: json['longitude'] as String,
      latitude: json['latitude'] as String,
    );

Map<String, dynamic> _$SubmitReportDataToJson(SubmitReportData instance) =>
    <String, dynamic>{
      'radius': instance.radius,
      'longitude': instance.longitude,
      'latitude': instance.latitude,
    };
