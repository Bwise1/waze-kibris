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

/// Someone in the group started or stopped typing.
class _GroupTypingChanged extends GroupChatEvent {
  const _GroupTypingChanged(this.userId, this.username, this.typing);
  final String userId;
  final String username;
  final bool typing;
  @override
  List<Object?> get props => [userId, username, typing];
}

/// Tell the group we are (or are no longer) typing.
class GroupChatTypingChanged extends GroupChatEvent {
  const GroupChatTypingChanged(this.typing);
  final bool typing;
  @override
  List<Object?> get props => [typing];
}

/// Drop a stale typing entry when its author goes quiet without sending.
class _GroupTypingExpired extends GroupChatEvent {
  const _GroupTypingExpired(this.userId);
  final String userId;
  @override
  List<Object?> get props => [userId];
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
    this.typingUsers = const {},
  });

  final String groupId;

  /// Newest first (index 0 renders at the bottom of the reversed list).
  final List<ChatEntry> entries;
  final bool loadingInitial;
  final bool loadingOlder;
  final bool hasMore;

  /// Non-null when the *initial* load failed and there is nothing to show.
  final String? loadError;

  /// Who is currently typing, keyed by user id → display name.
  final Map<String, String> typingUsers;

  GroupChatState copyWith({
    List<ChatEntry>? entries,
    bool? loadingInitial,
    bool? loadingOlder,
    bool? hasMore,
    String? loadError,
    Map<String, String>? typingUsers,
    bool clearLoadError = false,
  }) =>
      GroupChatState(
        groupId: groupId,
        entries: entries ?? this.entries,
        loadingInitial: loadingInitial ?? this.loadingInitial,
        loadingOlder: loadingOlder ?? this.loadingOlder,
        hasMore: hasMore ?? this.hasMore,
        loadError: clearLoadError ? null : (loadError ?? this.loadError),
        typingUsers: typingUsers ?? this.typingUsers,
      );

  @override
  List<Object?> get props => [
        groupId,
        entries,
        loadingInitial,
        loadingOlder,
        hasMore,
        loadError,
        typingUsers,
      ];
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
        _webSocketService = webSocketService,
        _currentUserId = currentUserId,
        super(GroupChatState(groupId: groupId)) {
    on<GroupChatStarted>(_onStarted);
    on<GroupChatOlderRequested>(_onOlderRequested);
    on<GroupChatSendRequested>(_onSendRequested);
    on<GroupChatRetryRequested>(_onRetryRequested);
    on<_GroupChatIncoming>(_onIncoming);
    on<_GroupTypingChanged>(_onTypingChanged);
    on<_GroupTypingExpired>(_onTypingExpired);
    on<GroupChatTypingChanged>(_onOutgoingTyping);

    _wsSubscription = webSocketService.messages.listen((msg) {
      if (msg.type == 'typing') {
        if (msg.groupId != groupId || msg.userId == currentUserId) return;
        add(_GroupTypingChanged(
          msg.userId,
          msg.username ?? 'Someone',
          msg.typing ?? false,
        ));
        return;
      }
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

  /// A peer stops being "typing" this long after their last keystroke, in
  /// case their stop event never arrives (backgrounded app, dropped socket).
  static const Duration _typingTimeout = Duration(seconds: 6);
  final Map<String, Timer> _typingTimers = {};

  /// Throttle outgoing typing pings so we send one per few seconds rather
  /// than one per keystroke.
  DateTime? _lastTypingSent;
  Timer? _stopTypingTimer;

  static const int _pageSize = 50;

  final GroupRepository _groupRepository;
  final WebSocketService _webSocketService;
  final String? _currentUserId;
  StreamSubscription<WsMessage>? _wsSubscription;
  final _uuid = const Uuid();

  @override
  Future<void> close() async {
    // Leaving the screen mid-sentence shouldn't leave us "typing" forever.
    if (_lastTypingSent != null) {
      _sendTyping(false);
    }
    _stopTypingTimer?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    await _wsSubscription?.cancel();
    return super.close();
  }

  void _sendTyping(bool typing) {
    _webSocketService.send({
      'type': 'typing',
      'group_id': state.groupId,
      'typing': typing,
    });
  }

  /// Called as the user types. Sends at most one "typing" every 3s, and an
  /// explicit "stopped" once they pause.
  void _onOutgoingTyping(
    GroupChatTypingChanged event,
    Emitter<GroupChatState> emit,
  ) {
    if (!event.typing) {
      _stopTypingTimer?.cancel();
      if (_lastTypingSent != null) {
        _lastTypingSent = null;
        _sendTyping(false);
      }
      return;
    }

    final now = DateTime.now();
    if (_lastTypingSent == null ||
        now.difference(_lastTypingSent!) > const Duration(seconds: 3)) {
      _lastTypingSent = now;
      _sendTyping(true);
    }
    // Auto-stop shortly after the last keystroke.
    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 4), () {
      _lastTypingSent = null;
      _sendTyping(false);
    });
  }

  void _onTypingChanged(
    _GroupTypingChanged event,
    Emitter<GroupChatState> emit,
  ) {
    final next = Map<String, String>.from(state.typingUsers);
    _typingTimers.remove(event.userId)?.cancel();

    if (event.typing) {
      next[event.userId] = event.username;
      // Safety net: expire the entry if no stop event arrives.
      _typingTimers[event.userId] = Timer(_typingTimeout, () {
        if (!isClosed) add(_GroupTypingExpired(event.userId));
      });
    } else {
      next.remove(event.userId);
    }
    emit(state.copyWith(typingUsers: next));
  }

  void _onTypingExpired(
    _GroupTypingExpired event,
    Emitter<GroupChatState> emit,
  ) {
    if (!state.typingUsers.containsKey(event.userId)) return;
    final next = Map<String, String>.from(state.typingUsers)
      ..remove(event.userId);
    _typingTimers.remove(event.userId)?.cancel();
    emit(state.copyWith(typingUsers: next));
  }

  Future<void> _onStarted(
    GroupChatStarted event,
    Emitter<GroupChatState> emit,
  ) async {
    emit(state.copyWith(loadingInitial: true, clearLoadError: true));
    try {
      final response = await _groupRepository
          .getGroupMessages(state.groupId, limit: _pageSize);
      // Back-out during the fetch closes the bloc; emitting then throws.
      if (isClosed) return;
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
      if (isClosed) return;
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
      // Send-and-immediately-back is common; the reply lands after close.
      if (isClosed) return;
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
      if (isClosed) return;
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
