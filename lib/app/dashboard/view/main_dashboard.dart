import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/app/dashboard/services/dashboard_side_effects.dart';
import 'package:waze_kibris/app/dashboard/services/nav_trace_recorder.dart';
import 'package:waze_kibris/app/dashboard/services/route_replay_service.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/view/map_controller_mixin.dart';
import 'package:waze_kibris/app/dashboard/view/map_sheet.dart';
import 'package:waze_kibris/app/dashboard/view/navigation_overlay.dart';
import 'package:waze_kibris/app/dashboard/view/widgets/debug_controls.dart';
import 'package:waze_kibris/app/dashboard/view/widgets/map_layer.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/route_bar.dart';
import 'package:waze_kibris/app/dashboard/view/widgets/arrival_flow.dart';
import 'package:waze_kibris/app/dashboard/view/route_overview.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/app/dashboard/view/widgets/map_button_cluster.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/services/map_style_preference.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/repositories/group_repository.dart';
import 'package:waze_kibris/core/services/nav_puck_preference.dart';
import 'package:waze_kibris/core/services/nav_settings.dart';
import 'package:waze_kibris/core/services/push_notification_service.dart';
import 'package:waze_kibris/app/dashboard/view/groups/group_chat_screen.dart';
import 'package:waze_kibris/app/dashboard/view/report_chat_screen.dart';
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
  late DashboardSideEffects _sideEffects;
  SearchSuggestion? _activeRouteSuggestion;
  bool _initialReportFetchScheduled = false;
  bool _isMapSheetVisible = true; // Control MapSheet visibility
  bool _wsConnectAttempted =
      false; // So we only connect once when auth is ready
  Timer?
      _routeRefreshTimer; // Timer for periodic route refresh during navigation
  Timer? _mapStyleTimer; // Re-evaluates Auto day/night at intervals
  String? _initialStyleUri; // Style the MapWidget is created with (stable)

  /// Live height of the home bottom sheet in px (-1 until first drag).
  /// Drives the floating buttons so they ride on top of the sheet,
  /// Waze-style, without rebuilding the whole screen per frame.
  final ValueNotifier<double> _sheetHeightPx = ValueNotifier(-1);

  /// Live map bearing in degrees, driving our own compass button.
  final ValueNotifier<double> _mapBearing = ValueNotifier(0);

  /// Height of the navigation bottom card in logical pixels, measured from
  /// the laid-out widget. The camera needs this so it can frame the puck in
  /// the *visible* map area instead of centring it behind the card.
  double _navCardHeight = 0;

  /// Last known map height, so padding can be recomputed when the card
  /// resizes without waiting for the next layout pass.
  double _lastMapHeightLogical = 0;

  /// Latches the arrival sheet to one showing per trip.
  bool _arrivalShown = false;
  MapboxRoute?
      _lastDrawnRoute; // Track last drawn route for reroute/refresh redraw
  StreamSubscription<WsMessage>? _groupLocationSub;
  final Map<String, dynamic> _groupMemberLocations = {};

  /// Lets a saved-place pin tap reuse the sheet's existing route flow.
  final GlobalKey<MapSheetState> _mapSheetKey = GlobalKey<MapSheetState>();

  @override
  NavigationBloc get navigationBloc => _navigationBloc;

  @override
  void onPositionUpdate(Position position) {
    _sideEffects.onPositionFix(position);

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
    _sideEffects = DashboardSideEffects(
      authBloc: context.read<AuthBloc>(),
      reportsBloc: context.read<ReportsBloc>(),
      navigationBloc: _navigationBloc,
      authRepository: context.read<AuthRepository>(),
      webSocketService: context.read<WebSocketService>(),
      displayNearbyUsers: (users) {
        if (mounted) displayNearbyUsersOnMap(users);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _mapReadyToBuild = true);
    });

    // Map style: load the persisted Auto/Day/Night preference, react to
    // changes from the settings screen, and re-evaluate Auto mode
    // periodically so a drive through dusk flips to the night style.
    MapStylePreference.load().then((_) {
      if (mounted) _evaluateMapStyle();
    });
    MapStylePreference.mode.addListener(_evaluateMapStyle);

    // Puck icon (arrow/car/bus/truck): load persisted choice and re-apply
    // the location puck when it changes in settings.
    NavPuckPreference.load().then((_) {
      if (mounted) refreshLocationPuck();
    });
    NavPuckPreference.style.addListener(_onPuckStyleChanged);
    // Walking/cycling swaps the puck for the duration of the trip.
    NavPuckPreference.mode.addListener(_onPuckStyleChanged);

    // Tapping a saved-place pin on the map opens the same place/route sheet
    // the Home/Work cards use.
    onSavedPlaceTapped = (place) {
      if (!mounted) return;
      _mapSheetKey.currentState?.openSavedLocation(place);
    };

    // Driving preferences (voice, units, avoid rules, report alerts…).
    NavSettings.load();
    // Hiding/showing a report type takes effect on the map immediately.
    NavSettings.mutedReportTypes.addListener(_onReportFilterChanged);
    _mapStyleTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _evaluateMapStyle(),
    );

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
          _sideEffects.connectWebSocket(isMounted: () => mounted);
        }
      }
    });

    // First report fetch is triggered when we get a position in onPositionUpdate,
    // with an 8s fallback timer started from build().

    // Live member locations for group trips arrive straight off the socket
    // (chat state moved to GroupChatBloc, so the map listens directly).
    _groupLocationSub =
        context.read<WebSocketService>().messages.listen((msg) {
      if (msg.type != 'group_location_update' || msg.content == null) return;
      try {
        final payload = jsonDecode(msg.content!) as Map<String, dynamic>;
        final userId = (payload['userId'] ?? payload['user_id'])?.toString();
        final lat = double.tryParse(payload['lat'].toString());
        final lng = double.tryParse(payload['lng'].toString());
        if (userId == null || lat == null || lng == null) return;
        _groupMemberLocations[userId] = {'lat': lat, 'lng': lng};
        displayGroupLocationsOnMap(_groupMemberLocations);
      } catch (_) {}
    });

    // Fetch the group list once at startup so unread badges are populated
    // and can then update live from the socket.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GroupsBloc>().add(const GetGroupsRequested());
      }
    });

    // Tapping a group-chat push notification opens that conversation.
    getIt<PushNotificationService>().setGroupChatTapHandler((groupId) async {
      if (!mounted) return;
      try {
        final response =
            await context.read<GroupRepository>().getGroupById(groupId);
        final group = response.data;
        if (group == null || !mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GroupChatScreen(group: group),
          ),
        );
      } catch (e) {
        debugPrint('Push tap: could not open group $groupId: $e');
      }
    });

    // Tapping a report-discussion notification opens that thread.
    getIt<PushNotificationService>()
        .setReportChatTapHandler((reportId, lat, lng) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReportChatScreen(
            reportId: reportId,
            latitude: lat,
            longitude: lng,
          ),
        ),
      );
    });
  }

  void _onPuckStyleChanged() {
    if (mounted) refreshLocationPuck();
  }

  void _onReportFilterChanged() {
    if (!mounted) return;
    // Re-fetch so types that were muted (and dropped from the cache) come
    // back when re-enabled.
    final position = _sideEffects.lastReportFetchPosition;
    if (position != null) {
      _sideEffects.fetchNearbyReports(position, force: true);
    }
  }

  /// Resolve the style for the current mode/sun position and apply it if it
  /// differs from what the map is showing.
  void _evaluateMapStyle() {
    if (!mounted) return;
    final position = _sideEffects.lastReportFetchPosition;
    final uri = MapStylePreference.resolveStyleUri(
      latitude: position?.latitude,
      longitude: position?.longitude,
    );
    applyMapStyleUri(uri);
  }

  @override
  void onMapStyleReloaded() {
    // Restore the active route after the style wipe.
    final route = _lastDrawnRoute;
    if (route != null) {
      drawMapboxPolyline(route, fitCamera: false);
    }
    // Saved-place pins live in runtime layers, which the reload also wiped.
    refreshSavedPlaces();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground: resume tracking and refresh navigation.
      resumeTrackingAndRefreshNavigation(_navigationBloc);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause tracking in background — but never during active navigation:
      // guidance must keep advancing (steps, voice, reroute) while the
      // screen is off or another app is in front. The Android foreground
      // service notification exists precisely for this. `inactive` also
      // fires on incoming calls / notification shade, where stopping
      // navigation would be a serious failure.
      if (_navigationBloc.state is! NavigationInProgress) {
        pausePositionTracking();
      }
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
          _sideEffects.lastReportFetchPosition = position;
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
    MapStylePreference.mode.removeListener(_evaluateMapStyle);
    NavPuckPreference.style.removeListener(_onPuckStyleChanged);
    NavPuckPreference.mode.removeListener(_onPuckStyleChanged);
    NavSettings.mutedReportTypes.removeListener(_onReportFilterChanged);
    _mapStyleTimer?.cancel();
    getIt<PushNotificationService>().setGroupChatTapHandler(null);
    getIt<PushNotificationService>().setReportChatTapHandler(null);
    _groupLocationSub?.cancel();
    _sheetHeightPx.dispose();
    _mapBearing.dispose();
    _sideEffects.dispose();
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

  void _startNavigation(MapboxRoute route,
      {TravelMode mode = TravelMode.drive}) {
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

    // fitCamera: false — the nav camera below owns the viewport. The old
    // unawaited fit-to-route raced against forceNavigationZoom, and when it
    // landed last it disabled follow mode and left the camera stuck on a
    // north-up overview for the whole trip.
    drawMapboxPolyline(route, fitCamera: false);
    setState(() => _lastDrawnRoute = route);
    updateMapForNavigationMode(true);
    if (useNativeNavViewport) {
      // Native follow-puck camera: set the lower-third padding on the map
      // (native never touches padding), pin the departure bearing so the
      // map is course-up before the car moves, and let the SDK drive.
      startNativeNavViewport(initialBearing: _initialRouteBearing(route));
    } else {
      forceNavigationZoom(initialBearing: _initialRouteBearing(route));
    }
    _navigationBloc.add(NavigationStarted(route: route, mode: mode));
    setIsFollowingUser(true);
    initializeSnapToRoad(route, mode: mode);

    // Draw lane guidance immediately for step 0 (position optional; first position update will refine)
    updateRouteProgress(route, 0, currentLegIndex: 0);

    // Start periodic route refresh timer (every 4 minutes)
    _startRouteRefreshTimer(route);
  }

  /// Bearing of the route's first meaningful segment (degrees, 0–360).
  /// Used to rotate the map course-up at trip start, when the car is
  /// stationary and GPS course is invalid.
  double? _initialRouteBearing(MapboxRoute route) {
    final coords = route.geometry.coordinates;
    if (coords.length < 2 || coords.first.length < 2) return null;
    final startLat = coords.first[1];
    final startLng = coords.first[0];
    for (final c in coords.skip(1)) {
      if (c.length < 2) continue;
      final d = Geolocator.distanceBetween(startLat, startLng, c[1], c[0]);
      if (d >= 5) {
        final bearing =
            Geolocator.bearingBetween(startLat, startLng, c[1], c[0]);
        return (bearing + 360) % 360;
      }
    }
    return null;
  }

  void _startRouteRefreshTimer(MapboxRoute initialRoute) {
    // Cancel any existing timer
    _routeRefreshTimer?.cancel();

    // Refresh route every 2 minutes to get updated traffic conditions
    // (native SDK default: routeRefreshPeriod = 120s).
    _routeRefreshTimer =
        Timer.periodic(const Duration(minutes: 2), (timer) async {
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
            profile: currentState.mode.mapboxProfile,
            alternatives: false,
          );

          if (response.routes.isNotEmpty) {
            final refreshedRoute = response.routes.first;

            // Only apply the refresh when traffic conditions meaningfully
            // changed the route. Re-dispatching NavigationStarted resets step
            // progress and replays the departure voice prompt, and the
            // clear+redraw makes the route line blink — none of that is
            // acceptable every 2 minutes for a near-identical route.
            final distanceDelta =
                (refreshedRoute.distance - currentState.remainingDistance)
                    .abs();
            final durationDelta =
                (refreshedRoute.duration - currentState.remainingDuration)
                    .abs();
            if (distanceDelta < 50 && durationDelta < 30) {
              debugPrint(
                  '🔄 Route refresh: no meaningful change (Δ${distanceDelta.toStringAsFixed(0)}m, Δ${durationDelta.toStringAsFixed(0)}s) — keeping current route');
              return;
            }

            debugPrint(
                '✅ Route refreshed! New distance: ${refreshedRoute.distance}m, duration: ${refreshedRoute.duration}s');

            // Update navigation with refreshed route. The NavigationBloc
            // listener redraws the polyline (fitCamera: false) — no direct
            // draw here, or the route gets cleared and redrawn twice.
            _navigationBloc.add(
                NavigationStarted(route: refreshedRoute, mode: currentState.mode));
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

    // The debug simulator keeps emitting fixes after the trip ends — into
    // free-drive, where they fight the real GPS for the camera.
    RouteReplayService.instance.stop();

    _navigationBloc.add(NavigationStopped());
    updateMapForNavigationMode(false);
    clearRoutePolyline();
    clearSnapToRoad();
    _clearRouteBar();
    // Hand the camera back to the user. If follow was off (they panned
    // during the trip), ending navigation otherwise leaves the map parked
    // on the destination with the puck somewhere off-screen.
    setIsFollowingUser(true);
    // Restore MapSheet visibility when navigation ends
    setState(() {
      _isMapSheetVisible = true;
      _lastDrawnRoute = null;
      // Re-arm for the next trip, or arrival would only ever fire once
      // per app launch.
      _arrivalShown = false;
      _navCardHeight = 0;
    });
  }

  void _onReportsReceived(List<ReportData> reports) {
    debugPrint('📍 Received ${reports.length} reports to display on map');
    displayReportsOnMap(reports);
  }

  final GlobalKey _mapWidgetKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Schedule fallback: if we don't get a position from the stream within
    // 8s, fetch with getCurrentPosition(). Scheduled once, on the first build.
    if (!_initialReportFetchScheduled) {
      _initialReportFetchScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sideEffects.scheduleInitialReportFetchFallback(
          isMounted: () => mounted,
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
                  _sideEffects.connectWebSocket(isMounted: () => mounted);
                }
              },
            ),
            BlocListener<NavigationBloc, NavigationState>(
              listener: (context, state) {
                if (state is NavigationInProgress) {
                  // Redraw route and update snap service when bloc applies a
                  // new route (e.g. after reroute). fitCamera: false — swap
                  // the line silently like Waze; never yank the nav camera
                  // out to a route overview mid-drive.
                  // Never redraw once the trip is complete: position events
                  // queued behind NavigationStopped still emit InProgress
                  // states, and each was re-drawing the route line right
                  // after _endNavigation cleared it — the "route line stays
                  // after OK" bug.
                  if (!state.isNavigationComplete &&
                      state.route != _lastDrawnRoute) {
                    drawMapboxPolyline(state.route, fitCamera: false);
                    setState(() => _lastDrawnRoute = state.route);
                  }
                  // isNavigationComplete stays true on every subsequent
                  // position fix, so without this latch the arrival sheet
                  // was pushed once per second, stacking duplicates.
                  if (state.isNavigationComplete && !_arrivalShown) {
                    _arrivalShown = true;
                    _showNavigationCompleteDialog();
                  }
                } else if (state is NavigationInitial) {
                  // Self-healing failsafe: whenever navigation returns to
                  // initial/idle, ensure MapSheet is restored regardless of
                  // how it was hidden — and clear the route line again.
                  // Position events queued behind NavigationStopped can
                  // redraw it after _endNavigation's clear (mid-trip End has
                  // this race too, where isNavigationComplete is false), so
                  // the state that means "no trip" must also mean "no line".
                  clearRoutePolyline();
                  _lastDrawnRoute = null;
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
                  _sideEffects.lastReportsWereEmpty = state.data.isEmpty;
                  _onReportsReceived(state.data);
                } else if (state is GetSavedLocationsSuccess) {
                  // Home/Work/etc. as pins on the map, tappable to navigate.
                  displaySavedPlacesOnMap(state.data);
                } else if (state is ReportError) {
                  debugPrint('🚨 Report fetch error: ${state.message}');
                }
              },
            ),
          ],
          child: BlocBuilder<NavigationBloc, NavigationState>(
            // The whole Stack under this builder — MapWidget shell,
            // LayoutBuilder, Positioned subtrees — used to rebuild on every
            // GPS fix because NavigationInProgress emits a fresh state per
            // fix (userPosition, distances, speed all change). Gate on the
            // things that actually toggle UI: entering/leaving nav, the
            // overview flip, and route swaps (reroute). identical() on
            // route is deliberate: reroute swaps the object, position fixes
            // do not. Per-fix numbers live in the leaf BlocSelectors below.
            buildWhen: (prev, next) =>
                prev.runtimeType != next.runtimeType ||
                (prev is NavigationInProgress &&
                    next is NavigationInProgress &&
                    (prev.isOverviewVisible != next.isOverviewVisible ||
                        !identical(prev.route, next.route))),
            builder: (context, state) {
              return Stack(
                children: [
                  // Map widget (full screen)
                  Positioned.fill(
                    child: MapLayer(
                      mapWidgetKey: _mapWidgetKey,
                      readyToBuild: _mapReadyToBuild,
                      lastReportFetchPosition: _sideEffects.lastReportFetchPosition,
                      initialStyleUri: _initialStyleUri,
                      onInitialStyleResolved: (uri) {
                        _initialStyleUri ??= uri;
                      },
                      onMapCreated: (controller) {
                        markInitialStyleApplied(_initialStyleUri!);
                        onMapCreated(controller);
                      },
                      onMapTap: onMapTap,
                      viewport: navViewport,
                      onUserMapGesture: onUserMapGesture,
                      onCameraChange: (data) {
                        _mapBearing.value = data.cameraState.bearing;
                      },
                      // Recompute nav-camera padding when the map actually
                      // resizes (>1px). The plan A3 pattern.
                      onMapResize: (newHeight) {
                        if ((newHeight - _lastMapHeightLogical).abs() <= 1) {
                          return;
                        }
                        _lastMapHeightLogical = newHeight;
                        if (!mounted) return;
                        updateNavigationViewportPadding(
                          newHeight,
                          MediaQuery.of(context).devicePixelRatio,
                          bottomObstructionLogical: _navCardHeight,
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
                  const MenuButton(),

                  // Compass — hidden during navigation, where the course-up
                  // toggle in the nav overlay owns this job instead.
                  if (state is! NavigationInProgress)
                    CompassOverlayButton(
                      mapBearing: _mapBearing,
                      onTap: resetMapBearingToNorth,
                    ),

                  // Chats — hidden while navigating.
                  if (state is! NavigationInProgress) const ChatsButton(),

                  // Floating buttons (recenter + report) ride on top of the
                  // bottom sheet as it drags — Waze-style.
                  if (state is! NavigationInProgress &&
                      _isMapSheetVisible &&
                      !_isModalOpen)
                    FloatingSheetButtons(
                      sheetHeightPx: _sheetHeightPx,
                      onRecenter: recenterOnUser,
                    ),

                  // Navigation UI
                  // Debug-only drive simulator. Compiled out of release
                  // builds; lets the emulator/simulator produce a realistic
                  // drive with bearing and speed.
                  if (!kReleaseMode && state is NavigationInProgress)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 124,
                      right: 16,
                      child: ReplayControl(
                        route: _lastDrawnRoute,
                      ),
                    ),

                  // Exports saved nav traces so a whole day of test drives
                  // can be pulled off the phone in one go. Visible outside
                  // navigation too — that's when you're back at the desk
                  // wanting to send the batch. Debug/profile builds only.
                  if (NavTraceRecorder.isAvailable)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 216,
                      right: 16,
                      child: TraceShareButton(
                        isNavigating: state is NavigationInProgress,
                      ),
                    ),

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
                      // Measure the nav card so the camera can keep the puck
                      // above it rather than centring it underneath.
                      MeasureHeight(
                        onHeight: (h) {
                          if ((h - _navCardHeight).abs() < 1) return;
                          _navCardHeight = h;
                          updateNavigationViewportPadding(
                            _lastMapHeightLogical,
                            MediaQuery.of(context).devicePixelRatio,
                            bottomObstructionLogical: h,
                          );
                        },
                        // BlocSelector so per-fix rebuilds only touch the
                        // overlay subtree, not the whole Stack above. The
                        // outer `state` is phase-scoped (see buildWhen) so
                        // this closure captures a stable NavigationInProgress
                        // reference for the trip.
                        child: BlocSelector<NavigationBloc, NavigationState,
                            NavTelemetry>(
                          selector: (s) => s is NavigationInProgress
                              ? NavTelemetry.from(s)
                              : const NavTelemetry(
                                  distanceToNextManeuver: 0,
                                  remainingDistance: 0,
                                  remainingDuration: 0,
                                  currentSpeed: null,
                                  speedLimit: null,
                                  currentStepIndex: 0,
                                  isRerouting: false,
                                  hasCongestionData: false,
                                ),
                          builder: (context, telemetry) => NavigationOverlay(
                            navigationState: state,
                            telemetry: telemetry,
                            isCourseUp: cameraController.isCourseUp,
                            isFollowingUser: isFollowingUser,
                            onEndNavigation: _endNavigation,
                            onToggleCourseUp: () {
                              setState(() {
                                cameraController.toggleCourseUp();
                              });
                            },
                            onToggleOverview: () {
                              _navigationBloc.add(NavigationOverviewToggled());
                              if (!state.isOverviewVisible) {
                                // Entering overview: take the camera back
                                // from the native follow state so the Dart
                                // overview framing can drive.
                                exitNativeViewport();
                                setIsFollowingUser(false);
                              } else {
                                setIsFollowingUser(true);
                                if (useNativeNavViewport) {
                                  enterNativeFollowViewport(
                                      maxDurationMs: 1500);
                                }
                              }
                            },
                            onRecenter: () async {
                              setIsFollowingUser(true);
                              await recenterOnUser();
                              setState(() {});
                            },
                          ),
                        ),
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
                          child: NotificationListener<
                              DraggableScrollableNotification>(
                            onNotification: (notification) {
                              _sheetHeightPx.value = notification.extent *
                                  MediaQuery.of(context).size.height;
                              return false;
                            },
                            child: MapSheet(
                            key: _mapSheetKey,
                            onSuggestionSelected: _onSuggestionSelected,
                            onDrawMapboxPolyline:
                                (route, {alternativeRoutes}) {
                              drawMapboxPolyline(
                                route,
                                alternativeRoutes: alternativeRoutes,
                              );
                            },
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
    final s = _navigationBloc.state;
    if (s is! NavigationInProgress) {
      _endNavigation();
      return;
    }
    showArrivalFlow(
      context: context,
      state: s,
      onSettleCamera: settleCameraOnArrival,
      onEnd: _endNavigation,
      isMounted: () => mounted,
    );
  }
}

