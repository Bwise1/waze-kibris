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

ReportData _$ReportDataFromJson(Map<String, dynamic> json) => ReportData(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      type: json['type'] as String,
      severity: (json['severity'] as num).toInt(),
      active: json['active'] as bool,
      resolved: json['resolved'] as bool,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      expiresAt: json['expires_at'] as String,
      reportSource: json['report_source'] as String,
      reportStatus: json['report_status'] as String,
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
    );

Map<String, dynamic> _$ReportDataToJson(ReportData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'type': instance.type,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'severity': instance.severity,
      'active': instance.active,
      'resolved': instance.resolved,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'expires_at': instance.expiresAt,
      'report_source': instance.reportSource,
      'report_status': instance.reportStatus,
    };

GetReportsResponse _$GetReportsResponseFromJson(Map<String, dynamic> json) =>
    GetReportsResponse(
      message: json['message'] as String,
      statusCode: (json['status_code'] as num).toInt(),
      status: json['status'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) => ReportData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GetReportsResponseToJson(GetReportsResponse instance) =>
    <String, dynamic>{
      'message': instance.message,
      'status': instance.status,
      'status_code': instance.statusCode,
      'data': instance.data,
    };
