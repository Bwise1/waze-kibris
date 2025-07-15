import 'package:equatable/equatable.dart';
import 'package:waze_kibris/core/models/location/recent_location.dart';

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

  factory ReportsEvent.saveLocation({
    required String locationName,
    required double lat,
    required double lng,
  }) {
    return SaveLocation(
      locationName: locationName,
      lat: lat,
      lng: lng,
    );
  }

  factory ReportsEvent.getSavedLocations() {
    return const GetSavedLocations();
  }

  factory ReportsEvent.getRecentLocations() {
    return const GetRecentLocations();
  }

  factory ReportsEvent.addRecentLocation({
    required RecentLocation location,
  }) {
    return AddRecentLocation(location: location);
  }

  factory ReportsEvent.removeRecentLocation({
    required String placeId,
  }) {
    return RemoveRecentLocation(placeId: placeId);
  }

  factory ReportsEvent.clearRecentLocations() {
    return const ClearRecentLocations();
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

class SaveLocation extends ReportsEvent {
  const SaveLocation(
      {required this.locationName, required this.lat, required this.lng});

  final String locationName;
  final double lat;
  final double lng;

  @override
  List<Object?> get props => [
        locationName,
        lat,
        lng,
      ];
}

class GetSavedLocations extends ReportsEvent {
  const GetSavedLocations();
}

class GetRecentLocations extends ReportsEvent {
  const GetRecentLocations();
}

class AddRecentLocation extends ReportsEvent {
  const AddRecentLocation({required this.location});

  final RecentLocation location;

  @override
  List<Object?> get props => [location];
}

class RemoveRecentLocation extends ReportsEvent {
  const RemoveRecentLocation({required this.placeId});

  final String placeId;

  @override
  List<Object?> get props => [placeId];
}

class ClearRecentLocations extends ReportsEvent {
  const ClearRecentLocations();
}

class ClearExpiredToken extends ReportsEvent {
  const ClearExpiredToken();

  @override
  List<Object?> get props => [];
}
