import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({required this.group, super.key});
  final CommunityGroup group;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

const String _nilUuid = '00000000-0000-0000-0000-000000000000';

bool _isValidGroupId(String id) =>
    id.isNotEmpty && id.toLowerCase() != _nilUuid;

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  String? _wsUserId;
  double _wsLat = 0;
  double _wsLng = 0;
  bool _wsSubscriptionReady = false;
  WebSocketService? _webSocketService;
  bool _hasRequestedMessages = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _webSocketService ??= context.read<WebSocketService>();
    // Request messages when we have context; only if no cache and not yet requested
    if (_isValidGroupId(widget.group.id) && !_hasRequestedMessages) {
      final state = context.read<GroupsBloc>().state;
      final hasCachedMessages = state is GetGroupMessagesSuccess &&
          state.groupId == widget.group.id;
      if (!hasCachedMessages) {
        _hasRequestedMessages = true;
        context.read<GroupsBloc>().add(GetGroupMessagesRequested(widget.group.id));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_isValidGroupId(widget.group.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid group. Please try another.')),
          );
          setState(() => _wsSubscriptionReady = true);
        }
      });
      return;
    }

    // Mark as read when opening the chat so backend can clear unread counts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GroupsBloc>().add(MarkGroupReadRequested(widget.group.id));
    });

    _subscribeToGroup();
    // Fallback: if didChangeDependencies didn't request (e.g. had cache), mark so we don't double-request
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hasRequestedMessages) return;
      final state = context.read<GroupsBloc>().state;
      final hasCachedMessages = state is GetGroupMessagesSuccess &&
          state.groupId == widget.group.id;
      if (!hasCachedMessages) {
        _hasRequestedMessages = true;
        context.read<GroupsBloc>().add(GetGroupMessagesRequested(widget.group.id));
      }
    });
  }

  Future<void> _subscribeToGroup() async {
    if (!_isValidGroupId(widget.group.id)) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess || authState.user == null) {
      if (mounted) setState(() => _wsSubscriptionReady = true);
      return;
    }
    final userId = authState.user!.id;
    final position = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition();
    if (!mounted) return;
    final lat = position.latitude;
    final lng = position.longitude;
    final ws = _webSocketService ?? context.read<WebSocketService>();
    ws.updateSubscription(
          userId: userId,
          latitude: lat,
          longitude: lng,
          activeGroupIDs: [widget.group.id],
        );
    if (mounted) {
      setState(() {
        _wsUserId = userId;
        _wsLat = lat;
        _wsLng = lng;
        _wsSubscriptionReady = true;
      });
    }
  }

  void _clearGroupSubscription() {
    if (_wsUserId == null) return;
    _webSocketService?.updateSubscription(
          userId: _wsUserId!,
          latitude: _wsLat,
          longitude: _wsLng,
          activeGroupIDs: [],
        );
  }

  void _sendMessage() {
    if (!_isValidGroupId(widget.group.id)) return;
    final text = _msgController.text.trim();
    if (text.isNotEmpty) {
      context.read<GroupsBloc>().add(
            SendGroupMessageRequested(
              groupId: widget.group.id,
              content: text,
              messageType: 'text',
            ),
          );
      _msgController.clear();
    }
  }

  @override
  void dispose() {
    _clearGroupSubscription();
    _msgController.dispose();
    super.dispose();
  }

  String _formatMessageTime(DateTime at) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${at.month}/${at.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final currentUserId = context.watch<AuthBloc>().state is AuthSuccess
        ? (context.read<AuthBloc>().state as AuthSuccess).user?.id
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.group.name),
            const SizedBox(height: 2),
            Text(
              !_wsSubscriptionReady ? 'Connecting…' : 'Active',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Invite by email',
            onPressed: () => _showInviteDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: show group info
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<GroupsBloc, GroupsState>(
              buildWhen: (prev, curr) =>
                  curr is GetGroupMessagesSuccess ||
                  curr is GroupsError ||
                  (curr is GroupsLoading && prev is! GetGroupMessagesSuccess),
              builder: (context, state) {
                if (state is GroupsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is GroupsError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              context.read<GroupsBloc>().add(
                                    GetGroupMessagesRequested(widget.group.id),
                                  );
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (state is GetGroupMessagesSuccess &&
                    state.groupId == widget.group.id) {
                  final messages = state.messages;
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }
                  final lastReadAt = widget.group.lastReadAt;
                  final shouldShowNewDivider =
                      widget.group.unreadCount > 0 && lastReadAt != null;
                  final dividerIndex = shouldShowNewDivider
                      ? messages.lastIndexWhere((m) =>
                          m.createdAt.isAfter(lastReadAt) &&
                          (currentUserId == null || m.userId != currentUserId))
                      : -1;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = currentUserId != null && msg.userId == currentUserId;
                      final sideBubbleMaxWidth =
                          MediaQuery.of(context).size.width *
                              (isMe ? 0.82 : 0.68);
                      final senderName = isMe
                          ? 'You'
                          : (msg.senderUsername?.isNotEmpty == true
                              ? msg.senderUsername!
                              : _senderDisplayName(msg.userId));
                      final messageTime = _formatMessageTime(msg.createdAt);
                      final timeTextColor = isMe
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.55);

                      Widget bubble = Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment:
                              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: primary.withValues(alpha: 0.2),
                                child: Text(
                                  senderName.isNotEmpty
                                      ? senderName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxWidth: sideBubbleMaxWidth),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.red : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                                      bottomRight: Radius.circular(isMe ? 4 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 52, bottom: 14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isMe) ...[
                                              Text(
                                                senderName,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                            ],
                                            Text(
                                              msg.content,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color:
                                                    isMe ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Text(
                                          messageTime,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontSize: 11,
                                            color: timeTextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isMe) const SizedBox(width: 8),
                          ],
                        ),
                      );

                      if (dividerIndex >= 0 && index == dividerIndex) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color: theme.dividerColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '----------- new message ------',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Divider(
                                      thickness: 1,
                                      color: theme.dividerColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            bubble,
                          ],
                        );
                      }

                      return bubble;
                    },
                  );
                }
                return const Center(child: Text('Loading messages...'));
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: theme.cardColor,
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () {
                              // TODO: attach file / image
                            },
                            icon: const Icon(Icons.attach_file),
                            color: theme.iconTheme.color,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _msgController,
                              decoration: const InputDecoration(
                                hintText: 'Message commuters...',
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              maxLines: 4,
                              minLines: 1,
                              onChanged: (_) {
                                // trigger rebuild for send/mic icon
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: FloatingActionButton(
                      onPressed: _wsSubscriptionReady ? _sendMessage : null,
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      child: Icon(
                        _msgController.text.trim().isEmpty
                            ? Icons.mic_rounded
                            : Icons.send_rounded,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _senderDisplayName(String userId) {
    // TODO: resolve from cache or API; for now use short id
    if (userId.length >= 8) {
      return 'User ${userId.substring(0, 8)}';
    }
    return 'User';
  }

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
    );
  }
}
