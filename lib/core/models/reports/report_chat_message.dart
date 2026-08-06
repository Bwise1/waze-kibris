import 'package:equatable/equatable.dart';

class ReportChatMessage extends Equatable {
  const ReportChatMessage({
    required this.id,
    required this.reportId,
    required this.userId,
    this.username,
    this.userIcon,
    required this.content,
    required this.createdAt,
  });

  factory ReportChatMessage.fromJson(Map<String, dynamic> json) {
    return ReportChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reportId: (json['report_id'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      userIcon: json['user_icon']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  final int id;
  final int reportId;
  final String userId;
  final String? username;

  /// Avatar: an uploaded picture URL, or a preset filename from
  /// assets/user_profiles/.
  final String? userIcon;
  final String content;

  /// Server timestamp as sent (ISO-8601). Use [sentAt] for anything that
  /// needs to compare or format it.
  final String createdAt;

  /// Parsed [createdAt], falling back to now for unparseable values so the
  /// message still renders in order rather than jumping to 1970.
  DateTime get sentAt =>
      DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now();

  @override
  List<Object?> get props =>
      [id, reportId, userId, username, content, createdAt];
}
