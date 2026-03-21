import 'dart:convert';
import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';
import 'package:waze_kibris/core/repositories/group_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

class GroupsBloc extends Bloc<GroupsEvent, GroupsState> {
  GroupsBloc({
    required GroupRepository groupRepository,
    required WebSocketService webSocketService,
  })  : _groupRepository = groupRepository,
        _webSocketService = webSocketService,
        super(const GroupsInitial()) {
    on<GetGroupsRequested>(_onGetGroups);
    on<CreateGroupRequested>(_onCreateGroup);
    on<JoinGroupRequested>(_onJoinGroup);
    on<LeaveGroupRequested>(_onLeaveGroup);
    on<GetGroupMessagesRequested>(_onGetGroupMessages);
    on<SendGroupMessageRequested>(_onSendGroupMessage);
    on<GroupMessageReceived>(_onGroupMessageReceived);
    on<GroupLocationReceived>(_onGroupLocationReceived);
    on<LoadMyInvitationsRequested>(_onLoadMyInvitations);
    on<CreateInviteRequested>(_onCreateInvite);
    on<AcceptInvitationRequested>(_onAcceptInvitation);
    on<DeclineInvitationRequested>(_onDeclineInvitation);
    on<MarkGroupReadRequested>(_onMarkGroupRead);

    _webSocketService.messages.listen((msg) {
      if (msg.type == 'group_chat' && msg.content != null) {
        try {
          final json = jsonDecode(msg.content!) as Map<String, dynamic>;
          add(GroupMessageReceived(json));
        } catch (_) {}
      } else if (msg.type == 'group_location_update' && msg.content != null) {
        try {
          final json = jsonDecode(msg.content!) as Map<String, dynamic>;
          add(GroupLocationReceived(json));
        } catch (_) {}
      }
    });
  }

  final GroupRepository _groupRepository;
  final WebSocketService _webSocketService;

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

  Future<void> _onGetGroupMessages(
    GetGroupMessagesRequested event,
    Emitter<GroupsState> emit,
  ) async {
    final wasShowingMessages = state is GetGroupMessagesSuccess;
    try {
      // Do not emit GroupsLoading so the chat screen shows scaffold + "Loading messages..." instead of a full-screen spinner.
      final response = await _groupRepository.getGroupMessages(event.groupId);
      log('GroupsBloc: get messages for group ${event.groupId} returned ${response.data.length} messages');
      final currentState = state;
      if (response.data.isEmpty &&
          currentState is GetGroupMessagesSuccess &&
          currentState.groupId == event.groupId &&
          currentState.messages.isNotEmpty) {
        log('GroupsBloc: refetch returned empty for group ${event.groupId}, keeping current ${currentState.messages.length} messages');
        return;
      }
      final groupLocations = currentState is GetGroupMessagesSuccess &&
              currentState.groupId == event.groupId
          ? currentState.groupLocations
          : <String, dynamic>{};
      emit(GetGroupMessagesSuccess(
        messages: response.data,
        groupId: event.groupId,
        groupLocations: groupLocations,
      ));
    } catch (e) {
      log('Get group messages error: $e');
      if (!wasShowingMessages) emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onSendGroupMessage(
    SendGroupMessageRequested event,
    Emitter<GroupsState> emit,
  ) async {
    try {
      final response = await _groupRepository.sendGroupMessage(
        event.groupId,
        event.content,
        event.messageType,
      );
      final createdMessage = response.data;
      log('GroupsBloc: send message response data=${createdMessage != null ? "message(id=${createdMessage.id})" : "null"}');
      final currentState = state;
      if (createdMessage != null &&
          currentState is GetGroupMessagesSuccess &&
          currentState.groupId == event.groupId &&
          !currentState.messages.any((m) => m.id == createdMessage.id)) {
        final updatedList = List<GroupMessage>.from(currentState.messages)
          ..insert(0, createdMessage);
        emit(GetGroupMessagesSuccess(
          messages: updatedList,
          groupId: event.groupId,
          groupLocations: currentState.groupLocations,
        ));
      }
      add(GetGroupMessagesRequested(event.groupId));
    } catch (e) {
      emit(GroupsError(e.toString()));
    }
  }

  Future<void> _onGroupMessageReceived(
    GroupMessageReceived event,
    Emitter<GroupsState> emit,
  ) async {
    final currentState = state;
    if (currentState is GetGroupMessagesSuccess) {
      try {
        final newMsg = GroupMessage.fromJson(event.messagePayload);
        // Only append if it belongs to the current open group (assuming we have one state list for now)
        // This can be refined later if the app allows multiple active chats
        final updatedList = List<GroupMessage>.from(currentState.messages);

        // Ensure that we don't add duplicates
        if (!updatedList.any((m) => m.id == newMsg.id)) {
          updatedList.insert(0, newMsg);
          emit(GetGroupMessagesSuccess(
            messages: updatedList,
            groupId: currentState.groupId,
            groupLocations: currentState.groupLocations,
          ));
        }
      } catch (e) {
        log('Error parsing incoming group message: $e');
      }
    }
  }

  Future<void> _onGroupLocationReceived(
    GroupLocationReceived event,
    Emitter<GroupsState> emit,
  ) async {
    final currentState = state;
    if (currentState is GetGroupMessagesSuccess) {
      try {
        final payload = event.locationPayload;
        final userId = payload['userId'] as String?;
        // Location might come in as lat/lng strings or doubles depending on backend
        final lat = double.tryParse(payload['lat'].toString());
        final lng = double.tryParse(payload['lng'].toString());

        if (userId != null && lat != null && lng != null) {
          final newLocs =
              Map<String, dynamic>.from(currentState.groupLocations);
          newLocs[userId] = {'lat': lat, 'lng': lng};
          emit(currentState.copyWith(groupLocations: newLocs));
        }
      } catch (e) {
        log('Error parsing group location update: $e');
      }
    }
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
        // We're likely in the middle of an active chat (GetGroupMessagesSuccess).
        // Avoid emitting/triggering a groups refresh here, since it can cause
        // the chat screen to briefly rebuild into a loading state.
      }
    } catch (e) {
      // Non-fatal: unread counters will still correct on next refresh.
      log('Mark group read error: $e');
    }
  }
}
