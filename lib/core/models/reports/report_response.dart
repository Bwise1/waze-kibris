import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'report_response.g.dart';

@JsonSerializable()
class CreateReport extends Equatable {
  const CreateReport({
    required this.type,
    required this.longitude,
    required this.latitude,
  });

  factory CreateReport.fromJson(Map<String, dynamic> json) =>
      _$CreateReportFromJson(json);

  final String type;
  final String longitude;

  final String latitude;

  Map<String, dynamic> toJson() => _$CreateReportToJson(this);

  @override
  List<Object?> get props => [type, longitude, latitude];
}

@JsonSerializable()
class NearByReport extends Equatable {
  const NearByReport({
    required this.radius,
    required this.longitude,
    required this.latitude,
  });

  factory NearByReport.fromJson(Map<String, dynamic> json) =>
      _$NearByReportFromJson(json);

  final String radius;
  final String longitude;
  final String latitude;

  Map<String, dynamic> toJson() => _$NearByReportToJson(this);

  @override
  List<Object?> get props => [radius, longitude, latitude];
}

@JsonSerializable()
class SubmitReportData extends Equatable {
  const SubmitReportData({
    required this.radius,
    required this.longitude,
    required this.latitude,
  });

  factory SubmitReportData.fromJson(Map<String, dynamic> json) =>
      _$SubmitReportDataFromJson(json);

  final String radius;
  final String longitude;
  final String latitude;

  Map<String, dynamic> toJson() => _$SubmitReportDataToJson(this);

  @override
  List<Object?> get props => [radius, longitude, latitude];
}

@JsonSerializable()
class ReportData extends Equatable {
  const ReportData({
    required this.id,
    required this.userId,
    required this.type,
    required this.severity,
    required this.active,
    required this.resolved,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.reportSource,
    required this.reportStatus,
    required this.longitude,
    required this.latitude,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) =>
      _$ReportDataFromJson(json);

  final int id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String type;
  final double latitude;
  final double longitude;
  final int severity;
  final bool active;
  final bool resolved;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;
  @JsonKey(name: 'expires_at')
  final String expiresAt;
  @JsonKey(name: 'report_source')
  final String reportSource;
  @JsonKey(name: 'report_status')
  final String reportStatus;

  Map<String, dynamic> toJson() => _$ReportDataToJson(this);

  @override
  List<Object?> get props => [
        id,
        userId,
        longitude,
        latitude,
        reportStatus,
        reportSource,
        resolved,
        expiresAt,
        updatedAt,
        createdAt,
        severity,
        active,
        type,
      ];
}

@JsonSerializable()
class GetReportsResponse extends Equatable {
  const GetReportsResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    required this.data,
  });

  factory GetReportsResponse.fromJson(Map<String, dynamic> json) =>
      _$GetReportsResponseFromJson(json);

  final String message;
  final String status;
  @JsonKey(name: 'status_code')
  final int statusCode;
  final List<ReportData> data;

  Map<String, dynamic> toJson() => _$GetReportsResponseToJson(this);

  @override
  List<Object?> get props => [
        message,
        status,
        statusCode,
        data,
      ];
}
