import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';
import 'package:waze_kibris/core/repositories/group_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

/// Group *list*, membership, and invitations. Conversations live in
/// GroupChatBloc — this bloc only listens to the socket to keep unread
/// badges and "last message" times live while the user is anywhere in the
/// app.
class GroupsBloc extends Bloc<GroupsEvent, GroupsState> {
  GroupsBloc({
    required GroupRepository groupRepository,
    required WebSocketService webSocketService,
    String? Function()? currentUserId,
  })  : _groupRepository = groupRepository,
        _currentUserId = currentUserId,
        super(const GroupsInitial()) {
    on<GetGroupsRequested>(_onGetGroups);
    on<CreateGroupRequested>(_onCreateGroup);
    on<JoinGroupRequested>(_onJoinGroup);
    on<LeaveGroupRequested>(_onLeaveGroup);
    on<GroupChatMessageArrived>(_onGroupChatMessageArrived);
    on<LoadMyInvitationsRequested>(_onLoadMyInvitations);
    on<CreateInviteRequested>(_onCreateInvite);
    on<AcceptInvitationRequested>(_onAcceptInvitation);
    on<DeclineInvitationRequested>(_onDeclineInvitation);
    on<MarkGroupReadRequested>(_onMarkGroupRead);

    _wsSubscription = webSocketService.messages.listen((msg) {
      if (msg.type == 'group_chat' && msg.content != null) {
        try {
          final json = jsonDecode(msg.content!) as Map<String, dynamic>;
          add(GroupChatMessageArrived(GroupMessage.fromJson(json)));
        } catch (_) {}
      }
    });
  }

  final GroupRepository _groupRepository;
  final String? Function()? _currentUserId;
  StreamSubscription<WsMessage>? _wsSubscription;

  @override
  Future<void> close() async {
    await _wsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onGetGroups(
    GetGroupsRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      // Avoid UI jank on quick filter switches: keep existing list visible while refreshing.
      final hasCachedGroups = state is GetGroupsSuccess;
      if (!hasCachedGroups) {
        emit(const GroupsLoading());
      }
      final response = await _groupRepository.getGroups(
        filterType: event.filterType,
        latitude: event.latitude,
        longitude: event.longitude,
      );
      emit(GetGroupsSuccess(response.data));
    } catch (e) {
      log('Groups fetch error: $e');
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onCreateGroup(
    CreateGroupRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      emit(const GroupsLoading());
      final response = await _groupRepository.createGroup(
        event.name,
        event.description,
        event.visibility,
        event.groupType,
      );
      emit(GroupActionSuccess(response.message, group: response.data));
      add(const GetGroupsRequested());
    } catch (e) {
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onJoinGroup(
    JoinGroupRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      emit(const GroupsLoading());
      final response =
          await _groupRepository.joinGroupByShortCode(event.shortCode);
      emit(GroupActionSuccess(response.message));
      add(const GetGroupsRequested());
    } catch (e) {
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onLeaveGroup(
    LeaveGroupRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      emit(const GroupsLoading());
      final response = await _groupRepository.leaveGroup(event.groupId);
      emit(GroupActionSuccess(response.message));
      add(const GetGroupsRequested());
    } catch (e) {
      emit(GroupsError(e.toString()));
    }
  }

  /// A chat message arrived on the socket (for any of my groups): bump that
  /// group's unread badge and last-message time in the list, live. Messages I
  /// sent myself update the timestamp but not the badge.
  void _onGroupChatMessageArrived(
    GroupChatMessageArrived event,
    Emitter<GroupsState> emit,
  ) {
    final currentState = state;
    if (currentState is! GetGroupsSuccess) return;
    final msg = event.message;
    final myId = _currentUserId?.call();
    final isMine = myId != null && msg.userId == myId;

    var changed = false;
    final updated = currentState.groups.map((g) {
      if (g.id != msg.groupId) return g;
      changed = true;
      return g.copyWith(
        unreadCount: isMine ? g.unreadCount : g.unreadCount + 1,
        lastMessageAt: msg.createdAt,
      );
    }).toList(growable: false);
    if (changed) emit(GetGroupsSuccess(updated));
  }

  Future<void> _onLoadMyInvitations(
    LoadMyInvitationsRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      final response = await _groupRepository.listMyInvitations();
      emit(MyInvitationsLoaded(response.data));
    } catch (e) {
      log('Load my invitations error: $e');
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onCreateInvite(
    CreateInviteRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      await _groupRepository.createInvitation(
        event.groupId,
        invitedUserId: event.invitedUserId,
        invitedUserEmail: event.invitedUserEmail,
      );
      emit(const GroupActionSuccess('Invitation sent'));
    } catch (e) {
      log('Create invite error: $e');
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onAcceptInvitation(
    AcceptInvitationRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      await _groupRepository.acceptInvitation(event.invitationId);
      emit(const GroupActionSuccess('Invitation accepted'));
      add(const LoadMyInvitationsRequested());
      add(const GetGroupsRequested());
    } catch (e) {
      log('Accept invitation error: $e');
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onDeclineInvitation(
    DeclineInvitationRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      await _groupRepository.declineInvitation(event.invitationId);
      emit(const GroupActionSuccess('Invitation declined'));
      add(const LoadMyInvitationsRequested());
    } catch (e) {
      log('Decline invitation error: $e');
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onMarkGroupRead(
    MarkGroupReadRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      await _groupRepository.markGroupRead(event.groupId);

      final currentState = state;
      if (currentState is GetGroupsSuccess) {
        final updatedGroups = currentState.groups
            .map(
              (g) => g.id == event.groupId
                  ? g.copyWith(unreadCount: 0, lastReadAt: DateTime.now())
                  : g,
            )
            .toList(growable: false);
        emit(GetGroupsSuccess(updatedGroups));
      } else {
        // Not showing the list right now (e.g. a chat is open).
        // Avoid emitting/triggering a groups refresh here, since it can cause
        // the chat screen to briefly rebuild into a loading state.
      }
    } catch (e) {
      // Non-fatal: unread counters will still correct on next refresh.
      log('Mark group read error: $e');
    }
  }
}
