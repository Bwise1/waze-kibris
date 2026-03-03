import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/view/map_controller_mixin.dart';
import 'package:waze_kibris/app/dashboard/view/map_sheet.dart';
import 'package:waze_kibris/app/dashboard/view/navigation_overlay.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/route_bar.dart';
import 'package:waze_kibris/app/dashboard/view/route_overview.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<StatefulWidget> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with TickerProviderStateMixin, MapControllerMixin {
  bool _isModalOpen = false;
  late NavigationBloc _navigationBloc;
  SearchSuggestion? _activeRouteSuggestion;
  Position? _lastReportFetchPosition;
  bool _initialReportsFetched = false;
  bool _isMapSheetVisible = true; // Control MapSheet visibility
  Timer?
      _routeRefreshTimer; // Timer for periodic route refresh during navigation

  @override
  NavigationBloc get navigationBloc => _navigationBloc;

  void _fetchNearbyReports(Position position) {
    if (_lastReportFetchPosition == null ||
        Geolocator.distanceBetween(
              _lastReportFetchPosition!.latitude,
              _lastReportFetchPosition!.longitude,
              position.latitude,
              position.longitude,
            ) >
            1000) {
      _lastReportFetchPosition = position;

      debugPrint(
          '🚨 Fetching reports near: ${position.latitude}, ${position.longitude}');

      context.read<ReportsBloc>().add(
            ReportsEvent.getNearByReports(
              radius: 50,
              lat: position.latitude.toString(),
              long: position.longitude.toString(),
            ),
          );
    }
  }

  void _fetchNearbyReportsAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));

    try {
      final currentPosition = await Geolocator.getCurrentPosition();
      if (mounted) {
        _fetchNearbyReports(currentPosition);
      }
    } catch (e) {
      debugPrint('Error getting position for report fetching: $e');
    }
  }

  @override
  void onPositionUpdate(Position position) {
    _fetchNearbyReports(position);

    final currentState = _navigationBloc.state;
    if (currentState is NavigationInProgress) {
      updateRouteProgress(
        currentState.route,
        currentState.currentStepIndex,
        currentPosition: position,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _navigationBloc = NavigationBloc();
    setupPositionTracking();
    _preloadUserLocation();
  }

  Future<void> _preloadUserLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        setState(() {
          _lastReportFetchPosition = position;
        });
        // Fetch reports immediately if we have a last known position
        _fetchNearbyReports(position);
      }
    } catch (e) {
      debugPrint('Error preloading location: $e');
    }
  }

  @override
  void dispose() {
    _routeRefreshTimer?.cancel();
    _navigationBloc.close();
    super.dispose();
  }

  void _onSuggestionSelected(SearchSuggestion suggestion) {
    setState(() {
      _activeRouteSuggestion = suggestion;
    });
  }

  void _clearRouteBar() {
    setState(() {
      _activeRouteSuggestion = null;
    });
  }

  void _startNavigation(MapboxRoute route) {
    if (route.distance < 50) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🎉 Destination Reached!'),
          content: const Text('You have arrived at your destination.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // MapSheet is already hidden during navigation, but ensure it stays hidden
    setState(() {
      _isMapSheetVisible = false;
    });

    drawMapboxPolyline(route);
    updateMapForNavigationMode(true);
    forceNavigationZoom();
    _navigationBloc.add(NavigationStarted(route: route));
    setIsFollowingUser(true);
    initializeSnapToRoad(route);

    // Start periodic route refresh timer (every 4 minutes)
    _startRouteRefreshTimer(route);
  }

  void _startRouteRefreshTimer(MapboxRoute initialRoute) {
    // Cancel any existing timer
    _routeRefreshTimer?.cancel();

    // Refresh route every 4 minutes to get updated traffic conditions
    _routeRefreshTimer =
        Timer.periodic(const Duration(minutes: 4), (timer) async {
      final currentState = _navigationBloc.state;
      if (currentState is NavigationInProgress && !currentState.isRerouting) {
        try {
          final currentPos = currentState.userPosition;
          if (currentPos == null) {
            debugPrint('⚠️ Cannot refresh route: No current position');
            return;
          }

          // Get destination from current route (last point of last step)
          final lastLeg = currentState.route.legs.last;
          final lastStep = lastLeg.steps.last;
          final destLat = lastStep.maneuver.location[1];
          final destLng = lastStep.maneuver.location[0];

          debugPrint(
              '🔄 Refreshing route from (${currentPos.latitude}, ${currentPos.longitude}) to ($destLat, $destLng)...');

          final placesService = getIt<PlacesService>();
          final response = await placesService.fetchMapboxDirections(
            originLat: currentPos.latitude,
            originLng: currentPos.longitude,
            destinationLat: destLat,
            destinationLng: destLng,
            profile: 'driving-traffic',
            alternatives: false,
          );

          if (response.routes.isNotEmpty) {
            final refreshedRoute = response.routes.first;
            debugPrint(
                '✅ Route refreshed! New distance: ${refreshedRoute.distance}m, duration: ${refreshedRoute.duration}s');

            // Update navigation with refreshed route
            _navigationBloc.add(NavigationStarted(route: refreshedRoute));

            // Update polyline visualization
            drawMapboxPolyline(refreshedRoute);
          } else {
            debugPrint('⚠️ Route refresh failed: No routes found');
          }
        } catch (e) {
          debugPrint('❌ Error refreshing route: $e');
          // Don't cancel timer on error - will retry on next interval
        }
      } else {
        // Navigation ended or rerouting in progress, cancel timer
        timer.cancel();
      }
    });
  }

  void _endNavigation() {
    // Cancel route refresh timer
    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = null;

    _navigationBloc.add(NavigationStopped());
    updateMapForNavigationMode(false);
    clearRoutePolyline();
    clearSnapToRoad();
    _clearRouteBar();
    // Restore MapSheet visibility when navigation ends
    setState(() {
      _isMapSheetVisible = true;
    });
  }

  void _onReportsReceived(List<ReportData> reports) {
    debugPrint('📍 Received ${reports.length} reports to display on map');
    displayReportsOnMap(reports);
  }

  final GlobalKey _mapWidgetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    if (!_initialReportsFetched) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Fetch reports immediately if we have a last known position
        // Otherwise, fetch after delay as fallback
        if (_lastReportFetchPosition != null) {
          _fetchNearbyReports(_lastReportFetchPosition!);
        } else {
          _fetchNearbyReportsAfterDelay();
        }
        _initialReportsFetched = true;
      });
    }

    debugPrint('🔥 MainDashboard build() called');

    return BlocProvider.value(
      value: _navigationBloc,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.grey[200],
        body: MultiBlocListener(
          listeners: [
            BlocListener<NavigationBloc, NavigationState>(
              listener: (context, state) {
                if (state is NavigationInProgress) {
                  if (state.isNavigationComplete) {
                    _showNavigationCompleteDialog();
                  }
                } else if (state is NavigationInitial) {
                  // Self-healing failsafe: whenever navigation returns to initial/idle,
                  // ensure MapSheet is restored regardless of how it was hidden.
                  if (!_isMapSheetVisible) {
                    setState(() {
                      _isMapSheetVisible = true;
                    });
                  }
                }
              },
            ),
            BlocListener<ReportsBloc, ReportState>(
              listener: (context, state) {
                if (state is GetReportSuccess) {
                  _onReportsReceived(state.data);
                } else if (state is ReportError) {
                  debugPrint('🚨 Report fetch error: ${state.message}');
                }
              },
            ),
          ],
          child: BlocBuilder<NavigationBloc, NavigationState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // Map widget (full screen)
                  mp.MapWidget(
                    key: _mapWidgetKey,
                    onMapCreated: onMapCreated,
                    onTapListener: onMapTap,
                    cameraOptions: _lastReportFetchPosition != null
                        ? mp.CameraOptions(
                            center: mp.Point(
                              coordinates: mp.Position(
                                _lastReportFetchPosition!.longitude,
                                _lastReportFetchPosition!.latitude,
                              ),
                            ),
                            zoom: 15.0,
                          )
                        : null,
                  ),

                  // Route bar (shown when a destination is selected)
                  if (_activeRouteSuggestion != null &&
                      state is! NavigationInProgress)
                    Positioned(
                      top: kToolbarHeight +
                          MediaQuery.of(context).padding.top -
                          100,
                      left: 16,
                      right: 16,
                      child: RouteBar(
                        start: "Current Location",
                        end: _activeRouteSuggestion!.mainText,
                        onCancel: _clearRouteBar,
                      ),
                    ),

                  // Navigation UI
                  if (state is NavigationInProgress) ...[
                    if (state.isOverviewVisible)
                      RouteOverviewWidget(
                        navigationState: state,
                        onBackToNavigation: () {
                          _navigationBloc.add(NavigationOverviewToggled());
                          setIsFollowingUser(true);
                        },
                      )
                    else
                      NavigationOverlay(
                        navigationState: state,
                        onEndNavigation: _endNavigation,
                        onToggleOverview: () {
                          _navigationBloc.add(NavigationOverviewToggled());
                          if (!state.isOverviewVisible) {
                            setIsFollowingUser(false);
                          } else {
                            setIsFollowingUser(true);
                          }
                        },
                      ),
                  ],

                  // Expandable sheet — hidden during navigation and when location selected
                  if (state is! NavigationInProgress &&
                      !_isModalOpen &&
                      _isMapSheetVisible)
                    Positioned.fill(
                      child: MapSheet(
                        onSuggestionSelected: _onSuggestionSelected,
                        onDrawMapboxPolyline: drawMapboxPolyline,
                        onStartNavigation: _startNavigation,
                        onLocationSelected: () {
                          setState(() {
                            _isMapSheetVisible = false;
                          });
                        },
                        // Restores MapSheet when any bottom sheet is dismissed without
                        // starting navigation (including error paths and back-swipes).
                        onRouteSelectionDismissed: () {
                          setState(() {
                            _isMapSheetVisible = true;
                          });
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showNavigationCompleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🎉 Destination Reached!'),
          content:
              const Text('You have successfully reached your destination.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _endNavigation();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
