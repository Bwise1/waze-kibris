import 'package:equatable/equatable.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';

class GetGroupsResponse extends Equatable {
  const GetGroupsResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    required this.data,
  });

  factory GetGroupsResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GetGroupsResponse(
        message: '',
        status: '',
        statusCode: 0,
        data: [],
      );
    }
    List<CommunityGroup> data = [];
    try {
      final rawData = json['data'];
      if (rawData is List<dynamic>) {
        data = rawData
            .map((e) => e is Map<String, dynamic>
                ? CommunityGroup.fromJson(e)
                : null)
            .whereType<CommunityGroup>()
            .toList();
      }
    } catch (_) {}
    return GetGroupsResponse(
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusCode: json['status_code'] as int? ?? 0,
      data: data,
    );
  }

  final String message;
  final String status;
  final int statusCode;
  final List<CommunityGroup> data;

  Map<String, dynamic> toJson() => {
        'message': message,
        'status': status,
        'status_code': statusCode,
        'data': data.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [message, status, statusCode, data];
}

class GroupActionResponse extends Equatable {
  const GroupActionResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    this.data,
  });

  factory GroupActionResponse.fromJson(Map<String, dynamic> json) =>
      GroupActionResponse(
        message: json['message'] as String,
        status: json['status'] as String,
        statusCode: json['status_code'] as int,
        data: json['data'] != null
            ? CommunityGroup.fromJson(json['data'] as Map<String, dynamic>)
            : null,
      );

  final String message;
  final String status;
  final int statusCode;
  final CommunityGroup? data;

  Map<String, dynamic> toJson() => {
        'message': message,
        'status': status,
        'status_code': statusCode,
        'data': data?.toJson(),
      };

  @override
  List<Object?> get props => [message, status, statusCode, data];
}

class GetGroupMessagesResponse extends Equatable {
  const GetGroupMessagesResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    required this.data,
  });

  factory GetGroupMessagesResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GetGroupMessagesResponse(
        message: '',
        status: '',
        statusCode: 0,
        data: [],
      );
    }
    List<GroupMessage> data = [];
    try {
      final rawData = json['data'];
      if (rawData is List<dynamic>) {
        data = rawData
            .map((e) => e is Map<String, dynamic>
                ? GroupMessage.fromJson(e)
                : null)
            .whereType<GroupMessage>()
            .toList();
      }
    } catch (_) {}
    return GetGroupMessagesResponse(
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusCode: json['status_code'] as int? ?? 0,
      data: data,
    );
  }

  final String message;
  final String status;
  final int statusCode;
  final List<GroupMessage> data;

  Map<String, dynamic> toJson() => {
        'message': message,
        'status': status,
        'status_code': statusCode,
        'data':
            data.map((e) => {'id': e.id}).toList(), // simplified for brevity
      };

  @override
  List<Object?> get props => [message, status, statusCode, data];
}

/// Response from POST /community/:id/messages; data is the created message.
class SendGroupMessageResponse extends Equatable {
  const SendGroupMessageResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    this.data,
  });

  factory SendGroupMessageResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SendGroupMessageResponse(
        message: '',
        status: '',
        statusCode: 0,
        data: null,
      );
    }
    GroupMessage? data;
    try {
      final raw = json['data'];
      if (raw is Map<String, dynamic>) {
        data = GroupMessage.fromJson(raw);
      }
    } catch (_) {}
    return SendGroupMessageResponse(
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusCode: json['status_code'] as int? ?? 0,
      data: data,
    );
  }

  final String message;
  final String status;
  final int statusCode;
  final GroupMessage? data;

  @override
  List<Object?> get props => [message, status, statusCode, data];
}

/// Response for GET .../invitations (list); data is List<GroupInvitation>.
class GetInvitationsResponse extends Equatable {
  const GetInvitationsResponse({
    required this.message,
    required this.statusCode,
    required this.status,
    required this.data,
  });

  factory GetInvitationsResponse.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const GetInvitationsResponse(
        message: '',
        status: '',
        statusCode: 0,
        data: [],
      );
    }
    List<GroupInvitation> data = [];
    try {
      final rawData = json['data'];
      if (rawData is List<dynamic>) {
        data = rawData
            .map((e) => e is Map<String, dynamic>
                ? GroupInvitation.fromJson(e)
                : null)
            .whereType<GroupInvitation>()
            .toList();
      }
    } catch (_) {}
    return GetInvitationsResponse(
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusCode: json['status_code'] as int? ?? 0,
      data: data,
    );
  }

  final String message;
  final String status;
  final int statusCode;
  final List<GroupInvitation> data;

  @override
  List<Object?> get props => [message, status, statusCode, data];
}
