import 'package:equatable/equatable.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';

abstract class GroupsState extends Equatable {
  const GroupsState();

  @override
  List<Object?> get props => [];
}

class GroupsInitial extends GroupsState {
  const GroupsInitial();
}

class GroupsLoading extends GroupsState {
  const GroupsLoading();
}

class GroupsError extends GroupsState {
  const GroupsError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class GetGroupsSuccess extends GroupsState {
  const GetGroupsSuccess(this.groups);
  final List<CommunityGroup> groups;

  int get totalUnreadCount =>
      groups.fold<int>(0, (sum, g) => sum + (g.unreadCount));

  @override
  List<Object?> get props => [groups];
}

class GroupActionSuccess extends GroupsState {
  const GroupActionSuccess(this.message, {this.group});
  final String message;
  final CommunityGroup? group;

  @override
  List<Object?> get props => [message, group];
}

class GetGroupMessagesSuccess extends GroupsState {
  const GetGroupMessagesSuccess({
    required this.messages,
    required this.groupId,
    this.groupLocations = const {},
  });
  final List<GroupMessage> messages;
  final String groupId;
  final Map<String, dynamic>
      groupLocations; // map of userId -> LatLng/dynamic dict

  GetGroupMessagesSuccess copyWith({
    List<GroupMessage>? messages,
    String? groupId,
    Map<String, dynamic>? groupLocations,
  }) {
    return GetGroupMessagesSuccess(
      messages: messages ?? this.messages,
      groupId: groupId ?? this.groupId,
      groupLocations: groupLocations ?? this.groupLocations,
    );
  }

  @override
  List<Object?> get props => [messages, groupId, groupLocations];
}

class MyInvitationsLoaded extends GroupsState {
  const MyInvitationsLoaded(this.invitations);
  final List<GroupInvitation> invitations;

  @override
  List<Object?> get props => [invitations];
}
