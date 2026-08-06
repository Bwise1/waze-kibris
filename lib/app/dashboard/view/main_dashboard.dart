import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/view/map_controller_mixin.dart';
import 'package:waze_kibris/app/dashboard/view/map_sheet.dart';
import 'package:waze_kibris/app/dashboard/view/navigation_overlay.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/arrival_summary_sheet.dart';
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
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/services/map_style_preference.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/app/dashboard/view/groups/group_list_screen.dart';
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
  Timer? _mapStyleTimer; // Re-evaluates Auto day/night at intervals
  String? _initialStyleUri; // Style the MapWidget is created with (stable)

  /// Live height of the home bottom sheet in px (-1 until first drag).
  /// Drives the floating buttons so they ride on top of the sheet,
  /// Waze-style, without rebuilding the whole screen per frame.
  final ValueNotifier<double> _sheetHeightPx = ValueNotifier(-1);
  MapboxRoute?
      _lastDrawnRoute; // Track last drawn route for reroute/refresh redraw
  StreamSubscription<WsMessage>? _groupLocationSub;
  final Map<String, dynamic> _groupMemberLocations = {};

  /// Lets a saved-place pin tap reuse the sheet's existing route flow.
  final GlobalKey<MapSheetState> _mapSheetKey = GlobalKey<MapSheetState>();
  DateTime? _lastNearbyUsersFetch;
  static const Duration _nearbyUsersFetchInterval = Duration(seconds: 30);

  // WebSocket position push: keeps the server's per-client lat/lng fresh so
  // report_update broadcasts filter against where the user actually is now,
  // not where they connected from.
  DateTime? _lastWsPositionPush;
  double? _lastWsRadiusPushed;
  static const Duration _wsPositionPushInterval = Duration(seconds: 15);
  static const double _wsRadiusIdleM = 5000; // matches server default floor
  static const double _wsRadiusNavigatingM = 15000; // ~10-15 min ahead on highway

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

  /// Push the current GPS position + preferred report broadcast radius to the
  /// backend so it can fan out new reports to us. Called on every position
  /// tick but throttled to [_wsPositionPushInterval] to avoid spam.
  ///
  /// Radius bumps up to [_wsRadiusNavigatingM] while a route is active so
  /// reports several minutes ahead on the route still push in real time. If
  /// the radius changed (nav started/stopped) we push immediately regardless
  /// of throttle.
  void _pushWsPositionIfDue(Position position) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;
    final userId = authState.user?.id;
    if (userId == null) return;

    final isNavigating = _navigationBloc.state is NavigationInProgress;
    final radius = isNavigating ? _wsRadiusNavigatingM : _wsRadiusIdleM;

    final radiusChanged = _lastWsRadiusPushed != radius;
    final now = DateTime.now();
    final due = _lastWsPositionPush == null ||
        now.difference(_lastWsPositionPush!) >= _wsPositionPushInterval;
    if (!radiusChanged && !due) return;

    context.read<WebSocketService>().updateSubscription(
          userId: userId,
          latitude: position.latitude,
          longitude: position.longitude,
          subscribeRadiusM: radius,
        );
    _lastWsPositionPush = now;
    _lastWsRadiusPushed = radius;
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

    _pushWsPositionIfDue(position);

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
          _connectWebSocketIfPossible();
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
    final position = _lastReportFetchPosition;
    if (position != null) {
      _fetchNearbyReports(position, force: true);
    }
  }

  /// Resolve the style for the current mode/sun position and apply it if it
  /// differs from what the map is showing.
  void _evaluateMapStyle() {
    if (!mounted) return;
    final uri = MapStylePreference.resolveStyleUri(
      latitude: _lastReportFetchPosition?.latitude,
      longitude: _lastReportFetchPosition?.longitude,
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
        subscribeRadiusM: _wsRadiusIdleM,
      );
      _lastWsRadiusPushed = _wsRadiusIdleM;
      _lastWsPositionPush = DateTime.now();
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
    MapStylePreference.mode.removeListener(_evaluateMapStyle);
    NavPuckPreference.style.removeListener(_onPuckStyleChanged);
    NavPuckPreference.mode.removeListener(_onPuckStyleChanged);
    NavSettings.mutedReportTypes.removeListener(_onReportFilterChanged);
    _mapStyleTimer?.cancel();
    getIt<PushNotificationService>().setGroupChatTapHandler(null);
    getIt<PushNotificationService>().setReportChatTapHandler(null);
    _groupLocationSub?.cancel();
    _sheetHeightPx.dispose();
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
                  // Redraw route and update snap service when bloc applies a
                  // new route (e.g. after reroute). fitCamera: false — swap
                  // the line silently like Waze; never yank the nav camera
                  // out to a route overview mid-drive.
                  if (state.route != _lastDrawnRoute) {
                    drawMapboxPolyline(state.route, fitCamera: false);
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

                        // Keep the nav camera's lower-third puck framing in
                        // sync with the actual map size (rotation, resize).
                        updateNavigationViewportPadding(
                          constraints.maxHeight,
                          MediaQuery.of(context).devicePixelRatio,
                        );

                        return mp.MapWidget(
                          key: _mapWidgetKey,
                          // Mapbox's dedicated navigation style (what the
                          // native turn-by-turn SDK ships). Resolved once at
                          // creation from the Auto/Day/Night preference;
                          // later switches go through applyMapStyleUri.
                          styleUri: _initialStyleUri ??=
                              MapStylePreference.resolveStyleUri(
                            latitude: _lastReportFetchPosition?.latitude,
                            longitude: _lastReportFetchPosition?.longitude,
                          ),
                          onMapCreated: (controller) {
                            markInitialStyleApplied(_initialStyleUri!);
                            onMapCreated(controller);
                          },
                          onTapListener: onMapTap,
                          // Native camera control during navigation (iOS):
                          // FollowPuckViewportState keeps camera and puck
                          // in 60fps lockstep on the render thread.
                          viewport: navViewport,
                          // Any user pan / pinch-zoom exits follow mode so
                          // the recenter pill swaps in for the speedometer.
                          // Rotate / tilt gestures aren't exposed by the
                          // Flutter plugin as separate listeners — they
                          // only surface through onCameraChangeListener,
                          // which also fires for our own programmatic
                          // easeTo calls and would create a feedback loop.
                          onScrollListener: (_) => onUserMapGesture(),
                          onZoomListener: (_) => onUserMapGesture(),
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

                  // Chats: one tap from the map, since it's a daily
                  // destination rather than a setting. Hidden while
                  // navigating so it can't distract or be mis-tapped.
                  if (state is! NavigationInProgress)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 68,
                      left: 16,
                      child: BlocBuilder<GroupsBloc, GroupsState>(
                        buildWhen: (prev, curr) => curr is GetGroupsSuccess,
                        builder: (context, groupsState) {
                          final unread = groupsState is GetGroupsSuccess
                              ? groupsState.totalUnreadCount
                              : 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                elevation: 4,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const GroupListScreen(),
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.forum_outlined,
                                      color: Colors.black87,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    constraints:
                                        const BoxConstraints(minWidth: 18),
                                    decoration: BoxDecoration(
                                      color: styles.theme.primary,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      textAlign: TextAlign.center,
                                      style: styles.typography.hairline
                                          .textColor(Colors.white)
                                          .copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                  // Floating buttons (recenter + report) ride on top of the
                  // bottom sheet as it drags — Waze-style. They follow the
                  // sheet edge up to a cap; past that the (later-painted)
                  // sheet simply slides over them.
                  if (state is! NavigationInProgress &&
                      _isMapSheetVisible &&
                      !_isModalOpen)
                    ValueListenableBuilder<double>(
                      valueListenable: _sheetHeightPx,
                      builder: (context, sheetPx, buttons) {
                        final screenH = MediaQuery.of(context).size.height;
                        // Before the first drag notification, assume the
                        // sheet's initial 36% resting height.
                        final height = sheetPx < 0 ? screenH * 0.36 : sheetPx;
                        final cap = screenH * 0.45;
                        final bottom = (height < cap ? height : cap) + 12;
                        return Positioned(
                          bottom: bottom,
                          right: 16,
                          child: buttons!,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton(
                            heroTag: 'recenter_fab',
                            onPressed: recenterOnUser,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.gps_fixed,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FloatingActionButton(
                            heroTag: 'global_report_fab',
                            backgroundColor: Colors.orange,
                            onPressed: () async {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    const ReportEventModal(),
                              );
                            },
                            child: const Icon(
                              Icons.report_problem,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
                            // Entering overview: take the camera back from
                            // the native follow state so the Dart overview
                            // framing can drive.
                            exitNativeViewport();
                            setIsFollowingUser(false);
                          } else {
                            setIsFollowingUser(true);
                            if (useNativeNavViewport) {
                              enterNativeFollowViewport(maxDurationMs: 1500);
                            }
                          }
                        },
                        onRecenter: () async {
                          setIsFollowingUser(true);
                          await recenterOnUser();
                          setState(() {});
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ArrivalSummarySheet(
        state: s,
        onDone: _endNavigation,
      ),
    );
  }
}
