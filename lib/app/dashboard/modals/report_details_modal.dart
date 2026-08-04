import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/utils/report_expiry.dart';
import 'package:waze_kibris/gen/assets.gen.dart';
import 'package:waze_kibris/app/dashboard/view/report_chat_screen.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(styles.corners.lg),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status bar spacer
          SizedBox(height: topPadding + 4),

          // Drag handle
          Center(
            child: Container(
              height: 3,
              width: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ───────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Colored icon container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: reportColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: reportColor.withOpacity(0.3),
                          width: 1,
                        ),
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

                    // Type + timestamp
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatReportType(report.type),
                            style: styles.typography.h4.bold
                                .textColor(reportColor),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _formatTimestamp(report.createdAt),
                                  style: styles.typography.caption
                                      .textColor(Colors.grey[600]!)
                                      .copyWith(fontStyle: FontStyle.normal),
                                ),
                              ),
                            ],
                          ),
                          if (formatExpiresInLabel(report.expiresAt) != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 12,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    formatExpiresInLabel(report.expiresAt)!,
                                    style: styles.typography.caption
                                        .textColor(Colors.orange[800]!)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Upvote badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: styles.theme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: styles.theme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.thumb_up_rounded,
                            size: 12,
                            color: styles.theme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${report.upvotesCount}',
                            style: styles.typography.caption.bold
                                .textColor(styles.theme.primary)
                                .copyWith(fontStyle: FontStyle.normal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Photo report image ───────────────────────────────────────
                if (report.type.toLowerCase() == 'photosharing' &&
                    report.imageUrl != null &&
                    report.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(styles.corners.sm),
                    child: Image.network(
                      report.imageUrl!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // ── Divider ───────────────────────────────────────────────────
                Divider(color: Colors.grey[100], height: 1),
                const SizedBox(height: 10),

                // ── Reporter info ─────────────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.grey[100],
                      child: Icon(
                        Icons.person_rounded,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reported by ',
                      style: styles.typography.caption
                          .textColor(Colors.grey[500]!)
                          .copyWith(fontStyle: FontStyle.normal),
                    ),
                    Text(
                      report.username != null && report.username!.isNotEmpty
                          ? report.username!
                          : 'Wazer',
                      style: styles.typography.caption.bold
                          .copyWith(fontStyle: FontStyle.normal),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ReportChatScreen(reportId: report.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Discuss this report'),
                  ),
                ),

                const SizedBox(height: 8),

                // ── "Still there?" label ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: reportColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Is this still there?',
                      style: styles.typography.t2.bold.copyWith(
                        decoration: TextDecoration.none,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Vote buttons ──────────────────────────────────────────────
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
                            icon: Icons.thumb_up_rounded,
                            label: 'Yes, still there',
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
                            icon: Icons.thumb_down_rounded,
                            label: 'Not there',
                            color: Colors.grey[700]!,
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
            ),
          ),
        ],
      ),
    );
  }

  String _formatReportType(String type) {
    if (type.isEmpty) return 'Report';
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
      color: isOutlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(styles.corners.sm),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(styles.corners.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: isOutlined
              ? BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  borderRadius: BorderRadius.circular(styles.corners.sm),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
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
                  size: 15,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: styles.typography.caption.bold
                    .textColor(
                      isOutlined ? color : Colors.white,
                    )
                    .copyWith(fontStyle: FontStyle.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
