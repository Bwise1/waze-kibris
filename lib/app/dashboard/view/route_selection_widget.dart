// Updated route_selection_widget.dart
import 'package:flutter/material.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';

class RouteSelectionSheet extends StatefulWidget {
  final List<DirectionsRoute> routes;
  final ValueChanged<DirectionsRoute> onRouteSelected;
  final ValueChanged<DirectionsRoute>? onStartNavigation; // Add this callback

  const RouteSelectionSheet({
    required this.routes,
    required this.onRouteSelected,
    this.onStartNavigation, // Add this parameter
    super.key,
  });

  @override
  State<RouteSelectionSheet> createState() => _RouteSelectionSheetState();
}

class _RouteSelectionSheetState extends State<RouteSelectionSheet> {
  late DirectionsRoute _selectedRoute;
  bool _isStartingNavigation = false;

  @override
  void initState() {
    super.initState();
    // Initially, the first route is selected
    if (widget.routes.isNotEmpty) {
      _selectedRoute = widget.routes.first;
    }
  }

  String _formatDuration(int durationSeconds) {
    final minutes = (durationSeconds / 60).round();
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${remainingMinutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDistance(int distanceMeters) {
    if (distanceMeters < 1000) {
      // Show in meters for distances under 1km
      return '${distanceMeters}m';
    } else {
      final km = distanceMeters / 1000;
      if (km < 10) {
        // Show one decimal place for distances under 10km
        return '${km.toStringAsFixed(1)} km';
      } else if (km < 100) {
        // Show one decimal place for distances under 100km
        return '${km.toStringAsFixed(1)} km';
      } else {
        // Round to nearest km for longer distances
        return '${km.round()} km';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with route options info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Route Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Driving distance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Routes list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.routes.length,
                itemBuilder: (context, index) {
                  final route = widget.routes[index];
                  final isPrimary = index == 0;
                  final isSelected = route == _selectedRoute;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedRoute = route;
                      });
                      // Always call onRouteSelected to update polyline immediately
                      widget.onRouteSelected(route);
                    },
                    child: Container(
                      color: isSelected ? Colors.red[50] : Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route indicator
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? Colors.orange[100]
                                  : const Color(0xFFFFDBDB), // Project secondary color
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isPrimary ? Icons.star : Icons.alt_route,
                              color: isPrimary
                                  ? Colors.orange[700]
                                  : const Color(0xFFFF0000), // Project primary red
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Route details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(
                                          route.legs.first.duration?.value ?? 0),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.red
                                            : Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDistance(
                                          route.legs.first.distance?.value ?? 0),
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  route.summary,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  route.legs.first.endAddress,
                                  style: const TextStyle(
                                    color: Colors.black38,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Additional route info for primary route
                                // if (isPrimary && route.warnings.isNotEmpty) ...[
                                //   const SizedBox(height: 8),
                                //   Container(
                                //     padding: const EdgeInsets.symmetric(
                                //         horizontal: 8, vertical: 4),
                                //     decoration: BoxDecoration(
                                //       color: Colors.amber[100],
                                //       borderRadius: BorderRadius.circular(12),
                                //     ),
                                //     child: Row(
                                //       mainAxisSize: MainAxisSize.min,
                                //       children: [
                                //         Icon(
                                //           Icons.warning_amber,
                                //           size: 14,
                                //           color: Colors.amber[700],
                                //         ),
                                //         const SizedBox(width: 4),
                                //         Text(
                                //           'Traffic alerts',
                                //           style: TextStyle(
                                //             fontSize: 12,
                                //             color: Colors.amber[700],
                                //             fontWeight: FontWeight.w500,
                                //           ),
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // ],
                              ],
                            ),
                          ),

                          // Selection indicator
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isStartingNavigation
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "Cancel trip",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isStartingNavigation ? null : _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                      ),
                      child: _isStartingNavigation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Start route",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startNavigation() async {
    setState(() {
      _isStartingNavigation = true;
    });

    // Add a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    if (widget.onStartNavigation != null) {
      widget.onStartNavigation!(_selectedRoute);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
