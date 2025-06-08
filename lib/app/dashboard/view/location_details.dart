import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/view/map_viewpoly.dart';
import 'package:waze_kibris/app/dashboard/view/route_summary.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/places/places_response.dart';

class LocationDetailsBottomSheet extends StatelessWidget {
  const LocationDetailsBottomSheet({
    required this.suggestion,
    required this.onGetRoute,
    required this.onSave,
    required this.onRouteSelected,
    required this.onStartTrip,
    this.placeDetails,
    super.key,
  });
  final AutocompleteSuggestion suggestion;
  final Map<String, dynamic>? placeDetails;
  final Future<void> Function() onGetRoute;
  final VoidCallback onSave;
  final void Function(int index) onRouteSelected;
  final VoidCallback onStartTrip;

  @override
  Widget build(BuildContext context) {
    final details = placeDetails;
    print('Details: ${suggestion.location}, $details');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(styles.corners.lg),
          topRight: Radius.circular(styles.corners.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.all(styles.insets.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Location info
          Padding(
            padding: EdgeInsets.all(styles.insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location name and icon
                Row(
                  children: [
                    Gap(styles.insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.name ?? suggestion.description,
                            style: styles.typography.h5
                                .textColor(styles.theme.black)
                                .semi,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            details?['address'] as String,
                            style: styles.typography.t2
                                .textColor(styles.theme.caption),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(suggestion.location.toString())
                        ],
                      ),
                    ),
                  ],
                ),

                Gap(styles.insets.lg),

                // Additional details
                if (details != null) ...[
                  if (details['website'] != null) ...[
                    Gap(styles.insets.sm),
                    _buildDetailRow(
                      icon: Assets.icons.globe,
                      title: 'Website',
                      value: details['website'].toString(),
                    ),
                  ],
                  Gap(styles.insets.lg),
                ],
                // Secondary actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSecondaryAction(
                      icon: Assets.icons.home,
                      label: 'Call',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Call feature not available')),
                        );
                      },
                    ),
                    _buildSecondaryAction(
                      icon: Assets.icons.arrowForward,
                      label: 'Share',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Shared: ${details?['name'] ?? suggestion.name}'),
                          ),
                        );
                      },
                    ),
                    _buildSecondaryAction(
                      icon: Assets.icons.home,
                      label: 'Favorite',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Added to favorites!')),
                        );
                      },
                    ),
                  ],
                ),
                // Main action buttons

                Gap(styles.insets.lg),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildActionButton(
                        text: 'See all Routes',
                        onPressed: () async {
                          Navigator.pop(context);
                          onGetRoute();
                          _showRoutesBottomSheet(
                              context); // Show routes bottom sheet
                        },
                        isPrimary: true,
                      ),
                    ),
                    Gap(styles.insets.sm),
                  ],
                ),

                Gap(styles.insets.md),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(styles.insets.sm),
      decoration: BoxDecoration(
        color: styles.theme.background,
        borderRadius: BorderRadius.circular(styles.corners.sm),
      ),
      child: Row(
        children: [
          AppIcon(
            icon,
            color: styles.theme.grey,
            size: 16,
          ),
          Gap(styles.insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: styles.typography.t3.textColor(styles.theme.caption),
                ),
                Text(
                  value,
                  style: styles.typography.t2.textColor(styles.theme.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isPrimary ? styles.theme.primary : styles.theme.background,
        borderRadius: BorderRadius.circular(styles.corners.sm),
        border: isPrimary ? null : Border.all(color: styles.theme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(styles.corners.sm),
          child: Center(
            child: Text(
              text,
              style: styles.typography.t2
                  .textColor(isPrimary ? Colors.white : styles.theme.text)
                  .semi,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryAction({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: styles.theme.background,
              borderRadius: BorderRadius.circular(styles.corners.sm),
              border: Border.all(color: styles.theme.divider),
            ),
            child: AppIcon(
              icon,
              color: styles.theme.grey,
              size: 20,
            ),
          ),
          Gap(styles.insets.xs),
          Text(
            label,
            style: styles.typography.h4.textColor(styles.theme.caption),
          ),
        ],
      ),
    );
  }

  void _showRoutesBottomSheet(BuildContext context) {
    onGetRoute();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoutesBottomSheet(
        onStartTrip: onStartTrip,
        availableRoutes: availableRoutes, // Add this parameter
        destinationName: suggestion.name ?? suggestion.description,
        destinationAddress:
            placeDetails?['address'].toString() ?? suggestion.location ?? '',
        onRouteSelected: onRouteSelected,
      ),
    );
  }
}
