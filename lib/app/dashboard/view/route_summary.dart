import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class RoutesBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> availableRoutes;
  final String destinationName;
  final String destinationAddress;
  final Function(int) onRouteSelected;
  final VoidCallback onStartTrip;

  const RoutesBottomSheet({
    required this.availableRoutes,
    required this.destinationName,
    required this.destinationAddress,
    required this.onRouteSelected,
    required this.onStartTrip,
    super.key,
  });

  @override
  State<RoutesBottomSheet> createState() => _RoutesBottomSheetState();
}

class _RoutesBottomSheetState extends State<RoutesBottomSheet> {
  int selectedIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _routes = [];
  // Timer? _checkRoutesTimer;

  @override
  void initState() {
    super.initState();
    _routes = List.from(widget.availableRoutes);
    _isLoading = _routes.isEmpty;

    if (!_isLoading) {
      // If routes are already available
      selectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check if the widget is still in the tree
          widget.onRouteSelected(selectedIndex);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant RoutesBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the provided availableRoutes list has actually changed
    if (widget.availableRoutes != oldWidget.availableRoutes) {
      setState(() {
        _routes = List.from(widget.availableRoutes);
        _isLoading = _routes.isEmpty;

        if (!_isLoading) {
          // If routes are now available (or have changed)
          selectedIndex = 0; // Reset to the first route
          // Defer calling onRouteSelected until after the current build cycle
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Check if the widget is still in the tree
              widget.onRouteSelected(selectedIndex);
            }
          });
        } else {
          // Routes became empty, reset selectedIndex if necessary
          selectedIndex = 0;
        }
      });
    }
  }

  // void _checkForRoutes() {
  //   if (mounted && widget.availableRoutes.isNotEmpty && _isLoading) {
  //     setState(() {
  //       _routes = List.from(widget.availableRoutes); // Create a copy
  //       _isLoading = false;
  //       selectedIndex = 0;
  //     });
  //     // Draw the first route now that routes are available
  //     // widget.onRouteSelected(0);
  //   }
  // }

  @override
  void dispose() {
    // _checkRoutesTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(styles.corners.lg),
          topRight: Radius.circular(styles.corners.lg),
        ),
      ),
      child: Column(
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

          // Route options
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: styles.insets.xxs),
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                final route = _routes[index];
                final summary = route['summary'] as Map<String, dynamic>;

                print('_____Route $index: $summary');
                final isSelected = index == selectedIndex;

                return _buildRouteCard(
                  route: route,
                  summary: summary,
                  index: index,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => selectedIndex = index);
                  },
                );
              },
            ),
          ),

          // Bottom action buttons
          Container(
            padding: EdgeInsets.all(styles.insets.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: styles.theme.divider)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding:
                            EdgeInsets.symmetric(vertical: styles.insets.sm),
                      ),
                      child: const Text('Cancel trip'),
                    ),
                  ),
                  Gap(styles.insets.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onRouteSelected(selectedIndex);
                        widget.onStartTrip();
                        // Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: styles.theme.primary,
                        padding:
                            EdgeInsets.symmetric(vertical: styles.insets.sm),
                      ),
                      child: const Text(
                        'Start Navigation',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildRouteCard({
    required Map<String, dynamic> route,
    required Map<String, dynamic> summary,
    required int index,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: styles.insets.sm),
      decoration: BoxDecoration(
        color:
            isSelected ? styles.theme.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(styles.corners.md),
        border: isSelected
            ? Border.all(color: styles.theme.primary, width: 2)
            : Border.all(color: styles.theme.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('Route card tapped: $index');
            setState(() => selectedIndex = index);
            // Call the callback to draw the selected route
            widget.onRouteSelected(index);
          },
          borderRadius: BorderRadius.circular(styles.corners.md),
          child: Padding(
            padding: EdgeInsets.all(styles.insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected ? styles.theme.primary : Colors.grey,
                    ),
                    Gap(styles.insets.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                summary['formattedTime']?.toString() ??
                                    'Unknown time',
                                style: styles.typography.h4
                                    .textColor(isSelected
                                        ? styles.theme.primary
                                        : styles.theme.black)
                                    .semi,
                              ),
                              Text(
                                summary['formattedDistance']?.toString() ??
                                    'Unknown distance',
                                style: styles.typography.t2
                                    .textColor(styles.theme.caption),
                              ),
                            ],
                          ),
                          Gap(styles.insets.xs),
                          Text(
                            summary['summaryText']?.toString() ??
                                'Route ${index + 1}',
                            style: styles.typography.t3
                                .textColor(styles.theme.caption),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                //Gap(styles.insets.sm),

                // Traffic info
                // Container(
                //   padding: EdgeInsets.all(styles.insets.xs),
                //   decoration: BoxDecoration(
                //     color: Colors.blue.withOpacity(0.1),
                //     borderRadius: BorderRadius.circular(styles.corners.sm),
                //   ),
                // child: Row(
                //   mainAxisSize: MainAxisSize.min,
                //   children: [
                //     const Icon(Icons.info_outline,
                //         size: 16, color: Colors.blue),
                //     Gap(styles.insets.xs),
                //     const Text(
                //       'Live traffic data available',
                //       style: TextStyle(color: Colors.blue, fontSize: 12),
                //     ),
                //   ],
                // ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
