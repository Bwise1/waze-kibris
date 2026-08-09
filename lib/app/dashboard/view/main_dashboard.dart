import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/app/dashboard/services/nav_trace_recorder.dart';
import 'package:waze_kibris/app/dashboard/services/route_replay_service.dart';
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
    _mapBearing.dispose();
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
                  // isNavigationComplete stays true on every subsequent
                  // position fix, so without this latch the arrival sheet
                  // was pushed once per second, stacking duplicates.
                  if (state.isNavigationComplete && !_arrivalShown) {
                    _arrivalShown = true;
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
                        // The padding call used to run inline every build
                        // (which the per-fix top-level rebuild did every
                        // second). Now: only fire on a real height change,
                        // and defer to post-frame so build stays pure.
                        final newHeight = constraints.maxHeight;
                        if ((newHeight - _lastMapHeightLogical).abs() > 1) {
                          _lastMapHeightLogical = newHeight;
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final navCardHeight = _navCardHeight;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            updateNavigationViewportPadding(
                              newHeight,
                              dpr,
                              bottomObstructionLogical: navCardHeight,
                            );
                          });
                        }

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
                          // These fire for programmatic camera moves too, so
                          // check for a real finger: a genuine gesture always
                          // reports a touch position inside the map view.
                          onScrollListener: (ctx) => onUserMapGesture(ctx),
                          onZoomListener: (ctx) => onUserMapGesture(ctx),
                          // Drives our own compass. Only the notifier
                          // updates, so this doesn't rebuild the screen.
                          onCameraChangeListener: (data) {
                            _mapBearing.value =
                                data.cameraState.bearing;
                          },
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
                    child: _MapCircleButton(
                      icon: Icons.menu,
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
                    ),
                  ),

                  // Compass, exactly opposite the menu button — same 42pt
                  // circle, same safe-area offset, so the two align.
                  // Hidden during navigation, where the course-up toggle
                  // in the nav overlay owns this job instead.
                  if (state is! NavigationInProgress)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      right: 16,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _mapBearing,
                        builder: (context, bearing, _) => _MapCompassButton(
                          bearing: bearing,
                          onTap: resetMapBearingToNorth,
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
                              _MapCircleButton(
                                icon: Icons.forum_outlined,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const GroupListScreen(),
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
                      // Same 42pt circle as the menu/chat buttons opposite,
                      // so every floating map control reads as one family.
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MapCircleButton(
                            icon: Icons.gps_fixed,
                            iconColor: Colors.blueAccent,
                            onTap: recenterOnUser,
                          ),
                          const SizedBox(height: 12),
                          _MapCircleButton(
                            icon: Icons.report_problem,
                            iconColor: Colors.white,
                            backgroundColor: Colors.orange,
                            onTap: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    const ReportEventModal(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  // Navigation UI
                  // Debug-only drive simulator. Compiled out of release
                  // builds; lets the emulator/simulator produce a realistic
                  // drive with bearing and speed.
                  if (!kReleaseMode && state is NavigationInProgress)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 124,
                      right: 16,
                      child: _ReplayControl(
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
                      child: _TraceShareButton(
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
                      _MeasureHeight(
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

    // What Waze and Google do on arrival: stop driving the camera and level
    // the map out. Course-up 3D framing exists to show the road ahead — once
    // you've stopped there is no road ahead, and staying tilted and rotated
    // makes it hard to see where you actually are relative to the building.
    settleCameraOnArrival();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ArrivalSummarySheet(
        state: s,
        // Only dismiss the sheet here; the teardown runs below so that
        // swiping it away tears down too.
        onDone: () {},
      ),
    ).whenComplete(() {
      // The sheet can also be dismissed by swiping or tapping the scrim,
      // which skips the Done button entirely. Ending navigation here covers
      // every path — otherwise a swipe left the route line, snap service and
      // nav state running with no UI to stop them.
      if (mounted) _endNavigation();
    });
  }
}

/// Circular floating control on the map — menu, chat, recenter, report.
///
/// All four share one size and shape so they read as a single family; the
/// default FloatingActionButton is 56pt with a squircle shape, which made
/// the recenter/report pair noticeably larger than the menu and chat
/// buttons opposite them.
class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.black87,
    this.backgroundColor = Colors.white,
  });

  /// Matches the menu button: 22pt icon + 10pt padding = 42pt.
  static const double diameter = 42;
  static const double iconSize = 22;

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all((diameter - iconSize) / 2),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

/// Compass matching the other floating map controls. Rotates with the map
/// and snaps the map back to north when tapped, like Google Maps.
class _MapCompassButton extends StatelessWidget {
  const _MapCompassButton({required this.bearing, required this.onTap});

  final double bearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: _MapCircleButton.diameter,
          height: _MapCircleButton.diameter,
          child: Center(
            child: Transform.rotate(
              // Map bearing is clockwise; the needle turns the other way to
              // keep pointing at true north.
              angle: -bearing * math.pi / 180,
              child: Icon(
                Icons.navigation,
                size: _MapCircleButton.iconSize,
                color: styles.theme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports its child's laid-out height. Used to measure the navigation card
/// so the camera can frame the puck above it — hardcoding a height would
/// drift the moment the card's content changes (lane guidance, exit numbers).
class _MeasureHeight extends StatefulWidget {
  const _MeasureHeight({required this.child, required this.onHeight});
  final Widget child;
  final ValueChanged<double> onHeight;

  @override
  State<_MeasureHeight> createState() => _MeasureHeightState();
}

class _MeasureHeightState extends State<_MeasureHeight> {
  final GlobalKey _key = GlobalKey();

  void _report(Duration _) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    widget.onHeight(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    // Measure after layout; the callback fires each build so the padding
    // follows the card as its content grows and shrinks.
    WidgetsBinding.instance.addPostFrameCallback(_report);
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// Debug-only: flush the nav trace and hand it to the share sheet, so a
/// drive recorded on a real phone can be pulled off and analysed.
class _TraceShareButton extends StatefulWidget {
  const _TraceShareButton({this.isNavigating = false});

  /// Whether a trip is in progress — decides if a stopped recorder is a
  /// failure (red 'off') or just the idle state between trips.
  final bool isNavigating;

  @override
  State<_TraceShareButton> createState() => _TraceShareButtonState();
}

class _TraceShareButtonState extends State<_TraceShareButton> {
  Timer? _tick;
  int _savedTrips = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Refresh the event counter so it's visibly climbing — proof the
    // recorder is alive without needing a console. While recording, the
    // count comes from memory, so skip the directory listing and only pay
    // for a cheap setState; when idle, list the batch on a slow cadence.
    // (The first version listed the directory every 2s forever — needless
    // filesystem churn on a phone that's already running GPS + map.)
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      if (NavTraceRecorder.instance.isRecording) {
        if (mounted) setState(() {});
      } else if (_tickCount++ % 5 == 0) {
        _refresh();
      }
    });
  }

  int _tickCount = 0;

  Future<void> _refresh() async {
    final traces = await NavTraceRecorder.instance.listTraces();
    if (mounted) setState(() => _savedTrips = traces.length);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Share every saved trip in one go. Recording keeps running — the
  /// active file is flushed first so it exports as a valid snapshot.
  Future<void> _share(BuildContext context) async {
    final recorder = NavTraceRecorder.instance;
    await recorder.flushNow();
    final traces = await recorder.listTraces();
    if (traces.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final f in traces) XFile(f.path)],
        text: 'Nav traces — ${traces.length} trip(s)',
      ),
    );
  }

  /// Long-press: clear the batch after it's been sent. Refused while a
  /// trip is recording so the active file isn't deleted under the sink.
  Future<void> _deleteAll(BuildContext context) async {
    final deleted = await NavTraceRecorder.instance.deleteAll();
    await _refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted > 0
            ? 'Deleted $deleted trace(s)'
            : 'Nothing deleted (recording in progress?)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recorder = NavTraceRecorder.instance;
    final recording = recorder.isRecording;
    final navigating = widget.isNavigating;

    // Nothing recorded and nothing recording: stay out of the way.
    if (!recording && !navigating && _savedTrips == 0) {
      return const SizedBox.shrink();
    }

    // Phone-only feedback: with no console on a real drive, a silent
    // failure to record would waste the whole trip. A climbing count means
    // it's writing; red 'off' during navigation means it isn't. Between
    // trips the badge shows how many traces are banked for export.
    final failed = navigating && !recording;
    final label = recording
        ? '${recorder.lineCount}'
        : failed
            ? 'off'
            : '$_savedTrips 🚗';

    return GestureDetector(
      onTap: () => _share(context),
      onLongPress: recording ? null : () => _deleteAll(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: failed ? Colors.red.shade700 : Colors.black87,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.error_outline : Icons.ios_share,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Debug-only control for the drive simulator: play/stop, and cycle the
/// playback speed. Never present in release builds.
class _ReplayControl extends StatefulWidget {
  const _ReplayControl({required this.route});
  final MapboxRoute? route;

  @override
  State<_ReplayControl> createState() => _ReplayControlState();
}

class _ReplayControlState extends State<_ReplayControl> {
  static const _speeds = [1.0, 2.0, 4.0, 8.0];
  int _speedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final replay = RouteReplayService.instance;
    final running = replay.isRunning;
    return Column(
      children: [
        _MapCircleButton(
          icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
          backgroundColor: running ? Colors.red : Colors.black87,
          iconColor: Colors.white,
          onTap: () {
            final route = widget.route;
            if (route == null) return;
            setState(() {
              if (running) {
                replay.stop();
              } else {
                replay.start(route, speedMultiplier: _speeds[_speedIndex]);
              }
            });
          },
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _speedIndex = (_speedIndex + 1) % _speeds.length;
              replay.setSpeedMultiplier(_speeds[_speedIndex]);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_speeds[_speedIndex].toStringAsFixed(0)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
