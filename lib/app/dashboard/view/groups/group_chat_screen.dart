import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/group_chat/group_chat_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';
import 'package:waze_kibris/core/repositories/group_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

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
            _ConnectionStatusLabel(
              status: context.read<WebSocketService>().status,
              memberCount: widget.group.memberCount,
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
                    child: AnimatedScale(
                      scale: _showJumpToLatest ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _jumpToLatest,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.keyboard_double_arrow_down,
                                size: 22, color: Colors.black87),
                          ),
                        ),
                      ),
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
    final theme = Theme.of(context);

    if (state.loadingInitial && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.loadError != null && state.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 44, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
              const SizedBox(height: 12),
              Text(
                state.loadError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context
                    .read<GroupChatBloc>()
                    .add(const GroupChatStarted()),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.forum_outlined,
                  size: 34, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text('No messages yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Say hi to your group.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
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
            older == null || !_sameDay(older.createdAt, msg.createdAt);
        final firstOfRun = dayChanged ||
            older.userId != msg.userId ||
            msg.createdAt.difference(older.createdAt).inMinutes >= 3;
        final lastOfRun = newer == null ||
            newer.userId != msg.userId ||
            newer.createdAt.difference(msg.createdAt).inMinutes >= 3;

        final bubble = _MessageBubble(
          entry: entry,
          isMe: widget.currentUserId != null &&
              msg.userId == widget.currentUserId,
          firstOfRun: firstOfRun,
          lastOfRun: lastOfRun,
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
          if (dayChanged) _DayDivider(date: msg.createdAt),
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
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _msgController,
                  decoration: const InputDecoration(
                    hintText: 'Message your group…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Only the button listens to the text — typing never rebuilds
            // the message list.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _msgController,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return AnimatedOpacity(
                  opacity: hasText ? 1 : 0.4,
                  duration: const Duration(milliseconds: 120),
                  child: Material(
                    color: theme.colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: hasText ? _send : null,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                );
              },
            ),
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

/// Honest connection indicator driven by the socket's actual state.
class _ConnectionStatusLabel extends StatelessWidget {
  const _ConnectionStatusLabel({
    required this.status,
    required this.memberCount,
  });

  final ValueNotifier<WsStatus> status;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<WsStatus>(
      valueListenable: status,
      builder: (context, value, _) {
        final (color, label) = switch (value) {
          WsStatus.connected => (const Color(0xFF00A650), 'Live'),
          WsStatus.connecting => (const Color(0xFFFFA000), 'Connecting…'),
          WsStatus.reconnecting => (const Color(0xFFFFA000), 'Reconnecting…'),
          WsStatus.disconnected => (const Color(0xFF9E9E9E), 'Offline'),
        };
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              memberCount > 0 ? '$label · $memberCount members' : label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});
  final DateTime date;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final label = '${months[day.month - 1]} ${day.day}';
    return day.year == now.year ? label : '$label ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: color.withValues(alpha: 0.35))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'New',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: color.withValues(alpha: 0.35))),
        ],
      ),
    );
  }
}

/// Deterministic per-user accent so different senders are telling-apart-able
/// at a glance without clashing with the brand red reserved for "me".
const List<Color> _senderPalette = [
  Color(0xFF00639B), // ocean
  Color(0xFF7A5900), // amber-dark
  Color(0xFF37693D), // forest
  Color(0xFF7D5260), // plum
  Color(0xFF00696E), // teal
  Color(0xFF695F00), // olive
];

Color _senderColor(String userId) =>
    _senderPalette[userId.hashCode.abs() % _senderPalette.length];

String _senderFallbackName(String userId) =>
    userId.length >= 4 ? 'User ${userId.substring(0, 4)}' : 'User';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.entry,
    required this.isMe,
    required this.firstOfRun,
    required this.lastOfRun,
    required this.onRetry,
    required this.onCopy,
  });

  final ChatEntry entry;
  final bool isMe;
  final bool firstOfRun;
  final bool lastOfRun;
  final VoidCallback onRetry;
  final VoidCallback onCopy;

  String _timeLabel(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = entry.message;
    final failed = entry.status == ChatSendStatus.failed;
    final senderName = msg.senderUsername?.isNotEmpty == true
        ? msg.senderUsername!
        : _senderFallbackName(msg.userId);
    final senderColor = _senderColor(msg.userId);
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    final bubbleColor = isMe
        ? (failed
            ? theme.colorScheme.primary.withValues(alpha: 0.55)
            : theme.colorScheme.primary)
        : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;

    final radius = BorderRadius.only(
      topLeft: Radius.circular(!isMe && firstOfRun ? 18 : 18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : (lastOfRun ? 4 : 18)),
      bottomRight: Radius.circular(isMe ? (lastOfRun ? 4 : 18) : 18),
    );

    final statusIcon = switch (entry.status) {
      ChatSendStatus.sending => Icons.schedule_rounded,
      ChatSendStatus.sent => Icons.check_rounded,
      ChatSendStatus.failed => Icons.error_outline_rounded,
    };

    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
        border: failed
            ? Border.all(color: theme.colorScheme.error, width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe && firstOfRun) ...[
            Text(
              senderName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: senderColor,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            msg.content,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _timeLabel(msg.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  statusIcon,
                  size: 13,
                  color: failed
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    bubble = GestureDetector(
      onTap: failed ? onRetry : null,
      onLongPress: onCopy,
      child: bubble,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: lastOfRun ? 10 : 2),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                if (lastOfRun)
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: senderColor.withValues(alpha: 0.15),
                    child: Text(
                      senderName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        color: senderColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 30),
                const SizedBox(width: 8),
              ],
              Flexible(child: bubble),
            ],
          ),
          if (failed)
            Padding(
              padding: EdgeInsets.only(top: 3, right: isMe ? 4 : 0),
              child: Text(
                'Not sent — tap the message to retry',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}
