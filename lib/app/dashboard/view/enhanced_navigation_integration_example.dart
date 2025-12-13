// Example integration of enhanced navigation features
// This shows how to integrate the enhanced features with your existing navigation code

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/app/dashboard/services/enhanced_navigation_controller.dart';
import 'package:waze_kibris/app/dashboard/view/enhanced_navigation_view.dart';
import 'package:waze_kibris/app/dashboard/view/maneuver_banner.dart';

/// Example showing how to integrate enhanced navigation into your existing dashboard
class NavigationDashboardExample extends StatefulWidget {
  const NavigationDashboardExample({Key? key}) : super(key: key);

  @override
  State<NavigationDashboardExample> createState() => _NavigationDashboardExampleState();
}

class _NavigationDashboardExampleState extends State<NavigationDashboardExample> {
  final EnhancedNavigationController _navController = EnhancedNavigationController();
  MapboxDirectionsResponse? _currentRoute;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    await _navController.initialize();
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  // Example: Start navigation with a route from your backend
  Future<void> _startNavigationWithRoute(MapboxDirectionsResponse routeResponse) async {
    if (routeResponse.routes.isNotEmpty) {
      final selectedRoute = routeResponse.routes.first;
      
      setState(() {
        _currentRoute = routeResponse;
        _isNavigating = true;
      });

      // Start enhanced navigation
      await _navController.startNavigation(selectedRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Navigation Demo'),
        actions: [
          // Voice toggle
          IconButton(
            icon: Icon(_navController.isVoiceEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() {
                _navController.isVoiceEnabled = !_navController.isVoiceEnabled;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Your existing map widget would go here
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: Text('Your Map Widget Here'),
            ),
          ),

          // Enhanced navigation overlay
          if (_isNavigating && _navController.currentStep != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: ManeuverBanner(
                  step: _navController.currentStep!,
                  distanceRemaining: _navController.distanceRemaining,
                  navigationController: _navController,
                ),
              ),
            ),

          // Navigation info
          if (_isNavigating)
            Positioned(
              bottom: 100,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Distance: ${_navController.formattedDistanceRemaining}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      'Time: ${_navController.estimatedTimeRemaining}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      'ETA: ${_navController.estimatedArrivalTime}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Test route button (for demo)
          if (!_isNavigating)
            FloatingActionButton.extended(
              onPressed: _simulateRouteSelection,
              label: const Text('Start Navigation'),
              icon: const Icon(Icons.navigation),
            ),
          
          const SizedBox(height: 8),
          
          // Stop navigation button
          if (_isNavigating)
            FloatingActionButton(
              onPressed: _stopNavigation,
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop),
            ),
        ],
      ),
    );
  }

  // Simulate getting a route from your backend and starting navigation
  Future<void> _simulateRouteSelection() async {
    // This would normally come from your API call
    final mockRoute = _createMockRoute();
    await _startNavigationWithRoute(mockRoute);
  }

  Future<void> _stopNavigation() async {
    await _navController.stopNavigation();
    setState(() {
      _isNavigating = false;
      _currentRoute = null;
    });
  }

  // Mock route for demonstration - replace with your actual API data
  MapboxDirectionsResponse _createMockRoute() {
    return MapboxDirectionsResponse(
      routes: [
        MapboxRoute(
          geometry: MapboxLineString(
            type: 'LineString',
            coordinates: [
              [33.3823, 35.1856], // lng, lat
              [33.3923, 35.1956],
            ],
          ),
          legs: [
            MapboxLeg(
              steps: [
                MapboxStep(
                  intersections: [
                    MapboxIntersection(
                      location: [33.3823, 35.1856],
                      bearings: [0, 90, 180, 270],
                      entry: [true, true, false, true],
                      lanes: [
                        MapboxLane(valid: true, active: true, indications: ['straight']),
                        MapboxLane(valid: true, active: false, indications: ['left']),
                        MapboxLane(valid: false, active: false, indications: ['right']),
                      ],
                    ),
                  ],
                  geometry: MapboxLineString(
                    type: 'LineString',
                    coordinates: [[33.3823, 35.1856], [33.3923, 35.1956]],
                  ),
                  maneuver: MapboxManeuver(
                    type: 'turn',
                    instruction: 'Turn left onto Main Street',
                    bearingAfter: 270,
                    bearingBefore: 0,
                    location: [33.3823, 35.1856],
                    modifier: 'left',
                  ),
                  name: 'Main Street',
                  duration: 30.0,
                  distance: 200.0,
                  mode: 'driving',
                  voiceInstructions: [
                    MapboxVoiceInstruction(
                      distanceAlongGeometry: 150.0,
                      announcement: 'In 150 meters, turn left onto Main Street',
                    ),
                    MapboxVoiceInstruction(
                      distanceAlongGeometry: 50.0,
                      announcement: 'Turn left onto Main Street',
                    ),
                  ],
                  bannerInstructions: [
                    MapboxBannerInstruction(
                      distanceAlongGeometry: 100.0,
                      primary: MapboxBannerContent(
                        text: 'Turn left',
                        components: [
                          MapboxBannerComponent(text: 'Turn left', type: 'text'),
                        ],
                        type: 'turn',
                        modifier: 'left',
                      ),
                    ),
                  ],
                  ref: 'A1', // Highway reference
                  destinations: 'City Center, Airport',
                  exits: null,
                ),
              ],
              summary: 'Main Street',
              weight: 30.0,
              duration: 30.0,
              distance: 200.0,
            ),
          ],
          weightName: 'routability',
          weight: 30.0,
          duration: 30.0,
          distance: 200.0,
        ),
      ],
      code: 'Ok',
    );
  }
}

/// How to integrate with your existing route selection
class RouteSelectionIntegrationExample {
  
  // Example: Modify your existing route selection to use enhanced navigation
  static Future<void> selectAndStartNavigation(
    BuildContext context,
    MapboxDirectionsResponse routeResponse,
    Stream<Position> positionStream,
  ) async {
    if (routeResponse.routes.isEmpty) return;

    // Show route options to user
    final selectedRouteIndex = await showDialog<int>(
      context: context,
      builder: (context) => _RouteSelectionDialog(routes: routeResponse.routes),
    );

    if (selectedRouteIndex != null) {
      final selectedRoute = routeResponse.routes[selectedRouteIndex];
      
      // Navigate to enhanced navigation view
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EnhancedNavigationView(
            route: selectedRoute,
            positionStream: positionStream,
            onNavigationComplete: () {
              Navigator.of(context).pop();
            },
            onNavigationCancel: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  }
}

class _RouteSelectionDialog extends StatelessWidget {
  final List<MapboxRoute> routes;

  const _RouteSelectionDialog({required this.routes});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Route'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            return ListTile(
              title: Text('Route ${index + 1}'),
              subtitle: Text(
                '${(route.duration / 60).round()} min • ${(route.distance / 1000).toStringAsFixed(1)} km',
              ),
              onTap: () => Navigator.of(context).pop(index),
            );
          },
        ),
      ),
    );
  }
}