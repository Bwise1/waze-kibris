import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/group_chat/group_chat_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';
import 'package:waze_kibris/core/repositories/group_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';
import 'package:waze_kibris/core/widgets/chat/chat_widgets.dart';

const String _nilUuid = '00000000-0000-0000-0000-000000000000';

bool _isValidGroupId(String id) =>
    id.isNotEmpty && id.toLowerCase() != _nilUuid;

/// One group conversation. Chat state is owned by a screen-scoped
/// [GroupChatBloc], so nothing that happens elsewhere in the app (list
/// refreshes, invite errors…) can disturb an open conversation.
class GroupChatScreen extends StatelessWidget {
  const GroupChatScreen({required this.group, super.key});
  final CommunityGroup group;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId =
        authState is AuthSuccess ? authState.user?.id : null;

    return BlocProvider<GroupChatBloc>(
      create: (context) => GroupChatBloc(
        groupId: group.id,
        groupRepository: context.read<GroupRepository>(),
        webSocketService: context.read<WebSocketService>(),
        currentUserId: currentUserId,
      )..add(const GroupChatStarted()),
      child: _GroupChatView(group: group, currentUserId: currentUserId),
    );
  }
}

class _GroupChatView extends StatefulWidget {
  const _GroupChatView({required this.group, required this.currentUserId});
  final CommunityGroup group;
  final String? currentUserId;

  @override
  State<_GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends State<_GroupChatView> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _clockTimer;
  bool _showJumpToLatest = false;
  GroupsBloc? _groupsBloc;

  @override
  void initState() {
    super.initState();
    _groupsBloc = context.read<GroupsBloc>();

    if (_isValidGroupId(widget.group.id)) {
      // Clear the unread badge both entering and leaving the conversation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _groupsBloc?.add(MarkGroupReadRequested(widget.group.id));
        }
      });
    }

    _scrollController.addListener(_onScroll);
    // Relative timestamps ("2m ago") drift; refresh them once a minute.
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (_isValidGroupId(widget.group.id)) {
      _groupsBloc?.add(MarkGroupReadRequested(widget.group.id));
    }
    _clockTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Reverse list: offset 0 is the newest message at the bottom.
    final away = position.pixels > 320;
    if (away != _showJumpToLatest) {
      setState(() => _showJumpToLatest = away);
    }
    // Nearing the top (oldest loaded message) — pull the previous page.
    if (position.pixels > position.maxScrollExtent - 400) {
      context.read<GroupChatBloc>().add(const GroupChatOlderRequested());
    }
  }

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    context.read<GroupChatBloc>().add(GroupChatSendRequested(text));
    _msgController.clear();
    // A message you just sent should always be visible.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _jumpToLatest() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isValidGroupId(widget.group.id)) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.group.name)),
        body: const Center(child: Text('This group is unavailable.')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            ChatConnectionLabel(
              status: context.read<WebSocketService>().status,
              trailing: widget.group.memberCount > 0
                  ? '${widget.group.memberCount} members'
                  : null,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Invite by email',
            onPressed: () => _showInviteDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Group info',
            onPressed: () => _showGroupInfoSheet(context),
          ),
        ],
      ),
      body: BlocListener<GroupsBloc, GroupsState>(
        listenWhen: (prev, curr) =>
            curr is GroupActionSuccess || curr is GroupsError,
        listener: (context, state) {
          // Feedback for invites sent from this screen; errors no longer
          // touch the conversation itself.
          if (state is GroupActionSuccess &&
              state.message.toLowerCase().contains('invitation')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  BlocBuilder<GroupChatBloc, GroupChatState>(
                    builder: (context, state) => _buildMessages(context, state),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: ChatJumpToLatest(
                      visible: _showJumpToLatest,
                      onTap: _jumpToLatest,
                    ),
                  ),
                ],
              ),
            ),
            _buildComposer(context, theme),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Message list
  // -------------------------------------------------------------------------

  Widget _buildMessages(BuildContext context, GroupChatState state) {
    if (state.loadingInitial && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.loadError != null && state.entries.isEmpty) {
      return ChatErrorState(
        message: state.loadError!,
        onRetry: () =>
            context.read<GroupChatBloc>().add(const GroupChatStarted()),
      );
    }

    if (state.entries.isEmpty) {
      return const ChatEmptyState(
        icon: Icons.forum_outlined,
        title: 'No messages yet',
        subtitle: 'Say hi to your group.',
      );
    }

    final entries = state.entries;
    final lastReadAt = widget.group.lastReadAt;
    final unreadDividerIndex =
        widget.group.unreadCount > 0 && lastReadAt != null
            ? entries.lastIndexWhere((e) =>
                e.message.createdAt.isAfter(lastReadAt) &&
                e.message.userId != widget.currentUserId)
            : -1;

    // +1 slot at the very top for the "loading older" spinner.
    final itemCount = entries.length + (state.loadingOlder ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= entries.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final entry = entries[index];
        final msg = entry.message;
        final older = index + 1 < entries.length
            ? entries[index + 1].message
            : null;
        final newer = index > 0 ? entries[index - 1].message : null;

        final dayChanged =
            older == null || !sameDay(older.createdAt, msg.createdAt);
        final firstOfRun = dayChanged ||
            older.userId != msg.userId ||
            msg.createdAt.difference(older.createdAt).inMinutes >= 3;
        final lastOfRun = newer == null ||
            newer.userId != msg.userId ||
            newer.createdAt.difference(msg.createdAt).inMinutes >= 3;

        final bubble = ChatBubble(
          text: msg.content,
          isMe: widget.currentUserId != null &&
              msg.userId == widget.currentUserId,
          sentAt: msg.createdAt,
          firstOfRun: firstOfRun,
          lastOfRun: lastOfRun,
          senderName: msg.senderUsername?.isNotEmpty == true
              ? msg.senderUsername!
              : (msg.userId.length >= 4
                  ? 'User ${msg.userId.substring(0, 4)}'
                  : 'User'),
          senderId: msg.userId,
          failed: entry.status == ChatSendStatus.failed,
          sending: entry.status == ChatSendStatus.sending,
          onRetry: () => context
              .read<GroupChatBloc>()
              .add(GroupChatRetryRequested(entry.localId)),
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

        // Widgets above the bubble (rendered higher on screen).
        final decorations = <Widget>[
          if (dayChanged) ChatDayDivider(date: msg.createdAt),
          if (unreadDividerIndex >= 0 && index == unreadDividerIndex)
            const _NewMessagesDivider(),
        ];

        if (decorations.isEmpty) return bubble;
        return Column(children: [...decorations, bubble]);
      },
    );
  }

  // -------------------------------------------------------------------------
  // Composer
  // -------------------------------------------------------------------------

  Widget _buildComposer(BuildContext context, ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ChatComposerField(
                controller: _msgController,
                hintText: 'Message your group…',
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: 8),
            ChatSendButton(controller: _msgController, onSend: _send),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Dialogs / sheets
  // -------------------------------------------------------------------------

  void _showInviteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Invite to group'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'Enter member email',
            ),
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final email = controller.text.trim();
                if (email.isEmpty) return;
                Navigator.pop(dialogContext);
                context.read<GroupsBloc>().add(CreateInviteRequested(
                      groupId: widget.group.id,
                      invitedUserEmail: email,
                    ));
              },
              child: const Text('Send invite'),
            ),
          ],
        );
      },
    ).then(
      // Dispose after the dialog's exit animation is done with the field.
      (_) => Future<void>.delayed(
        const Duration(milliseconds: 400),
        controller.dispose,
      ),
    );
  }

  void _showGroupInfoSheet(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(group.name, style: theme.textTheme.titleLarge),
                if (group.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    group.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.group_outlined,
                        size: 18,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Text(
                      '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Join code — the fastest way to grow a group.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join code',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            Text(
                              group.shortCode,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy join code',
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: group.shortCode));
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Join code copied')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------


/// Marks where the user's unread messages begin.
class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider();

  @override
  Widget build(BuildContext context) {
    final color = styles.theme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: color.withValues(alpha: 0.35))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'New',
              style: styles.typography.hairline
                  .textColor(color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Divider(color: color.withValues(alpha: 0.35))),
        ],
      ),
    );
  }
}
