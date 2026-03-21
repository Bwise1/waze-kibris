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
import 'package:waze_kibris/app/profile/view/profile_panel.dart';
import 'package:waze_kibris/app/dashboard/modals/report_modal.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<StatefulWidget> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with TickerProviderStateMixin, MapControllerMixin, WidgetsBindingObserver {
  bool _isModalOpen = false;
  bool _mapReadyToBuild = false;
  bool _servicesStarted = false;
  late NavigationBloc _navigationBloc;
  SearchSuggestion? _activeRouteSuggestion;
  Position? _lastReportFetchPosition;
  bool _initialReportsFetched = false;
  bool _initialReportFetchScheduled = false;
  Timer? _initialReportFetchFallbackTimer;
  bool _lastReportsWereEmpty = false;
  bool _retriedEmptyReportsFetch = false;
  bool _isMapSheetVisible = true; // Control MapSheet visibility
  bool _wsConnectAttempted =
      false; // So we only connect once when auth is ready
  Timer?
      _routeRefreshTimer; // Timer for periodic route refresh during navigation
  MapboxRoute?
      _lastDrawnRoute; // Track last drawn route for reroute/refresh redraw
  DateTime? _lastNearbyUsersFetch;
  static const Duration _nearbyUsersFetchInterval = Duration(seconds: 30);

  @override
  NavigationBloc get navigationBloc => _navigationBloc;

  Future<void> _fetchNearbyUsersIfDue(Position position) async {
    final now = DateTime.now();
    if (_lastNearbyUsersFetch != null &&
        now.difference(_lastNearbyUsersFetch!) < _nearbyUsersFetchInterval) {
      return;
    }
    _lastNearbyUsersFetch = now;

    try {
      final repo = context.read<AuthRepository>();
      final users = await repo.getNearbyUsers(
        position.latitude,
        position.longitude,
        radiusM: 2000,
      );
      if (!mounted) return;
      displayNearbyUsersOnMap(users);
    } catch (e) {
      debugPrint('Nearby users fetch error: $e');
    }
  }

  void _fetchNearbyReports(Position position, {bool force = false}) {
    bool shouldFetch = force;

    if (!shouldFetch) {
      if (_lastReportFetchPosition == null) {
        shouldFetch = true;
      } else {
        final distance = Geolocator.distanceBetween(
          _lastReportFetchPosition!.latitude,
          _lastReportFetchPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (distance > 1000) {
          shouldFetch = true;
        }
      }
    }

    if (shouldFetch) {
      _lastReportFetchPosition = position;

      debugPrint(
          '🚨 Fetching reports near: ${position.latitude}, ${position.longitude}');

      context.read<ReportsBloc>().add(
            ReportsEvent.getNearByReports(
              radius:
                  5000, // meters: same area so multiple users see same reports
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
        _fetchNearbyReports(currentPosition, force: true);
      }
    } catch (e) {
      debugPrint('Error getting position for report fetching: $e');
    }
  }

  @override
  void onPositionUpdate(Position position) {
    bool isFirstFetch = false;
    // First report fetch: wait for location from stream instead of timer
    if (!_initialReportsFetched) {
      _initialReportFetchFallbackTimer?.cancel();
      _initialReportFetchFallbackTimer = null;
      _initialReportsFetched = true;
      isFirstFetch = true;
      debugPrint(
          '🚨 First report fetch triggered by position: ${position.latitude}, ${position.longitude}');
    }
    // Retry once when we had empty reports and position has moved significantly
    if (_lastReportsWereEmpty &&
        !_retriedEmptyReportsFetch &&
        _lastReportFetchPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastReportFetchPosition!.latitude,
        _lastReportFetchPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance > 500) {
        _retriedEmptyReportsFetch = true;
        isFirstFetch = true;
        _lastReportFetchPosition = null; // force next fetch to run
      }
    }
    _fetchNearbyReports(position, force: isFirstFetch);

    _fetchNearbyUsersIfDue(position);

    final currentState = _navigationBloc.state;
    if (currentState is NavigationInProgress) {
      updateRouteProgress(
        currentState.route,
        currentState.currentStepIndex,
        currentLegIndex: currentState.currentLegIndex,
        currentPosition: position,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navigationBloc = NavigationBloc();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _mapReadyToBuild = true);
    });

    // Check if user is already authenticated on app launch to connect WS immediately,
    // otherwise the BlocListener below will handle the initial AuthSuccess emission.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '🔌 WebSocket: addPostFrameCallback triggered. mounted=$mounted');
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        debugPrint(
            '🔌 WebSocket: authState in postFrame is ${authState.runtimeType}, _wsConnectAttempted=$_wsConnectAttempted');
        if (authState is AuthSuccess &&
            authState.user != null &&
            !_wsConnectAttempted) {
          debugPrint('🔌 WebSocket: connecting from postFrameCallback');
          _wsConnectAttempted = true;
          _connectWebSocketIfPossible();
        }
      }
    });

    // First report fetch is triggered when we get a position in onPositionUpdate,
    // with an 8s fallback timer started from build().
  }

  Future<void> _connectWebSocketIfPossible() async {
    debugPrint('🔌 WebSocket: _connectWebSocketIfPossible called');
    final authState = context.read<AuthBloc>().state;
    String? userId;

    if (authState is AuthSuccess && authState.user != null) {
      userId = authState.user!.id;
    } else {
      // If we are still loading profile but have a token, we can try to extract userId or bypass
      // but without JWT decoding we need the user ID. So we log and return, relying on BlocListener.
      debugPrint(
          '🔌 WebSocket: skip connect (not AuthSuccess or no user: ${authState.runtimeType})');
      return;
    }

    try {
      debugPrint('🔌 WebSocket: fetching position...');
      final position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();

      if (!mounted || position == null) {
        debugPrint(
            '🔌 WebSocket: skip connect (no position or not mounted). mounted: $mounted, position: $position');
        return;
      }

      debugPrint(
          '🔌 WebSocket: connecting (userId: $userId, lat: ${position.latitude}, lng: ${position.longitude})');
      final ws = context.read<WebSocketService>();
      await ws.connect(
        userId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e, st) {
      debugPrint('🔌 WebSocket: connect failed: $e');
      debugPrint('🔌 WebSocket: $st');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground: resume tracking and refresh navigation.
      resumeTrackingAndRefreshNavigation(_navigationBloc);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Lightly pause tracking while in background to avoid unnecessary work.
      pausePositionTracking();
    }
  }

  Future<void> _preloadUserLocation() async {
    try {
      Position? position = await Geolocator.getLastKnownPosition();

      // Fallback if last known position is not available
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      if (mounted) {
        setState(() {
          _lastReportFetchPosition = position;
        });
        // Do not fetch here; first fetch happens after delay with getCurrentPosition()
      }
    } catch (e) {
      debugPrint('Error preloading location: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initialReportFetchFallbackTimer?.cancel();
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
    if (!mounted) return;

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
    setState(() => _lastDrawnRoute = route);
    updateMapForNavigationMode(true);
    forceNavigationZoom();
    _navigationBloc.add(NavigationStarted(route: route));
    setIsFollowingUser(true);
    initializeSnapToRoad(route);

    // Draw lane guidance immediately for step 0 (position optional; first position update will refine)
    updateRouteProgress(route, 0, currentLegIndex: 0);

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
      _lastDrawnRoute = null;
    });
  }

  void _onReportsReceived(List<ReportData> reports) {
    debugPrint('📍 Received ${reports.length} reports to display on map');
    displayReportsOnMap(reports);
  }

  final GlobalKey _mapWidgetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Schedule fallback: if we don't get a position from the stream within 8s, fetch with getCurrentPosition()
    if (!_initialReportFetchScheduled) {
      _initialReportFetchScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initialReportFetchFallbackTimer = Timer(
          const Duration(seconds: 8),
          () {
            if (mounted && !_initialReportsFetched) {
              debugPrint(
                  '🚨 Report fetch fallback: no position yet, using getCurrentPosition()');
              _initialReportsFetched = true;
              _fetchNearbyReportsAfterDelay();
            }
          },
        );
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
            BlocListener<AuthBloc, AuthState>(
              listener: (context, authState) {
                debugPrint(
                    '🔌 WebSocket: BlocListener detected AuthBloc state change: ${authState.runtimeType}. _wsConnectAttempted=$_wsConnectAttempted, hasUser=${authState is AuthSuccess ? authState.user != null : "N/A"}');

                // Require login: start services only after we have an authenticated user.
                if (!_servicesStarted &&
                    authState is AuthSuccess &&
                    authState.user != null) {
                  _servicesStarted = true;
                  setupPositionTracking();
                  _preloadUserLocation();
                }

                // Require login: if auth errors, send user to sign-in.
                // LoggedOut is handled on MainScreen so logout works from any tab.
                if (authState is AuthError) {
                  if (mounted) context.go(ScreenPaths.signIn);
                  return;
                }

                if (authState is AuthSuccess &&
                    authState.user != null &&
                    !_wsConnectAttempted) {
                  debugPrint(
                      '🔌 WebSocket: BlocListener initiating connection.');
                  _wsConnectAttempted = true;
                  _connectWebSocketIfPossible();
                }
              },
            ),
            BlocListener<NavigationBloc, NavigationState>(
              listener: (context, state) {
                if (state is NavigationInProgress) {
                  // Redraw route and update snap service when bloc applies a new route (e.g. after reroute)
                  if (state.route != _lastDrawnRoute) {
                    drawMapboxPolyline(state.route);
                    setState(() => _lastDrawnRoute = state.route);
                  }
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
                  _lastReportsWereEmpty = state.data.isEmpty;
                  _onReportsReceived(state.data);
                } else if (state is ReportError) {
                  debugPrint('🚨 Report fetch error: ${state.message}');
                }
              },
            ),
            BlocListener<GroupsBloc, GroupsState>(
              listener: (context, state) {
                if (state is GetGroupMessagesSuccess) {
                  displayGroupLocationsOnMap(state.groupLocations);
                }
              },
            ),
          ],
          child: BlocBuilder<NavigationBloc, NavigationState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // Map widget (full screen)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (!_mapReadyToBuild) {
                          return const SizedBox.shrink();
                        }
                        // Avoid initializing Mapbox while the widget has not been laid out yet.
                        if (constraints.maxWidth < 2 ||
                            constraints.maxHeight < 2) {
                          return const SizedBox.shrink();
                        }

                        return mp.MapWidget(
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
                        );
                      },
                    ),
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

                  // Waze-style menu button (top-left)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          final authState = context.read<AuthBloc>().state;
                          if (authState is AuthSuccess &&
                              authState.user != null) {
                            final user = authState.user!;
                            showProfilePanel(
                              context,
                              userDisplayName: user.displayName,
                              userEmail: user.email,
                              userProfileIcon: user.profileIcon,
                            );
                          } else {
                            showProfilePanel(context);
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.menu,
                            color: Colors.black87,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Global report button (available even when not navigating),
                  // aligned just below the recenter FAB and only shown when
                  // the main MapSheet is visible (so it appears "attached" to it)
                  if (state is! NavigationInProgress &&
                      _isMapSheetVisible &&
                      !_isModalOpen)
                    Positioned(
                      bottom: 268, // closer to recenter, but not overlapping
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'global_report_fab',
                        backgroundColor: Colors.orange,
                        onPressed: () async {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const ReportEventModal(),
                          );
                        },
                        child: const Icon(
                          Icons.report_problem,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Recenter (my location) button — above report FAB, visible above panel,
                  // and only when the MapSheet is present (so it visually rides on top of it)
                  if (state is! NavigationInProgress &&
                      _isMapSheetVisible &&
                      !_isModalOpen)
                    Positioned(
                      bottom: 332,
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'recenter_fab',
                        onPressed: recenterOnUser,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.gps_fixed,
                          color: Colors.blueAccent,
                        ),
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
                        isCourseUp: cameraController.isCourseUp,
                        onEndNavigation: _endNavigation,
                        onToggleCourseUp: () {
                          setState(() {
                            cameraController.toggleCourseUp();
                          });
                        },
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

                  // Expandable sheet — keep it alive offstage so async route fetching
                  // can still draw polylines even after we "hide" the sheet UI.
                  if (state is! NavigationInProgress && !_isModalOpen)
                    Positioned.fill(
                      child: Offstage(
                        offstage: !_isMapSheetVisible,
                        child: IgnorePointer(
                          ignoring: !_isMapSheetVisible,
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
