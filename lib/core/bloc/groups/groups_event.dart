import 'package:equatable/equatable.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';

abstract class GroupsEvent extends Equatable {
  const GroupsEvent();

  @override
  List<Object?> get props => [];
}

class GetGroupsRequested extends GroupsEvent {
  const GetGroupsRequested({
    this.filterType,
    this.latitude,
    this.longitude,
  });

  final String? filterType; // near_me | my_routes | popular
  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => [filterType, latitude, longitude];
}

class CreateGroupRequested extends GroupsEvent {
  const CreateGroupRequested({
    required this.name,
    this.description,
    required this.visibility,
    required this.groupType,
  });

  final String name;
  final String? description;
  final String visibility;
  final String groupType;

  @override
  List<Object?> get props => [name, description, visibility, groupType];
}

class JoinGroupRequested extends GroupsEvent {
  const JoinGroupRequested(this.shortCode);
  final String shortCode;

  @override
  List<Object?> get props => [shortCode];
}

class LeaveGroupRequested extends GroupsEvent {
  const LeaveGroupRequested(this.groupId);
  final String groupId;

  @override
  List<Object?> get props => [groupId];
}

/// Internal: a chat message arrived on the socket — used to keep unread
/// badges and last-message times live in the group list. Conversation
/// state itself lives in GroupChatBloc.
class GroupChatMessageArrived extends GroupsEvent {
  const GroupChatMessageArrived(this.message);
  final GroupMessage message;

  @override
  List<Object?> get props => [message];
}

class LoadMyInvitationsRequested extends GroupsEvent {
  const LoadMyInvitationsRequested();
}

class CreateInviteRequested extends GroupsEvent {
  const CreateInviteRequested({
    required this.groupId,
    this.invitedUserId,
    this.invitedUserEmail,
  });
  final String groupId;
  final String? invitedUserId;
  final String? invitedUserEmail;

  @override
  List<Object?> get props => [groupId, invitedUserId, invitedUserEmail];
}

class AcceptInvitationRequested extends GroupsEvent {
  const AcceptInvitationRequested(this.invitationId);
  final String invitationId;

  @override
  List<Object?> get props => [invitationId];
}

class DeclineInvitationRequested extends GroupsEvent {
  const DeclineInvitationRequested(this.invitationId);
  final String invitationId;

  @override
  List<Object?> get props => [invitationId];
}

class MarkGroupReadRequested extends GroupsEvent {
  const MarkGroupReadRequested(this.groupId);
  final String groupId;

  @override
  List<Object?> get props => [groupId];
}
