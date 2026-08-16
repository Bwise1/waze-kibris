import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waze_kibris/core/models/reports/report_chat_message.dart';
import 'package:waze_kibris/core/repositories/report_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

abstract class ReportChatEvent extends Equatable {
  const ReportChatEvent();
  @override
  List<Object?> get props => [];
}

class ReportChatStarted extends ReportChatEvent {
  const ReportChatStarted();
}

class ReportChatSendRequested extends ReportChatEvent {
  const ReportChatSendRequested(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

class ReportChatRetryRequested extends ReportChatEvent {
  const ReportChatRetryRequested(this.localId);
  final String localId;
  @override
  List<Object?> get props => [localId];
}

class _ReportChatIncoming extends ReportChatEvent {
  const _ReportChatIncoming(this.message);
  final ReportChatMessage message;
  @override
  List<Object?> get props => [message];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum ChatSendStatus { sending, sent, failed }

class ReportChatEntry extends Equatable {
  const ReportChatEntry({
    required this.localId,
    required this.message,
    this.status = ChatSendStatus.sent,
  });

  final String localId;
  final ReportChatMessage message;
  final ChatSendStatus status;

  ReportChatEntry copyWith({
    ReportChatMessage? message,
    ChatSendStatus? status,
  }) =>
      ReportChatEntry(
        localId: localId,
        message: message ?? this.message,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [localId, message.id, status];
}

class ReportChatState extends Equatable {
  const ReportChatState({
    required this.reportId,
    this.entries = const [],
    this.loading = true,
    this.loadError,
  });

  final int reportId;

  /// Newest first — rendered into a reversed list.
  final List<ReportChatEntry> entries;
  final bool loading;
  final String? loadError;

  ReportChatState copyWith({
    List<ReportChatEntry>? entries,
    bool? loading,
    String? loadError,
    bool clearError = false,
  }) =>
      ReportChatState(
        reportId: reportId,
        entries: entries ?? this.entries,
        loading: loading ?? this.loading,
        loadError: clearError ? null : (loadError ?? this.loadError),
      );

  @override
  List<Object?> get props => [reportId, entries, loading, loadError];
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

/// One report discussion thread. Same contract as GroupChatBloc: optimistic
/// send with retry, live socket delivery, and incoming messages filtered to
/// this report so other threads can't leak in.
class ReportChatBloc extends Bloc<ReportChatEvent, ReportChatState> {
  ReportChatBloc({
    required int reportId,
    required ReportRepository reportRepository,
    required WebSocketService webSocketService,
    required String? currentUserId,
  })  : _repository = reportRepository,
        _currentUserId = currentUserId,
        super(ReportChatState(reportId: reportId)) {
    on<ReportChatStarted>(_onStarted);
    on<ReportChatSendRequested>(_onSend);
    on<ReportChatRetryRequested>(_onRetry);
    on<_ReportChatIncoming>(_onIncoming);

    _wsSubscription = webSocketService.messages.listen((msg) {
      if (msg.type != 'report_chat' || msg.content == null) return;
      try {
        final json = jsonDecode(msg.content!) as Map<String, dynamic>;
        final message = ReportChatMessage.fromJson(json);
        if (message.reportId == reportId) {
          add(_ReportChatIncoming(message));
        }
      } catch (e) {
        log('ReportChatBloc: bad incoming payload: $e');
      }
    });
  }

  final ReportRepository _repository;
  final String? _currentUserId;
  StreamSubscription<WsMessage>? _wsSubscription;
  int _localSeq = 0;

  @override
  Future<void> close() async {
    await _wsSubscription?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    ReportChatStarted event,
    Emitter<ReportChatState> emit,
  ) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final messages = await _repository.getReportChatMessages(state.reportId);
      // Back-out during the fetch closes the bloc; emitting then throws.
      if (isClosed) return;
      // Server returns newest-first; keep that order for the reversed list.
      final fetched = messages
          .map((m) => ReportChatEntry(localId: 'srv-${m.id}', message: m))
          .toList();
      final pending = state.entries
          .where((e) => e.status != ChatSendStatus.sent)
          .toList();
      emit(state.copyWith(
        entries: [...pending, ...fetched],
        loading: false,
        clearError: true,
      ));
    } catch (e) {
      log('ReportChatBloc: load failed: $e');
      emit(state.copyWith(
        loading: false,
        loadError: state.entries.isEmpty
            ? 'Could not load the discussion. Check your connection.'
            : null,
      ));
    }
  }

  Future<void> _onSend(
    ReportChatSendRequested event,
    Emitter<ReportChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) return;

    final localId = 'local-${_localSeq++}';
    final optimistic = ReportChatEntry(
      localId: localId,
      status: ChatSendStatus.sending,
      message: ReportChatMessage(
        id: -_localSeq, // negative so it can't collide with a server id
        reportId: state.reportId,
        userId: _currentUserId ?? '',
        content: text,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    emit(state.copyWith(entries: [optimistic, ...state.entries]));
    await _deliver(localId, text, emit);
  }

  Future<void> _onRetry(
    ReportChatRetryRequested event,
    Emitter<ReportChatState> emit,
  ) async {
    final entry = _byLocalId(event.localId);
    if (entry == null || entry.status != ChatSendStatus.failed) return;
    _replace(event.localId, entry.copyWith(status: ChatSendStatus.sending),
        emit);
    await _deliver(event.localId, entry.message.content, emit);
  }

  Future<void> _deliver(
    String localId,
    String text,
    Emitter<ReportChatState> emit,
  ) async {
    try {
      final confirmed =
          await _repository.postReportChatMessage(state.reportId, text);
      if (isClosed) return;
      // The socket echo may have landed first.
      final already = state.entries
          .any((e) => e.localId != localId && e.message.id == confirmed.id);
      if (already) {
        emit(state.copyWith(
          entries: state.entries.where((e) => e.localId != localId).toList(),
        ));
        return;
      }
      final entry = _byLocalId(localId);
      if (entry != null) {
        _replace(
          localId,
          entry.copyWith(message: confirmed, status: ChatSendStatus.sent),
          emit,
        );
      }
    } catch (e) {
      log('ReportChatBloc: send failed: $e');
      if (isClosed) return;
      final entry = _byLocalId(localId);
      if (entry != null) {
        _replace(localId, entry.copyWith(status: ChatSendStatus.failed), emit);
      }
    }
  }

  void _onIncoming(
    _ReportChatIncoming event,
    Emitter<ReportChatState> emit,
  ) {
    final incoming = event.message;
    if (state.entries.any((e) => e.message.id == incoming.id)) return;

    // Our own message echoing back before the REST response resolves.
    if (incoming.userId == _currentUserId) {
      final inFlight = state.entries.where((e) =>
          e.status == ChatSendStatus.sending &&
          e.message.content == incoming.content);
      if (inFlight.isNotEmpty) {
        final first = inFlight.first;
        _replace(
          first.localId,
          first.copyWith(message: incoming, status: ChatSendStatus.sent),
          emit,
        );
        return;
      }
    }

    emit(state.copyWith(
      entries: [
        ReportChatEntry(localId: 'srv-${incoming.id}', message: incoming),
        ...state.entries,
      ],
    ));
  }

  ReportChatEntry? _byLocalId(String localId) {
    for (final e in state.entries) {
      if (e.localId == localId) return e;
    }
    return null;
  }

  void _replace(
    String localId,
    ReportChatEntry updated,
    Emitter<ReportChatState> emit,
  ) {
    emit(state.copyWith(
      entries:
          state.entries.map((e) => e.localId == localId ? updated : e).toList(),
    ));
  }
}
