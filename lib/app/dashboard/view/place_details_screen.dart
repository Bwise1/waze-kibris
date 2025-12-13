import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:waze_kibris/app/dashboard/view/route_bar.dart';
import 'package:waze_kibris/common.dart';

class RouteBar extends StatelessWidget {
  final String start;
  final String end;
  final VoidCallback onCancel;

  const RouteBar({
    required this.start,
    required this.end,
    required this.onCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(32),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _dot(start, Colors.red),
              const SizedBox(width: 8),
              Text(start, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Expanded(
                child: Divider(
                  color: Colors.grey,
                  thickness: 1,
                  indent: 0,
                  endIndent: 0,
                ),
              ),
              const SizedBox(width: 8),
              _dot(end, Colors.red),
              const SizedBox(width: 8),
              Text(getInitials(end),
                  style: const TextStyle(fontWeight: FontWeight.bold)),

              // IconButton(
              //   icon: const Icon(Icons.close),
              //   onPressed: onCancel,
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(String label, Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class PlaceDetailsSheet extends StatelessWidget {
  const PlaceDetailsSheet({
    required this.title,
    required this.address,
    required this.distanceKm,
    required this.onSave,
    required this.onShare,
    required this.onMore,
    required this.onSeeAllRoutes,
    this.info,
    this.isLoading = false,
    super.key,
    this.showOnlySaveShareAction = false,
  });
  final String title;
  final String address;
  final double distanceKm;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onSeeAllRoutes;
  final String? info;
  final bool isLoading;
  final bool showOnlySaveShareAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                Text(
                  '${_formatDistance(distanceKm)} km away',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              address,
              style: const TextStyle(color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _actionButton(Icons.save, "Save", onSave),
                _actionButton(Icons.share, "Share", onShare),
                _actionButton(Icons.more_horiz, "More", onMore),
              ],
            ),
            if (info != null && showOnlySaveShareAction == false) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: styles.theme.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: styles.theme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      info!,
                      style: TextStyle(color: styles.theme.primary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (showOnlySaveShareAction == false) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onSeeAllRoutes,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "See all routes",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      if (isLoading) ...[
                        Gap(20),
                        const CustomLoader(
                          type: LoaderType.spinner,
                        )
                      ]
                    ],
                  ),
                ),
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 90,
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km >= 100) {
      return NumberFormat('#,###').format(km);
    } else {
      return NumberFormat('#,##0.1').format(km);
    }
  }
}
