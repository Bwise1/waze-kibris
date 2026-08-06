import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/report_chat/report_chat_bloc.dart';
import 'package:waze_kibris/core/repositories/report_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';
import 'package:waze_kibris/core/widgets/chat/chat_widgets.dart';

/// Per-report discussion thread — live over the socket, same look and
/// behaviour as group chat.
class ReportChatScreen extends StatelessWidget {
  const ReportChatScreen({
    super.key,
    required this.reportId,
    this.reportLabel,
  });

  final int reportId;

  /// e.g. "Traffic" — shown in the title so the thread has context.
  final String? reportLabel;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthSuccess ? authState.user?.id : null;

    return BlocProvider<ReportChatBloc>(
      create: (context) => ReportChatBloc(
        reportId: reportId,
        reportRepository: context.read<ReportRepository>(),
        webSocketService: context.read<WebSocketService>(),
        currentUserId: currentUserId,
      )..add(const ReportChatStarted()),
      child: _ReportChatView(
        reportId: reportId,
        reportLabel: reportLabel,
        currentUserId: currentUserId,
      ),
    );
  }
}

class _ReportChatView extends StatefulWidget {
  const _ReportChatView({
    required this.reportId,
    required this.reportLabel,
    required this.currentUserId,
  });

  final int reportId;
  final String? reportLabel;
  final String? currentUserId;

  @override
  State<_ReportChatView> createState() => _ReportChatViewState();
}

class _ReportChatViewState extends State<_ReportChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _clock;
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Keeps relative labels honest without rebuilding on every frame.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final away = _scroll.position.pixels > 320;
    if (away != _showJump) setState(() => _showJump = away);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ReportChatBloc>().add(ReportChatSendRequested(text));
    _controller.clear();
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.reportLabel;
    return Scaffold(
      backgroundColor: styles.theme.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label == null ? 'Report discussion' : '$label discussion',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            ChatConnectionLabel(
              status: context.read<WebSocketService>().status,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                BlocBuilder<ReportChatBloc, ReportChatState>(
                  builder: (context, state) => _buildList(context, state),
                ),
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: ChatJumpToLatest(
                    visible: _showJump,
                    onTap: () => _scroll.animateTo(
                      0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ChatComposerField(
                      controller: _controller,
                      hintText: 'Is it still there?',
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChatSendButton(controller: _controller, onSend: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, ReportChatState state) {
    if (state.loading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.loadError != null && state.entries.isEmpty) {
      return ChatErrorState(
        message: state.loadError!,
        onRetry: () =>
            context.read<ReportChatBloc>().add(const ReportChatStarted()),
      );
    }

    if (state.entries.isEmpty) {
      return const ChatEmptyState(
        icon: Icons.forum_outlined,
        title: 'No replies yet',
        subtitle: 'Ask if this is still there, or add what you can see.',
      );
    }

    final entries = state.entries;
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final msg = entry.message;
        final older =
            index + 1 < entries.length ? entries[index + 1].message : null;
        final newer = index > 0 ? entries[index - 1].message : null;

        final dayChanged =
            older == null || !sameDay(older.sentAt, msg.sentAt);
        final firstOfRun = dayChanged ||
            older.userId != msg.userId ||
            msg.sentAt.difference(older.sentAt).inMinutes >= 3;
        final lastOfRun = newer == null ||
            newer.userId != msg.userId ||
            newer.sentAt.difference(msg.sentAt).inMinutes >= 3;

        final bubble = ChatBubble(
          text: msg.content,
          isMe: widget.currentUserId != null &&
              msg.userId == widget.currentUserId,
          sentAt: msg.sentAt,
          firstOfRun: firstOfRun,
          lastOfRun: lastOfRun,
          senderName: msg.username?.isNotEmpty == true ? msg.username! : 'Wazer',
          senderId: msg.userId,
          failed: entry.status == ChatSendStatus.failed,
          sending: entry.status == ChatSendStatus.sending,
          onRetry: () => context
              .read<ReportChatBloc>()
              .add(ReportChatRetryRequested(entry.localId)),
          onCopy: () {
            Clipboard.setData(ClipboardData(text: msg.content));
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message copied'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        );

        if (dayChanged) {
          return Column(
            children: [ChatDayDivider(date: msg.sentAt), bubble],
          );
        }
        return bubble;
      },
    );
  }
}
