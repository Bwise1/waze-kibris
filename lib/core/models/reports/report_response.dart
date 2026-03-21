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
    this.username,
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
    this.imageUrl,
    this.upvotesCount = 0,
    this.downvotesCount = 0,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) =>
      _$ReportDataFromJson(json);

  final int id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String? username;
  final String type;
  final double latitude;
  final double longitude;
  final int? severity;
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
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'upvotes_count')
  final int upvotesCount;
  @JsonKey(name: 'downvotes_count')
  final int downvotesCount;

  Map<String, dynamic> toJson() => _$ReportDataToJson(this);

  @override
  List<Object?> get props => [
        id,
        userId,
        username,
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
        imageUrl,
        upvotesCount,
        downvotesCount,
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

  factory GetReportsResponse.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const GetReportsResponse(
        message: '',
        status: '',
        statusCode: 0,
        data: [],
      );
    }
    List<ReportData> data = [];
    try {
      final rawData = json['data'];
      if (rawData is List<dynamic>) {
        data = rawData
            .map((e) => e is Map<String, dynamic>
                ? ReportData.fromJson(e)
                : null)
            .whereType<ReportData>()
            .toList();
      }
    } catch (_) {}
    return GetReportsResponse(
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusCode: (json['status_code'] as num?)?.toInt() ?? 0,
      data: data,
    );
  }

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

@JsonSerializable()
class SubmitReportResponse extends Equatable {
  const SubmitReportResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    required this.data,
  });

  factory SubmitReportResponse.fromJson(Map<String, dynamic> json) =>
      _$SubmitReportResponseFromJson(json);

  final String message;
  final String status;
  @JsonKey(name: 'status_code')
  final int statusCode;
  final ReportData data;

  Map<String, dynamic> toJson() => _$SubmitReportResponseToJson(this);

  @override
  List<Object?> get props => [
        message,
        status,
        statusCode,
        data,
      ];
}

@JsonSerializable()
class SaveLocationResponse extends Equatable {
  const SaveLocationResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    required this.data,
  });

  factory SaveLocationResponse.fromJson(Map<String, dynamic> json) =>
      _$SaveLocationResponseFromJson(json);

  final String message;
  final String status;
  @JsonKey(name: 'status_code')
  final int statusCode;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => _$SaveLocationResponseToJson(this);

  @override
  List<Object?> get props => [
        message,
        status,
        statusCode,
        data,
      ];
}

@JsonSerializable()
class GetSavedLocationsResponse extends Equatable {
  const GetSavedLocationsResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    required this.data,
  });

  factory GetSavedLocationsResponse.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const GetSavedLocationsResponse(
        message: '',
        status: '',
        statusCode: 0,
        data: [],
      );
    }
    List<SavedLocations> data = [];
    try {
      final rawData = json['data'];
      if (rawData is List<dynamic>) {
        data = rawData
            .map((e) => e is Map<String, dynamic>
                ? SavedLocations.fromJson(e)
                : null)
            .whereType<SavedLocations>()
            .toList();
      }
    } catch (_) {}
    return GetSavedLocationsResponse(
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusCode: (json['status_code'] as num?)?.toInt() ?? 0,
      data: data,
    );
  }

  final String message;
  final String status;
  @JsonKey(name: 'status_code')
  final int statusCode;
  final List<SavedLocations> data;

  Map<String, dynamic> toJson() => _$GetSavedLocationsResponseToJson(this);

  @override
  List<Object?> get props => [
        message,
        status,
        statusCode,
        data,
      ];
}

@JsonSerializable()
class SavedLocations extends Equatable {
  const SavedLocations({
    this.placeId,
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory SavedLocations.fromJson(Map<String, dynamic> json) =>
      _$SavedLocationsFromJson(json);

  final int id;
  @JsonKey(name: 'place_id')
  final String? placeId;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
//
  Map<String, dynamic> toJson() => _$SavedLocationsToJson(this);

  @override
  List<Object?> get props => [
        name,
        address,
        longitude,
        latitude,placeId,
      ];
}
