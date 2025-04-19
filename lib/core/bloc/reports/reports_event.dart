import 'package:equatable/equatable.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  factory ReportsEvent.getReportByID({
    required String reportID,
  }) {
    return GetReportByID(reportID: reportID);
  }

  factory ReportsEvent.getNearByReports({
    required int radius,
    required String lat,
    required String long,
  }) {
    return GetNearByReports(radius: radius, lat: lat, long: long);
  }

  factory ReportsEvent.voteOnReport({
    required int reportID,
    required String reportType,
  }) {
    return VoteOnReport(reportID: reportID, reportType: reportType);
  }

  factory ReportsEvent.submitReportRequested({
    required double longitude,
    required double latitude,
    required String type,
  }) {
    return SubmitReportRequested(
      longitude: longitude,
      latitude: latitude,
      type: type,
    );
  }

  factory ReportsEvent.getVotesOnReport({
    required int reportID,
  }) {
    return GetVotesOnReport(
      reportID: reportID,
    );
  }

  factory ReportsEvent.clearExpiredToken() {
    return const ClearExpiredToken();
  }

  @override
  List<Object?> get props => [];
}

class GetReportByID extends ReportsEvent {
  const GetReportByID({required this.reportID});

  final String reportID;

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
    required this.reportID,
    required this.reportType,
  });

  final int reportID;
  final String reportType;

  @override
  List<Object?> get props => [reportType, reportID];
}

class SubmitReportRequested extends ReportsEvent {
  const SubmitReportRequested({
    required this.type,
    required this.longitude,
    required this.latitude,
  });

  final double longitude;
  final double latitude;
  final String type;

  @override
  List<Object?> get props => [
        type,
        longitude,
        latitude,
      ];
}

class GetVotesOnReport extends ReportsEvent {
  const GetVotesOnReport({
    required this.reportID,
  });

  final int reportID;

  @override
  List<Object?> get props => [
        reportID,
      ];
}

class ClearExpiredToken extends ReportsEvent {
  const ClearExpiredToken();

  @override
  List<Object?> get props => [];
}
