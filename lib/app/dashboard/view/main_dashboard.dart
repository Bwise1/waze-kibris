import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:sheet/sheet.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/modals/report_modal.dart';
import 'package:waze_kibris/app/dashboard/view/map_app_bar.dart';
import 'package:waze_kibris/app/dashboard/view/map_controller_mixin.dart';
import 'package:waze_kibris/app/dashboard/view/map_sheet.dart';
import 'package:waze_kibris/app/dashboard/view/navigation_overlay.dart';
import 'package:waze_kibris/app/dashboard/view/route_bar.dart';
import 'package:waze_kibris/app/dashboard/view/route_overview.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/dialog_route.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/widgets/buttons/app_button.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<StatefulWidget> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with TickerProviderStateMixin, MapControllerMixin {
  late SheetController controller;
  bool _isModalOpen = false;
  late NavigationBloc _navigationBloc;
  SearchSuggestion? _activeRouteSuggestion;
  Position? _lastReportFetchPosition;
  bool _initialReportsFetched = false;

  @override
  NavigationBloc get navigationBloc => _navigationBloc;

  void _fetchNearbyReports(Position position) {
    // Only fetch if we've moved significantly or haven't fetched before
    if (_lastReportFetchPosition == null ||
        Geolocator.distanceBetween(
          _lastReportFetchPosition!.latitude,
          _lastReportFetchPosition!.longitude,
          position.latitude,
          position.longitude,
        ) > 1000) { // Fetch reports every 1km movement
      
      _lastReportFetchPosition = position;
      
      debugPrint('🚨 Fetching reports near: ${position.latitude}, ${position.longitude}');
      
      context.read<ReportsBloc>().add(
        ReportsEvent.getNearByReports(
          radius: 50, // 50km radius
          lat: position.latitude.toString(),
          long: position.longitude.toString(),
        ),
      );
    }
  }

  void _fetchNearbyReportsAfterDelay() async {
    // Wait for location to be available before fetching reports
    await Future.delayed(const Duration(seconds: 3));
    
    try {
      final currentPosition = await Geolocator.getCurrentPosition();
      
      // Check if widget is still mounted before using context
      if (mounted) {
        _fetchNearbyReports(currentPosition);
      }
    } catch (e) {
      debugPrint('Error getting position for report fetching: $e');
    }
  }

  @override
  void onPositionUpdate(Position position) {
    // Fetch reports when user moves significantly
    _fetchNearbyReports(position);

    // Update route progress during navigation
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
    controller = SheetController();
    _preloadUserLocation();
  }

  Future<void> _preloadUserLocation() async {
    try {
      // Get last known position immediately for fast startup
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        setState(() {
          _lastReportFetchPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error preloading location: $e');
    }
  }

  @override
  void dispose() {
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
    // Check if we are already at the destination (e.g., distance < 50 meters)
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

    // Draw the route polyline first
    drawMapboxPolyline(route);

    // Update map for navigation mode FIRST
    updateMapForNavigationMode(true);

    // Immediately zoom to navigation level
    forceNavigationZoom();

    // Start navigation
    _navigationBloc.add(NavigationStarted(route: route));
    setIsFollowingUser(true);

    // Initialize snap-to-road with route data
    initializeSnapToRoad(route);

    // Close the sheet when navigation starts
    controller.relativeAnimateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _endNavigation() {
    _navigationBloc.add(NavigationStopped());
    updateMapForNavigationMode(false);
    clearRoutePolyline();
    clearSnapToRoad();
    _clearRouteBar(); // Also dismiss the route bar when ending navigation
  }

  void _onReportsReceived(List<ReportData> reports) {
    debugPrint('📍 Received ${reports.length} reports to display on map');
    
    // Pass reports to map controller to display as markers
    displayReportsOnMap(reports);
  }

  final GlobalKey _mapWidgetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Trigger initial reports fetch after first build
    if (!_initialReportsFetched) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchNearbyReportsAfterDelay();
        _initialReportsFetched = true;
      });
    }
    
    debugPrint('🔥 MainDashboard build() called');

    return BlocProvider.value(
      value: _navigationBloc,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false, // Prevent keyboard from pushing sheet up
        backgroundColor: Colors.grey[200],
        // Fixed AppBar issue - wrap BlocBuilder in PreferredSize
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: BlocBuilder<NavigationBloc, NavigationState>(
            builder: (context, state) {
              // Hide app bar during navigation
              if (state is NavigationInProgress && !state.isOverviewVisible) {
                return AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 0,
                  automaticallyImplyLeading: false,
                );
              }
              return MapAppBar(controller: controller);
            },
          ),
        ),
        body: MultiBlocListener(
          listeners: [
            BlocListener<NavigationBloc, NavigationState>(
              listener: (context, state) {
                if (state is NavigationInProgress) {
                  // Handle navigation state changes
                  if (state.isNavigationComplete) {
                    _showNavigationCompleteDialog();
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
                  // Map widget
                  mp.MapWidget(
                    key: _mapWidgetKey,
                    onMapCreated: onMapCreated,
                    onTapListener: onMapTap,
                    // Use initial camera options if we have a last known position
                    cameraOptions: _lastReportFetchPosition != null
                        ? mp.CameraOptions(
                            center: mp.Point(
                              coordinates: mp.Position(
                                _lastReportFetchPosition!.longitude,
                                _lastReportFetchPosition!.latitude,
                              ),
                            ),
                            zoom: 15.0, // Start close up
                          )
                        : null,
                  ),

                  // Show route bar if there's an active suggestion and not navigating
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

                  // Show navigation UI when in navigation mode
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
                            // Switching to overview mode
                            setIsFollowingUser(false);
                          } else {
                            // Switching back to navigation mode
                            setIsFollowingUser(true);
                          }
                        },
                      ),
                  ],

                    // Show bottom sheet only when not navigating and no modal is open
                    if (state is! NavigationInProgress && !_isModalOpen)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final screenHeight = MediaQuery.of(context).size.height;
                            return AnimatedBuilder(
                              animation: controller.animation,
                              builder: (context, child) {
                                return SizedBox(
                                  height: screenHeight,
                                  child: MapSheet(
                                    controller: controller,
                                    onSuggestionSelected: _onSuggestionSelected,
                                    onDrawMapboxPolyline: drawMapboxPolyline,
                                    onStartNavigation: _startNavigation,
                                    context: context,
                                  ),
                                );
                              },
                            );
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

  // void _hideLoadingAfterLocation() async {
  //   // Wait for location to be obtained and map to be positioned
  //   await Future.delayed(const Duration(milliseconds: 1500));

  //   if (mounted) {
  //     setState(() {
  //       _isMapLoading = false;
  //     });
  //   }
  // }

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
