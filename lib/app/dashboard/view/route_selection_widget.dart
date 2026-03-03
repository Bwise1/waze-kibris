// Updated route_selection_widget.dart - Mapbox Navigation
import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/location/recent_location.dart';

class RouteSelectionSheet extends StatefulWidget {
  final List<MapboxRoute> routes;
  final ValueChanged<MapboxRoute> onRouteSelected;
  final ValueChanged<MapboxRoute>? onStartNavigation;
  final GooglePlaceDetails? placeDetails; // Add place details

  const RouteSelectionSheet({
    required this.routes,
    required this.onRouteSelected,
    this.onStartNavigation,
    this.placeDetails, // Add this parameter
    super.key,
  });

  @override
  State<RouteSelectionSheet> createState() => _RouteSelectionSheetState();
}

class _RouteSelectionSheetState extends State<RouteSelectionSheet> {
  MapboxRoute? _selectedRoute;
  bool _isStartingNavigation = false;
  List<RouteOption> _routeOptions = [];

  @override
  void initState() {
    super.initState();
    // Defensive check: ensure routes are not empty or null
    if (widget.routes.isEmpty) {
      print(
          '⚠️ [ROUTE_SHEET] RouteSelectionSheet initialized with empty routes list!');
      return;
    }

    // Initially, the first route is selected (Mapbox's recommended route)
    _selectedRoute = widget.routes.first;
    _routeOptions = _createRouteOptions();

    print(
        '✅ [ROUTE_SHEET] RouteSelectionSheet initialized with ${widget.routes.length} routes');
  }

  List<RouteOption> _createRouteOptions() {
    return widget.routes.asMap().entries.map((entry) {
      final index = entry.key;
      final route = entry.value;
      return RouteOption.fromMapboxRoute(route, isRecommended: index == 0);
    }).toList();
  }

  String _formatDuration(double durationSeconds) {
    return MapboxNavigationUtils.formatDuration(durationSeconds);
  }

  String _formatDistance(double distanceMeters) {
    return MapboxNavigationUtils.formatDistance(distanceMeters);
  }

  @override
  Widget build(BuildContext context) {
    // Defensive check: if routes are empty, show error message
    if (widget.routes.isEmpty ||
        _routeOptions.isEmpty ||
        _selectedRoute == null) {
      print(
          '⚠️ [ROUTE_SHEET] RouteSelectionSheet build called with empty routes!');
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'No routes available',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unable to load route options. Please try again.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header with route options info
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Route Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Distance',
                        style: TextStyle(
                          fontSize: 11,
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
                    itemCount: _routeOptions.length,
                    itemBuilder: (context, index) {
                      final routeOption = _routeOptions[index];
                      final route = routeOption.route;
                      final isPrimary = routeOption.isRecommended;
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
                              horizontal: 24, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Route indicator
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isPrimary
                                      ? Colors.orange[100]
                                      : const Color(
                                          0xFFFFDBDB), // Project secondary color
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  isPrimary ? Icons.star : Icons.alt_route,
                                  color: isPrimary
                                      ? Colors.orange[700]
                                      : const Color(
                                          0xFFFF0000), // Project primary red
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Route details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _formatDuration(route.duration),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.red
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatDistance(route.distance),
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      routeOption.subtitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (routeOption.isRecommended) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'RECOMMENDED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],

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
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _isStartingNavigation ? null : _startNavigation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                          ),
                          child: _isStartingNavigation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Start",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
        ));
  }

  Future<void> _startNavigation() async {
    setState(() {
      _isStartingNavigation = true;
    });

    // Add to recent locations when user starts navigation
    if (widget.placeDetails != null) {
      final recentLocation = RecentLocation(
        placeId: widget.placeDetails!.placeId,
        name: widget.placeDetails!.name,
        address: widget.placeDetails!.formattedAddress,
        latitude: widget.placeDetails!.lat,
        longitude: widget.placeDetails!.lng,
        lastVisited: DateTime.now(),
      );

      debugPrint(
          '🔥 Adding recent location: ${recentLocation.name} (${recentLocation.placeId})');

      if (mounted) {
        context.read<ReportsBloc>().add(
              ReportsEvent.addRecentLocation(location: recentLocation),
            );
      }
    } else {
      debugPrint('❌ No place details available for recent location');
    }

    // IMPORTANT: Pop BEFORE calling onStartNavigation.
    // onStartNavigation calls setState in MainDashboard which rebuilds the widget tree
    // and removes this sheet — making Navigator.of(context) invalid in release builds.
    // Popping first while the context is still live avoids the stale-context crash.
    if (mounted) {
      Navigator.of(context).pop('navigation_started');
    }

    if (widget.onStartNavigation != null && _selectedRoute != null) {
      widget.onStartNavigation!(_selectedRoute!);
    } else {
      print(
          '⚠️ [ROUTE_SHEET] Cannot start navigation: _selectedRoute is null or onStartNavigation is null');
    }
  }
}
