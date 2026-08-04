import 'package:equatable/equatable.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/models/reports/report_vote_entry.dart';
import 'package:waze_kibris/core/models/location/recent_location.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class InitialState extends ReportState {
  const InitialState();
}

class ReportInitial extends ReportState {
  const ReportInitial();
}

class ReportLoading extends ReportState {
  const ReportLoading();
}

class SaveLocationLoading extends ReportState {
  const SaveLocationLoading();
}

class LoadedReportByID extends ReportState {
  const LoadedReportByID();
}

class NearByReportLoaded extends ReportState {
  const NearByReportLoaded();
}

class LoadedVotesOnReports extends ReportState {
  const LoadedVotesOnReports();
}

class VoteReportSuccess extends ReportState {
  const VoteReportSuccess({
    required this.data,
    required this.message,
    required this.status,
  });

  final String message;
  final String status;

  final String data;

  @override
  List<Object?> get props => [message, data, status];
}

class SubmitReportSuccess extends ReportState {
  const SubmitReportSuccess({
    required this.data,
    required this.message,
    required this.status,
  });

  final String message;
  final String status;

  final ReportData data;

  @override
  List<Object?> get props => [message, data, status];
}

class GetReportSuccess extends ReportState {
  const GetReportSuccess({
    required this.data,
    required this.message,
    required this.status,
    required this.statusCode,
  });

  final String message;
  final String status;
  final int statusCode;

  final List<ReportData> data;

  @override
  List<Object?> get props => [message, data, status, statusCode];
}

class GetVotesOnReportSuccess extends ReportState {
  const GetVotesOnReportSuccess({
    required this.data,
    required this.message,
    required this.status,
    required this.statusCode,
  });

  final String message;
  final String status;
  final int statusCode;

  final List<ReportVoteEntry> data;

  @override
  List<Object?> get props => [message, data, status, statusCode];
}

class SaveLocationSuccess extends ReportState {
  const SaveLocationSuccess({
    required this.data,
    required this.message,
    required this.status,
    required this.statusCode,
  });

  final String message;
  final String status;
  final int statusCode;

  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [message, data, status, statusCode];
}

class GetSavedLocationsSuccess extends ReportState {
  const GetSavedLocationsSuccess({
    required this.data,
    required this.message,
    required this.status,
    required this.statusCode,
  });

  final String message;
  final String status;
  final int statusCode;

  final List<SavedLocations> data;

  @override
  List<Object?> get props => [message, data, status, statusCode];
}

class RecentLocationsLoading extends ReportState {
  const RecentLocationsLoading();
}

class GetRecentLocationsSuccess extends ReportState {
  const GetRecentLocationsSuccess({
    required this.data,
  });

  final List<RecentLocation> data;

  @override
  List<Object?> get props => [data];
}

class AddRecentLocationSuccess extends ReportState {
  const AddRecentLocationSuccess();
}

class RemoveRecentLocationSuccess extends ReportState {
  const RemoveRecentLocationSuccess();
}

class ClearRecentLocationsSuccess extends ReportState {
  const ClearRecentLocationsSuccess();
}

//
//
class ReportError extends ReportState {
  const ReportError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
