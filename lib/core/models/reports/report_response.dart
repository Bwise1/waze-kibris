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
