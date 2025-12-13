import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/gen/assets.gen.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReportDetailsModal extends StatelessWidget {
  final ReportData report;

  const ReportDetailsModal({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(styles.corners.lg),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status bar spacer
          SizedBox(height: topPadding + 4),

          // Drag Handle
          Center(
            child: Container(
              height: 2,
              width: 28,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Content with padding
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: styles.insets.sm,
              vertical: styles.insets.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // Header: Icon + Type + Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getReportColor(report.type).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      _getReportIcon(report.type),
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatReportType(report.type),
                          style: styles.typography.h4.bold,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Reported ${timeago.format(DateTime.parse(report.createdAt))}',
                          style: styles.typography.caption.textColor(Colors.grey[600]!),
                        ),
                      ],
                    ),
                  ),
                  // Thumbs up count (Mocked for now)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.thumb_up_rounded,
                            size: 11, color: styles.theme.primary),
                        const SizedBox(width: 2),
                        Text(
                          '124',
                          style: styles.typography.caption.bold
                              .textColor(styles.theme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Reporter Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.grey[200],
                    child:
                        Icon(Icons.person, size: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reported by ',
                    style: styles.typography.caption,
                  ),
                  Text(
                    report.userId.isNotEmpty
                        ? 'User ${report.userId.substring(0, 4)}'
                        : 'Wazer',
                    style: styles.typography.caption.bold,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // "Still There?" Section
              Text(
                'Is this still there?',
                style: styles.typography.caption.bold,
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.thumb_up_off_alt_rounded,
                      label: 'Yes',
                      color: styles.theme.primary,
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement verify logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thanks for your feedback!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.thumb_down_off_alt_rounded,
                      label: 'Not there',
                      color: Colors.grey[700]!,
                      isOutlined: true,
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: Implement not there logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Thanks for updating the map!')),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatReportType(String type) {
    // Capitalize first letter
    if (type.isEmpty) return 'Report';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  String _getReportIcon(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return Assets.icons.reports.police;
      case 'traffic':
        return Assets.icons.reports.trafic; // Note: typo in asset name 'trafic'
      case 'accident':
        return Assets.icons.reports.accident;
      default:
        return Assets.icons.reports.police; // Fallback
    }
  }

  Color _getReportColor(String type) {
    switch (type.toLowerCase()) {
      case 'police':
        return Colors.blue;
      case 'traffic':
        return Colors.red;
      case 'accident':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isOutlined;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isOutlined = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOutlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(styles.corners.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(styles.corners.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: isOutlined
              ? BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  borderRadius: BorderRadius.circular(styles.corners.sm),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isOutlined ? color : Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: styles.typography.caption.bold.textColor(
                  isOutlined ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
