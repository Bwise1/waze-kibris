import 'package:equatable/equatable.dart';

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

class GetGroupMessagesRequested extends GroupsEvent {
  const GetGroupMessagesRequested(this.groupId);
  final String groupId;

  @override
  List<Object?> get props => [groupId];
}

class SendGroupMessageRequested extends GroupsEvent {
  const SendGroupMessageRequested({
    required this.groupId,
    required this.content,
    required this.messageType,
  });

  final String groupId;
  final String content;
  final String messageType;

  @override
  List<Object?> get props => [groupId, content, messageType];
}

class GroupLocationReceived extends GroupsEvent {
  const GroupLocationReceived(this.locationPayload);
  final Map<String, dynamic> locationPayload;

  @override
  List<Object?> get props => [locationPayload];
}

/// Dispatched when a new message arrives via WebSockets
class GroupMessageReceived extends GroupsEvent {
  const GroupMessageReceived(this.messagePayload);
  final Map<String, dynamic> messagePayload;

  @override
  List<Object?> get props => [messagePayload];
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
