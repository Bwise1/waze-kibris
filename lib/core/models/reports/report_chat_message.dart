import 'package:equatable/equatable.dart';

class ReportChatMessage extends Equatable {
  const ReportChatMessage({
    required this.id,
    required this.reportId,
    required this.userId,
    this.username,
    required this.content,
    required this.createdAt,
  });

  factory ReportChatMessage.fromJson(Map<String, dynamic> json) {
    return ReportChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reportId: (json['report_id'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  final int id;
  final int reportId;
  final String userId;
  final String? username;
  final String content;
  final String createdAt;

  @override
  List<Object?> get props =>
      [id, reportId, userId, username, content, createdAt];
}
