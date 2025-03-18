import 'package:equatable/equatable.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class GetReportByID extends ReportsEvent {
  const GetReportByID({required this.reportID});

  final int reportID;

  @override
  List<Object?> get props => [reportID];
}

class GetNearByReports extends ReportsEvent {
  const GetNearByReports({
    required this.radius,
    required this.lat,
    required this.long,
  });

  final String lat;
  final String long;
  final int radius;

  @override
  List<Object?> get props => [lat, long, radius];
}

class VoteOnReport extends ReportsEvent {
  const VoteOnReport({
    required this.id,
    required this.reportType,
  });

  final int id;
  final String reportType;

  @override
  List<Object?> get props => [reportType, id];
}

class SubmitReport extends ReportsEvent {
  const SubmitReport({
    required this.type,
    required this.longitude,
    required this.latitude,
  });

  final String longitude;
  final String latitude;
  final String type;

  @override
  List<Object?> get props => [
        type,
        longitude,
        latitude,
      ];
}
