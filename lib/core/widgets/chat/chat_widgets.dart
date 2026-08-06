import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

/// Shared chat furniture used by both the group chat and the per-report
/// discussion, so the two surfaces stay visually identical.

/// Deterministic per-user accent so senders are distinguishable at a glance.
/// Brand red is deliberately absent — it is reserved for the current user's
/// own bubbles.
const List<Color> kSenderPalette = [
  Color(0xFF00639B), // ocean
  Color(0xFF7A5900), // amber-dark
  Color(0xFF37693D), // forest
  Color(0xFF7D5260), // plum
  Color(0xFF00696E), // teal
  Color(0xFF695F00), // olive
];

Color senderColor(String userId) =>
    kSenderPalette[userId.hashCode.abs() % kSenderPalette.length];

bool sameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

String chatTimeLabel(DateTime at) {
  final local = at.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Sender avatar: real profile picture when the user has one (uploaded URL
/// or a preset shipped under assets/user_profiles/), otherwise their initial
/// on a tinted disc.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    required this.userId,
    required this.name,
    this.icon,
    this.radius = 15,
    super.key,
  });

  final String userId;
  final String name;
  final String? icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colour = senderColor(userId);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colour.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: styles.typography.hairline
            .textColor(colour)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );

    final value = icon?.trim();
    if (value == null || value.isEmpty) return fallback;

    // Uploaded pictures are URLs; presets are bare filenames.
    final isUrl = value.startsWith('http://') || value.startsWith('https://');
    return CircleAvatar(
      radius: radius,
      backgroundColor: colour.withValues(alpha: 0.15),
      foregroundImage: isUrl
          ? NetworkImage(value)
          : AssetImage('assets/user_profiles/$value') as ImageProvider,
      // Shown while loading and if the image fails to resolve.
      child: Text(
        initial,
        style: styles.typography.hairline
            .textColor(colour)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// WhatsApp-style "Fred is typing…" / "3 people are typing…" line.
class ChatTypingIndicator extends StatelessWidget {
  const ChatTypingIndicator({required this.names, super.key});

  /// Display names of everyone currently typing.
  final List<String> names;

  String get _label {
    if (names.isEmpty) return '';
    if (names.length == 1) return '${names.first} is typing…';
    if (names.length == 2) {
      return '${names.first} and ${names[1]} are typing…';
    }
    return '${names.length} people are typing…';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: names.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Row(
                children: [
                  const _TypingDots(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _label,
                      overflow: TextOverflow.ellipsis,
                      style: styles.typography.hairline
                          .textColor(styles.theme.ash),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Three dots that pulse in sequence, as in WhatsApp/iMessage.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot a third of a cycle apart.
            final t = (_controller.value - i * 0.2) % 1.0;
            final opacity = t < 0.5 ? 0.35 + t : 0.35 + (1 - t);
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 3),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: styles.theme.ash
                      .withValues(alpha: opacity.clamp(0.3, 1.0)),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// "Today" / "Yesterday" / "12 Mar" pill separating days of conversation.
class ChatDayDivider extends StatelessWidget {
  const ChatDayDivider({required this.date, super.key});
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
    final label = '${day.day} ${months[day.month - 1]}';
    return day.year == now.year ? label : '$label ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(),
            style: styles.typography.hairline
                .textColor(styles.theme.ash)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Honest connection state, driven by the socket rather than a local guess.
class ChatConnectionLabel extends StatelessWidget {
  const ChatConnectionLabel({
    required this.status,
    this.trailing,
    super.key,
  });

  final ValueNotifier<WsStatus> status;

  /// Extra context appended after the state, e.g. "4 members".
  final String? trailing;

  @override
  Widget build(BuildContext context) {
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
            Flexible(
              child: Text(
                trailing == null ? label : '$label · $trailing',
                overflow: TextOverflow.ellipsis,
                style: styles.typography.hairline.textColor(styles.theme.ash),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Round send button that only lights up when there is something to send.
class ChatSendButton extends StatelessWidget {
  const ChatSendButton({
    required this.controller,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    // Only this button listens to the field, so typing never rebuilds the
    // message list.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return AnimatedOpacity(
          opacity: hasText ? 1 : 0.4,
          duration: const Duration(milliseconds: 120),
          child: Material(
            color: styles.theme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: hasText ? onSend : null,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child:
                    Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rounded input field shared by both chat composers.
class ChatComposerField extends StatelessWidget {
  const ChatComposerField({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmitted;

  /// Fires on each keystroke — used to drive typing indicators.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: styles.theme.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: styles.theme.border.withValues(alpha: 0.6)),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: styles.typography.body.textColor(styles.theme.ash),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isCollapsed: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        maxLines: 4,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.send,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

/// Floating "jump to newest" affordance shown once the user scrolls up.
class ChatJumpToLatest extends StatelessWidget {
  const ChatJumpToLatest({
    required this.visible,
    required this.onTap,
    super.key,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.keyboard_double_arrow_down,
                size: 22, color: styles.theme.text),
          ),
        ),
      ),
    );
  }
}

/// Empty-thread state.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: styles.theme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: styles.theme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: styles.typography.t3
                  .textColor(styles.theme.text)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: styles.typography.hairline.textColor(styles.theme.ash),
            ),
          ],
        ),
      ),
    );
  }
}

/// Load / network failure state with a retry affordance.
class ChatErrorState extends StatelessWidget {
  const ChatErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 44, color: styles.theme.nu1),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: styles.typography.body.textColor(styles.theme.body),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// A chat bubble. Shared shape/behaviour; callers supply the content.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    required this.text,
    required this.isMe,
    required this.sentAt,
    required this.firstOfRun,
    required this.lastOfRun,
    required this.senderName,
    required this.senderId,
    this.senderIcon,
    required this.failed,
    required this.sending,
    required this.onRetry,
    required this.onCopy,
    super.key,
  });

  final String text;
  final bool isMe;
  final DateTime sentAt;
  final bool firstOfRun;
  final bool lastOfRun;
  final String senderName;
  final String senderId;
  final String? senderIcon;
  final bool failed;
  final bool sending;
  final VoidCallback onRetry;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final color = senderColor(senderId);
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    final bubbleColor = isMe
        ? (failed
            ? styles.theme.primary.withValues(alpha: 0.55)
            : styles.theme.primary)
        : Colors.white;
    final textColor = isMe ? Colors.white : styles.theme.text;

    final statusIcon = failed
        ? Icons.error_outline_rounded
        : sending
            ? Icons.schedule_rounded
            : Icons.check_rounded;

    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : (lastOfRun ? 4 : 18)),
          bottomRight: Radius.circular(isMe ? (lastOfRun ? 4 : 18) : 18),
        ),
        border: failed
            ? Border.all(color: Theme.of(context).colorScheme.error, width: 1.2)
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
              style: styles.typography.hairline
                  .textColor(color)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
          ],
          Text(text, style: styles.typography.body.textColor(textColor)),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chatTimeLabel(sentAt),
                style: styles.typography.hairline.textColor(
                  isMe
                      ? Colors.white.withValues(alpha: 0.8)
                      : styles.theme.nu1,
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
                  ChatAvatar(
                    userId: senderId,
                    name: senderName,
                    icon: senderIcon,
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
                'Not sent — tap to retry',
                style: styles.typography.hairline
                    .textColor(Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
