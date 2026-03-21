class CommunityGroup {
  CommunityGroup({
    required this.id,
    required this.name,
    required this.shortCode,
    this.description,
    required this.groupType,
    required this.visibility,
    this.destinationPlaceId,
    this.destinationName,
    this.iconUrl,
    required this.memberCount,
    this.isMember = false,
    this.unreadCount = 0,
    this.lastReadAt,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String shortCode;
  final String? description;
  final String groupType;
  final String visibility;
  final String? destinationPlaceId;
  final String? destinationName;
  final String? iconUrl;
  final int memberCount;
  final bool isMember;
  final int unreadCount;
  final DateTime? lastReadAt;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommunityGroup copyWith({
    String? id,
    String? name,
    String? shortCode,
    String? description,
    String? groupType,
    String? visibility,
    String? destinationPlaceId,
    String? destinationName,
    String? iconUrl,
    int? memberCount,
    bool? isMember,
    int? unreadCount,
    DateTime? lastReadAt,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      description: description ?? this.description,
      groupType: groupType ?? this.groupType,
      visibility: visibility ?? this.visibility,
      destinationPlaceId: destinationPlaceId ?? this.destinationPlaceId,
      destinationName: destinationName ?? this.destinationName,
      iconUrl: iconUrl ?? this.iconUrl,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CommunityGroup.fromJson(Map<String, dynamic> json) {
    return CommunityGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      shortCode: json['short_code'] as String,
      description: json['description'] as String?,
      groupType: json['group_type'] as String,
      visibility: json['visibility'] as String,
      destinationPlaceId: json['destination_place_id'] as String?,
      destinationName: json['destination_name'] as String?,
      iconUrl: json['icon_url'] as String?,
      memberCount: json['member_count'] as int? ?? 0,
      isMember: json['is_member'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.tryParse(json['last_read_at'] as String)
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'short_code': shortCode,
      'description': description,
      'group_type': groupType,
      'visibility': visibility,
      'destination_place_id': destinationPlaceId,
      'destination_name': destinationName,
      'icon_url': iconUrl,
      'member_count': memberCount,
      'is_member': isMember,
      'unread_count': unreadCount,
      'last_read_at': lastReadAt?.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class GroupMembership {
  GroupMembership({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final String role;
  final String status;
  final DateTime joinedAt;

  factory GroupMembership.fromJson(Map<String, dynamic> json) {
    return GroupMembership(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

class GroupInvitation {
  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.invitedUserId,
    this.invitedBy,
    required this.status,
    required this.createdAt,
    this.groupName,
    this.invitedByName,
    this.invitedUserEmail,
  });

  final String id;
  final String groupId;
  final String invitedUserId;
  final String? invitedBy;
  final String status;
  final DateTime createdAt;
  final String? groupName;
  final String? invitedByName;
  final String? invitedUserEmail;

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    return GroupInvitation(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      invitedUserId: json['invited_user_id']?.toString() ?? '',
      invitedBy: json['invited_by']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: createdAtRaw != null
          ? (createdAtRaw is String
              ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
              : DateTime.now())
          : DateTime.now(),
      groupName: json['group_name']?.toString(),
      invitedByName: json['invited_by_name']?.toString(),
      invitedUserEmail: json['invited_user_email']?.toString(),
    );
  }
}

class GroupMessage {
  GroupMessage({
    required this.id,
    required this.groupId,
    required this.userId,
    this.senderUsername,
    required this.messageType,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String userId;
  final String? senderUsername;
  final String messageType;
  final String content;
  final DateTime createdAt;

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final groupId = json['group_id'];
    final userId = json['user_id'];
    final createdAtRaw = json['created_at'];
    final senderUsername = json['sender_username']?.toString();
    return GroupMessage(
      id: id?.toString() ?? '',
      groupId: groupId?.toString() ?? '',
      userId: userId?.toString() ?? '',
      senderUsername: senderUsername?.isNotEmpty == true ? senderUsername : null,
      messageType: json['message_type']?.toString() ?? 'text',
      content: json['content']?.toString() ?? '',
      createdAt: createdAtRaw != null
          ? (createdAtRaw is String
              ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
              : createdAtRaw is int
                  ? DateTime.fromMillisecondsSinceEpoch(createdAtRaw)
                  : DateTime.now())
          : DateTime.now(),
    );
  }
}
