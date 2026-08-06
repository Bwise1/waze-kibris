import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/repositories/report_repository.dart';
import 'package:waze_kibris/core/services/place_label_service.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';
import 'package:waze_kibris/core/utils/report_expiry.dart';
import 'package:waze_kibris/gen/assets.gen.dart';
import 'package:waze_kibris/app/dashboard/view/report_chat_screen.dart';

/// Waze-style report card that drops in from the top of the map.
///
/// Layout priority, top to bottom: what it is → how fresh it is → who said so
/// → confirm or dismiss it. The confirm/dismiss pair is the whole point of
/// the card, so it sits last and reads as the primary action.
class ReportDetailsModal extends StatelessWidget {
  final ReportData report;

  const ReportDetailsModal({
    super.key,
    required this.report,
  });

  // ── Exact timestamp with smart fallback ───────────────────────────────────

  String _formatTimestamp(String createdAt) {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) {
        return 'Just now';
      } else if (diff.inMinutes < 60) {
        final m = diff.inMinutes;
        return '$m min${m == 1 ? '' : 's'} ago';
      } else if (diff.inHours < 24) {
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        return m == 0 ? '$h hr${h == 1 ? '' : 's'} ago' : '$h hr ${m}m ago';
      } else {
        // Show exact date/time for older reports
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$day/$month at $hour:$minute';
      }
    } catch (_) {
      return 'Unknown time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final reportColor = _getReportColor(report.type);
    final expiresLabel = formatExpiresInLabel(report.expiresAt);
    final isPhoto = report.type.toLowerCase() == 'photosharing' &&
        report.imageUrl != null &&
        report.imageUrl!.isNotEmpty;

    final authState = context.read<AuthBloc>().state;
    final currentUserId =
        authState is AuthSuccess ? authState.user?.id : null;
    final isMine = currentUserId != null && report.userId == currentUserId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(styles.corners.lg),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding + 6),

          // ── Header: icon, type, freshness, confirmations ────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: reportColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      _getReportIcon(report.type),
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatReportType(report.type),
                        style: styles.typography.h4
                            .textColor(styles.theme.text)
                            .copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 2),
                      // Where it is — the one thing that tells two reports of
                      // the same type apart.
                      _PlaceLabel(
                        latitude: report.latitude,
                        longitude: report.longitude,
                      ),
                      const SizedBox(height: 3),
                      // Time and expiry on one line: both answer "is this
                      // still worth trusting?", so they belong together.
                      Row(
                        children: [
                          Text(
                            _formatTimestamp(report.createdAt),
                            style: styles.typography.hairline
                                .textColor(styles.theme.ash),
                          ),
                          if (expiresLabel != null) ...[
                            Text(
                              '  ·  ',
                              style: styles.typography.hairline
                                  .textColor(styles.theme.nu1),
                            ),
                            Flexible(
                              child: Text(
                                expiresLabel,
                                overflow: TextOverflow.ellipsis,
                                style: styles.typography.hairline
                                    .textColor(styles.theme.ash),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ConfirmationCount(count: report.upvotesCount),
              ],
            ),
          ),

          if (isPhoto) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  report.imageUrl!,
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 170,
                      color: styles.theme.nu3,
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    height: 170,
                    color: styles.theme.nu3,
                    child: Icon(Icons.broken_image_outlined,
                        size: 40, color: styles.theme.nu1),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Reporter + discussion, on one quiet line ────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: styles.theme.nu3,
                  child: Icon(Icons.person_rounded,
                      size: 13, color: styles.theme.ash),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: styles.typography.hairline
                          .textColor(styles.theme.ash),
                      children: [
                        const TextSpan(text: 'Reported by '),
                        TextSpan(
                          text: report.username?.isNotEmpty == true
                              ? report.username!
                              : 'Wazer',
                          style: styles.typography.hairline
                              .textColor(styles.theme.body)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Secondary action: available, but never competing with the
                // vote buttons below.
                _DiscussButton(
                  reportId: report.id,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReportChatScreen(
                          reportId: report.id,
                          reportLabel: _formatReportType(report.type),
                          latitude: report.latitude,
                          longitude: report.longitude,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── The ask ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: BoxDecoration(
              color: styles.theme.nu3.withValues(alpha: 0.6),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(styles.corners.lg),
              ),
            ),
            child: isMine ? _buildOwnerStatus() : _buildVotePrompt(),
          ),
        ],
      ),
    );
  }

  /// Owners can't confirm their own report — they already asserted it exists,
  /// and self-votes would let one person inflate a report's credibility or
  /// resolve it single-handedly. The backend rejects them too; this just
  /// avoids offering an action that would fail.
  Widget _buildOwnerStatus() {
    final confirmed = report.upvotesCount;
    return Row(
      children: [
        Icon(Icons.person_pin_circle_rounded,
            size: 18, color: styles.theme.ash),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            confirmed > 0
                ? 'Your report · confirmed by $confirmed '
                    '${confirmed == 1 ? 'driver' : 'drivers'}'
                : 'Your report · waiting for confirmations',
            style: styles.typography.hairline.textColor(styles.theme.body),
          ),
        ),
      ],
    );
  }

  Widget _buildVotePrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Is this still there?',
          style: styles.typography.t3
              .textColor(styles.theme.text)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        BlocConsumer<ReportsBloc, ReportState>(
          listener: (context, state) {
            if (state is VoteReportSuccess) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: styles.theme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            } else if (state is ReportError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is ReportLoading;
            return Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.check_rounded,
                    label: 'Still there',
                    color: styles.theme.primary,
                    isLoading: isLoading,
                    onPressed: () {
                      context.read<ReportsBloc>().add(
                            ReportsEvent.voteOnReport(
                              reportID: report.id,
                              reportType: 'upvote',
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.close_rounded,
                    label: 'Gone',
                    color: styles.theme.body,
                    isOutlined: true,
                    isLoading: isLoading,
                    onPressed: () {
                      context.read<ReportsBloc>().add(
                            ReportsEvent.voteOnReport(
                              reportID: report.id,
                              reportType: 'downvote',
                            ),
                          );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatReportType(String type) {
    if (type.isEmpty) return 'Report';
    if (type.toLowerCase() == 'photosharing') return 'Photo';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  String _getReportIcon(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return Assets.icons.reports.police;
      case 'traffic':
        return Assets.icons.reports.trafic;
      case 'accident':
        return Assets.icons.reports.accident;
      case 'photosharing':
        return Assets.icons.reports.sending;
      default:
        return Assets.icons.reports.police;
    }
  }

  Color _getReportColor(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return Colors.blue[700]!;
      case 'traffic':
        return Colors.red[600]!;
      case 'accident':
        return Colors.orange[700]!;
      case 'photosharing':
        return Colors.purple[700]!;
      default:
        return Colors.grey;
    }
  }
}

/// Street/area for a report, resolved lazily. Renders nothing until (and
/// unless) a label is available, so the header never shows a placeholder or
/// jumps in height for a failed lookup.
class _PlaceLabel extends StatefulWidget {
  const _PlaceLabel({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;

  @override
  State<_PlaceLabel> createState() => _PlaceLabelState();
}

class _PlaceLabelState extends State<_PlaceLabel> {
  String? _label;

  @override
  void initState() {
    super.initState();
    PlaceLabelService.shortLabel(widget.latitude, widget.longitude)
        .then((label) {
      if (mounted && label != null) setState(() => _label = label);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _label;
    if (label == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(Icons.place_outlined, size: 13, color: styles.theme.ash),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: styles.typography.hairline
                .textColor(styles.theme.body)
                .copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// How many drivers have confirmed this report. Reads as social proof, so it
/// only turns brand-red once someone has actually confirmed.
class _ConfirmationCount extends StatelessWidget {
  const _ConfirmationCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final hasVotes = count > 0;
    final color = hasVotes ? styles.theme.primary : styles.theme.ash;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_rounded, size: 20, color: color),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: styles.typography.hairline
              .textColor(color)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Opens the per-report thread. Shows how many drivers have already commented
/// so the button says whether there's anything to read — "Discuss" alone gave
/// no hint that a conversation existed.
class _DiscussButton extends StatefulWidget {
  const _DiscussButton({required this.reportId, required this.onTap});
  final int reportId;
  final VoidCallback onTap;

  @override
  State<_DiscussButton> createState() => _DiscussButtonState();
}

class _DiscussButtonState extends State<_DiscussButton> {
  int? _count;
  StreamSubscription<WsMessage>? _wsSub;

  @override
  void initState() {
    super.initState();
    _loadCount();
    // Keep the count live while the card is open, so a reply arriving now
    // is reflected immediately.
    _wsSub = context.read<WebSocketService>().messages.listen((msg) {
      if (msg.type != 'report_chat' || msg.content == null) return;
      try {
        final json = jsonDecode(msg.content!) as Map<String, dynamic>;
        if ((json['report_id'] as num?)?.toInt() != widget.reportId) return;
        if (mounted) setState(() => _count = (_count ?? 0) + 1);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCount() async {
    try {
      final messages = await context
          .read<ReportRepository>()
          .getReportChatMessages(widget.reportId);
      if (mounted) setState(() => _count = messages.length);
    } catch (_) {
      // Count is a nicety; the button still works without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _count ?? 0;
    final hasMessages = count > 0;
    final color =
        hasMessages ? styles.theme.primary : styles.theme.ash;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasMessages
              ? styles.theme.secondary.withValues(alpha: 0.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasMessages ? Colors.transparent : styles.theme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              hasMessages ? 'Discuss · $count' : 'Discuss',
              style: styles.typography.hairline
                  .textColor(color)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isOutlined = false,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOutlined ? Colors.white : color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: isOutlined
              ? BoxDecoration(
                  border: Border.all(color: styles.theme.border),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOutlined ? color : Colors.white,
                    ),
                  ),
                )
              else
                Icon(
                  icon,
                  color: isOutlined ? color : Colors.white,
                  size: 18,
                ),
              const SizedBox(width: 7),
              Text(
                label,
                style: styles.typography.t3
                    .textColor(isOutlined ? color : Colors.white)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
