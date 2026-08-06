import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';
import 'package:waze_kibris/core/repositories/group_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

abstract class GroupChatEvent extends Equatable {
  const GroupChatEvent();
  @override
  List<Object?> get props => [];
}

/// Load the newest page of history (fired once on open, or by "Retry").
class GroupChatStarted extends GroupChatEvent {
  const GroupChatStarted();
}

/// User scrolled to the top — fetch the page before the oldest message.
class GroupChatOlderRequested extends GroupChatEvent {
  const GroupChatOlderRequested();
}

class GroupChatSendRequested extends GroupChatEvent {
  const GroupChatSendRequested(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// Re-send a bubble that previously failed.
class GroupChatRetryRequested extends GroupChatEvent {
  const GroupChatRetryRequested(this.localId);
  final String localId;
  @override
  List<Object?> get props => [localId];
}

class _GroupChatIncoming extends GroupChatEvent {
  const _GroupChatIncoming(this.message);
  final GroupMessage message;
  @override
  List<Object?> get props => [message];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum ChatSendStatus { sending, sent, failed }

/// A message plus its delivery state. [localId] is stable across the
/// optimistic-insert -> server-confirm swap so list items keep identity.
class ChatEntry extends Equatable {
  const ChatEntry({
    required this.localId,
    required this.message,
    this.status = ChatSendStatus.sent,
  });

  final String localId;
  final GroupMessage message;
  final ChatSendStatus status;

  ChatEntry copyWith({GroupMessage? message, ChatSendStatus? status}) =>
      ChatEntry(
        localId: localId,
        message: message ?? this.message,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [localId, message.id, status];
}

class GroupChatState extends Equatable {
  const GroupChatState({
    required this.groupId,
    this.entries = const [],
    this.loadingInitial = true,
    this.loadingOlder = false,
    this.hasMore = true,
    this.loadError,
  });

  final String groupId;

  /// Newest first (index 0 renders at the bottom of the reversed list).
  final List<ChatEntry> entries;
  final bool loadingInitial;
  final bool loadingOlder;
  final bool hasMore;

  /// Non-null when the *initial* load failed and there is nothing to show.
  final String? loadError;

  GroupChatState copyWith({
    List<ChatEntry>? entries,
    bool? loadingInitial,
    bool? loadingOlder,
    bool? hasMore,
    String? loadError,
    bool clearLoadError = false,
  }) =>
      GroupChatState(
        groupId: groupId,
        entries: entries ?? this.entries,
        loadingInitial: loadingInitial ?? this.loadingInitial,
        loadingOlder: loadingOlder ?? this.loadingOlder,
        hasMore: hasMore ?? this.hasMore,
        loadError: clearLoadError ? null : (loadError ?? this.loadError),
      );

  @override
  List<Object?> get props =>
      [groupId, entries, loadingInitial, loadingOlder, hasMore, loadError];
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

/// One conversation. Scoped to a single group so unrelated group/list/invite
/// activity can never disturb an open chat, and incoming socket messages are
/// dropped unless they belong to this group.
class GroupChatBloc extends Bloc<GroupChatEvent, GroupChatState> {
  GroupChatBloc({
    required String groupId,
    required GroupRepository groupRepository,
    required WebSocketService webSocketService,
    required String? currentUserId,
  })  : _groupRepository = groupRepository,
        _currentUserId = currentUserId,
        super(GroupChatState(groupId: groupId)) {
    on<GroupChatStarted>(_onStarted);
    on<GroupChatOlderRequested>(_onOlderRequested);
    on<GroupChatSendRequested>(_onSendRequested);
    on<GroupChatRetryRequested>(_onRetryRequested);
    on<_GroupChatIncoming>(_onIncoming);

    _wsSubscription = webSocketService.messages.listen((msg) {
      if (msg.type != 'group_chat' || msg.content == null) return;
      try {
        final json = jsonDecode(msg.content!) as Map<String, dynamic>;
        final message = GroupMessage.fromJson(json);
        if (message.groupId == groupId) {
          add(_GroupChatIncoming(message));
        }
      } catch (e) {
        log('GroupChatBloc: bad incoming payload: $e');
      }
    });
  }

  static const int _pageSize = 50;

  final GroupRepository _groupRepository;
  final String? _currentUserId;
  StreamSubscription<WsMessage>? _wsSubscription;
  final _uuid = const Uuid();

  @override
  Future<void> close() async {
    await _wsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    GroupChatStarted event,
    Emitter<GroupChatState> emit,
  ) async {
    emit(state.copyWith(loadingInitial: true, clearLoadError: true));
    try {
      final response = await _groupRepository
          .getGroupMessages(state.groupId, limit: _pageSize);
      final fetched = response.data
          .map((m) => ChatEntry(localId: m.id, message: m))
          .toList();
      // Keep any in-flight/failed optimistic bubbles that aren't in the page.
      final pending = state.entries
          .where((e) =>
              e.status != ChatSendStatus.sent &&
              !fetched.any((f) => f.message.id == e.message.id))
          .toList();
      emit(state.copyWith(
        entries: [...pending, ...fetched],
        loadingInitial: false,
        hasMore: fetched.length >= _pageSize,
        clearLoadError: true,
      ));
    } catch (e) {
      log('GroupChatBloc: initial load failed: $e');
      if (state.entries.isEmpty) {
        emit(state.copyWith(
          loadingInitial: false,
          loadError: 'Could not load messages. Check your connection.',
        ));
      } else {
        emit(state.copyWith(loadingInitial: false));
      }
    }
  }

  Future<void> _onOlderRequested(
    GroupChatOlderRequested event,
    Emitter<GroupChatState> emit,
  ) async {
    if (state.loadingOlder || !state.hasMore || state.entries.isEmpty) return;
    final sent =
        state.entries.where((e) => e.status == ChatSendStatus.sent).toList();
    if (sent.isEmpty) return;
    final oldest = sent.last.message.createdAt;

    emit(state.copyWith(loadingOlder: true));
    try {
      final response = await _groupRepository.getGroupMessages(
        state.groupId,
        before: oldest,
        limit: _pageSize,
      );
      final existingIds = state.entries.map((e) => e.message.id).toSet();
      final older = response.data
          .where((m) => !existingIds.contains(m.id))
          .map((m) => ChatEntry(localId: m.id, message: m))
          .toList();
      emit(state.copyWith(
        entries: [...state.entries, ...older],
        loadingOlder: false,
        hasMore: response.data.length >= _pageSize,
      ));
    } catch (e) {
      log('GroupChatBloc: load older failed: $e');
      emit(state.copyWith(loadingOlder: false));
    }
  }

  Future<void> _onSendRequested(
    GroupChatSendRequested event,
    Emitter<GroupChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    final localId = _uuid.v4();
    final optimistic = ChatEntry(
      localId: localId,
      status: ChatSendStatus.sending,
      message: GroupMessage(
        id: localId,
        groupId: state.groupId,
        userId: _currentUserId ?? '',
        messageType: 'text',
        content: text,
        createdAt: DateTime.now(),
      ),
    );
    emit(state.copyWith(entries: [optimistic, ...state.entries]));
    await _deliver(localId, text, emit);
  }

  Future<void> _onRetryRequested(
    GroupChatRetryRequested event,
    Emitter<GroupChatState> emit,
  ) async {
    final entry = _entryByLocalId(event.localId);
    if (entry == null || entry.status != ChatSendStatus.failed) return;
    _replace(event.localId, entry.copyWith(status: ChatSendStatus.sending),
        emit);
    await _deliver(event.localId, entry.message.content, emit);
  }

  Future<void> _deliver(
    String localId,
    String text,
    Emitter<GroupChatState> emit,
  ) async {
    try {
      final response = await _groupRepository.sendGroupMessage(
        state.groupId,
        text,
        'text',
      );
      final confirmed = response.data;
      if (confirmed == null) {
        // Server accepted but returned no body — keep the optimistic bubble.
        final entry = _entryByLocalId(localId);
        if (entry != null) {
          _replace(localId, entry.copyWith(status: ChatSendStatus.sent), emit);
        }
        return;
      }
      // The socket broadcast may have already delivered the confirmed
      // message; if so drop the optimistic bubble instead of duplicating.
      final alreadyDelivered = state.entries.any(
        (e) => e.localId != localId && e.message.id == confirmed.id,
      );
      if (alreadyDelivered) {
        emit(state.copyWith(
          entries:
              state.entries.where((e) => e.localId != localId).toList(),
        ));
      } else {
        final entry = _entryByLocalId(localId);
        if (entry != null) {
          _replace(
            localId,
            entry.copyWith(message: confirmed, status: ChatSendStatus.sent),
            emit,
          );
        }
      }
    } catch (e) {
      log('GroupChatBloc: send failed: $e');
      final entry = _entryByLocalId(localId);
      if (entry != null) {
        _replace(localId, entry.copyWith(status: ChatSendStatus.failed), emit);
      }
    }
  }

  void _onIncoming(
    _GroupChatIncoming event,
    Emitter<GroupChatState> emit,
  ) {
    final incoming = event.message;
    if (state.entries.any((e) => e.message.id == incoming.id)) return;
    // Our own message echoing back before the REST response: reconcile with
    // the in-flight optimistic bubble instead of showing it twice.
    if (incoming.userId == _currentUserId) {
      final inFlight = state.entries
          .where((e) =>
              e.status == ChatSendStatus.sending &&
              e.message.content == incoming.content)
          .toList();
      if (inFlight.isNotEmpty) {
        _replace(
          inFlight.first.localId,
          inFlight.first
              .copyWith(message: incoming, status: ChatSendStatus.sent),
          emit,
        );
        return;
      }
    }
    emit(state.copyWith(
      entries: [
        ChatEntry(localId: incoming.id, message: incoming),
        ...state.entries,
      ],
    ));
  }

  ChatEntry? _entryByLocalId(String localId) {
    for (final e in state.entries) {
      if (e.localId == localId) return e;
    }
    return null;
  }

  void _replace(String localId, ChatEntry updated, Emitter<GroupChatState> emit) {
    emit(state.copyWith(
      entries: state.entries
          .map((e) => e.localId == localId ? updated : e)
          .toList(),
    ));
  }
}
