import 'package:equatable/equatable.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class InitialState extends ReportState {
  const InitialState();
}

class ReportLoading extends ReportState {
  const ReportLoading();
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
  const VoteReportSuccess();
}

class SubmitReportSuccess extends ReportState {
  const SubmitReportSuccess({
    required this.data,
    required this.message,
    required this.status,
    required this.statusCode,
  });

  final String message;
  final String status;
  final String statusCode;

  final String data;

  @override
  List<Object?> get props => [message, data, status, statusCode];
}

//
//
class ReportError extends ReportState {
  const ReportError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
