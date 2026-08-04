import 'package:equatable/equatable.dart';

/// Single vote row from `GET /reports/:id/votes`.
class ReportVoteEntry extends Equatable {
  const ReportVoteEntry({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.voteType,
    required this.createdAt,
  });

  factory ReportVoteEntry.fromJson(Map<String, dynamic> json) {
    return ReportVoteEntry(
      id: json['id']?.toString() ?? '',
      reportId: (json['report_id'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      voteType: json['vote_type']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  final String id;
  final int reportId;
  final String userId;
  final String voteType;
  final String createdAt;

  @override
  List<Object?> get props => [id, reportId, userId, voteType, createdAt];
}

class GetVotesApiResponse extends Equatable {
  const GetVotesApiResponse({
    required this.message,
    required this.status,
    required this.statusCode,
    required this.votes,
  });

  factory GetVotesApiResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GetVotesApiResponse(
        message: '',
        status: '',
        statusCode: 0,
        votes: [],
      );
    }
    var votes = <ReportVoteEntry>[];
    final raw = json['data'];
    if (raw is List<dynamic>) {
      votes = raw
          .map((e) =>
              e is Map<String, dynamic> ? ReportVoteEntry.fromJson(e) : null)
          .whereType<ReportVoteEntry>()
          .toList();
    }
    return GetVotesApiResponse(
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusCode: (json['status_code'] as num?)?.toInt() ?? 0,
      votes: votes,
    );
  }

  final String message;
  final String status;
  final int statusCode;
  final List<ReportVoteEntry> votes;

  @override
  List<Object?> get props => [message, status, statusCode, votes];
}
