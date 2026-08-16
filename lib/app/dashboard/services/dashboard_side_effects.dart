import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/user/nearby_user.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

/// Off-widget dashboard side-effect orchestrator.
///
/// Holds throttle bookkeeping for the three per-position-fix side effects
/// (reports fetch, nearby-users fetch, WS position push) so the widget
/// State only has to call [onPositionFix] and forget. Everything the
/// service needs comes through the constructor — no `context.read` from
/// the service body, which keeps it testable without a widget tree.
class DashboardSideEffects {
  DashboardSideEffects({
    required this.authBloc,
    required this.reportsBloc,
    required this.navigationBloc,
    required this.authRepository,
    required this.webSocketService,
    required this.displayNearbyUsers,
  });

  final AuthBloc authBloc;
  final ReportsBloc reportsBloc;
  final NavigationBloc navigationBloc;
  final AuthRepository authRepository;
  final WebSocketService webSocketService;

  /// Delegated to the map controller mixin — the service should not know
  /// about Mapbox layers.
  final void Function(List<NearbyUser> users) displayNearbyUsers;

  // -- Nearby users throttle -----------------------------------------------
  DateTime? _lastNearbyUsersFetch;
  static const Duration _nearbyUsersFetchInterval = Duration(seconds: 30);

  // -- WebSocket position push --------------------------------------------
  // Keeps the server's per-client lat/lng fresh so report_update broadcasts
  // filter against where the user actually is now, not where they connected
  // from.
  DateTime? _lastWsPositionPush;
  double? _lastWsRadiusPushed;
  static const Duration _wsPositionPushInterval = Duration(seconds: 15);
  static const double _wsRadiusIdleM = 5000; // matches server default floor
  static const double _wsRadiusNavigatingM =
      15000; // ~10-15 min ahead on highway

  // -- Reports fetch state ------------------------------------------------
  Position? _lastReportFetchPosition;
  bool _lastReportsWereEmpty = false;
  bool _retriedEmptyReportsFetch = false;
  bool _initialReportsFetched = false;
  Timer? _initialReportFetchFallbackTimer;

  /// Snapshot of the most recent successful fetch position; used by the
  /// screen for the initial camera seed and for style refresh geometry.
  Position? get lastReportFetchPosition => _lastReportFetchPosition;

  /// Called by the ReportsBloc listener to tell the service the latest
  /// batch was empty so a future position tick can force a retry.
  set lastReportsWereEmpty(bool value) => _lastReportsWereEmpty = value;

  /// Seed [_lastReportFetchPosition] from a last-known-position preload so
  /// the "moved more than 1km since last fetch" gate works from fix 1.
  set lastReportFetchPosition(Position? value) =>
      _lastReportFetchPosition = value;

  /// The main entry point: called once per position fix by the map
  /// controller mixin's [onPositionUpdate].
  void onPositionFix(Position position) {
    bool isFirstFetch = false;
    // First report fetch: wait for location from stream instead of timer.
    if (!_initialReportsFetched) {
      _initialReportFetchFallbackTimer?.cancel();
      _initialReportFetchFallbackTimer = null;
      _initialReportsFetched = true;
      isFirstFetch = true;
      debugPrint(
          '🚨 First report fetch triggered by position: '
          '${position.latitude}, ${position.longitude}');
    }
    // Retry once when we had empty reports and position has moved significantly.
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
    fetchNearbyReports(position, force: isFirstFetch);
    _fetchNearbyUsersIfDue(position);
    _pushWsPositionIfDue(position);
  }

  /// Fire the reports fetch (via bloc) if enough distance has passed since
  /// the last one. [force] bypasses the distance gate — used for the first
  /// fetch on app open and the empty-results retry.
  void fetchNearbyReports(Position position, {bool force = false}) {
    var shouldFetch = force;

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

      reportsBloc.add(
        ReportsEvent.getNearByReports(
          radius: 5000, // meters: same area so multiple users see same reports
          lat: position.latitude.toString(),
          long: position.longitude.toString(),
        ),
      );
    }
  }

  /// Schedule the 8s fallback that triggers a manual `getCurrentPosition`
  /// call if the position stream hasn't produced a fix yet. Called from
  /// `build()` on the very first pass.
  void scheduleInitialReportFetchFallback({required bool Function() isMounted}) {
    _initialReportFetchFallbackTimer = Timer(
      const Duration(seconds: 8),
      () async {
        if (!isMounted() || _initialReportsFetched) return;
        debugPrint(
            '🚨 Report fetch fallback: no position yet, using getCurrentPosition()');
        _initialReportsFetched = true;
        try {
          await Future<void>.delayed(const Duration(seconds: 3));
          final currentPosition = await Geolocator.getCurrentPosition();
          if (isMounted()) fetchNearbyReports(currentPosition, force: true);
        } catch (e) {
          debugPrint('Error getting position for report fetching: $e');
        }
      },
    );
  }

  Future<void> _fetchNearbyUsersIfDue(Position position) async {
    final now = DateTime.now();
    if (_lastNearbyUsersFetch != null &&
        now.difference(_lastNearbyUsersFetch!) < _nearbyUsersFetchInterval) {
      return;
    }
    _lastNearbyUsersFetch = now;

    try {
      final users = await authRepository.getNearbyUsers(
        position.latitude,
        position.longitude,
        radiusM: 2000,
      );
      displayNearbyUsers(users);
    } catch (e) {
      debugPrint('Nearby users fetch error: $e');
    }
  }

  /// Push the current GPS position + preferred report broadcast radius to
  /// the backend so it can fan out new reports to us. Called on every
  /// position tick but throttled to [_wsPositionPushInterval] to avoid
  /// spam.
  ///
  /// Radius bumps up to [_wsRadiusNavigatingM] while a route is active so
  /// reports several minutes ahead on the route still push in real time.
  /// If the radius changed (nav started/stopped) we push immediately
  /// regardless of throttle.
  void _pushWsPositionIfDue(Position position) {
    final authState = authBloc.state;
    if (authState is! AuthSuccess) return;
    final userId = authState.user?.id;
    if (userId == null) return;

    final isNavigating = navigationBloc.state is NavigationInProgress;
    final radius = isNavigating ? _wsRadiusNavigatingM : _wsRadiusIdleM;

    final radiusChanged = _lastWsRadiusPushed != radius;
    final now = DateTime.now();
    final due = _lastWsPositionPush == null ||
        now.difference(_lastWsPositionPush!) >= _wsPositionPushInterval;
    if (!radiusChanged && !due) return;

    webSocketService.updateSubscription(
      userId: userId,
      latitude: position.latitude,
      longitude: position.longitude,
      subscribeRadiusM: radius,
    );
    _lastWsPositionPush = now;
    _lastWsRadiusPushed = radius;
  }

  /// One-shot WS connect on auth-ready. Grabs current or last-known
  /// position and opens the socket with the idle radius. The screen calls
  /// this once when it first sees an authenticated user.
  /// Returns true only if a connection attempt was actually made, so the
  /// caller can re-arm its once-only guard when we bailed early (no
  /// position yet, not mounted). Latching the guard on a bailed attempt
  /// left the socket silently dead for the whole session.
  Future<bool> connectWebSocket({required bool Function() isMounted}) async {
    debugPrint('🔌 WebSocket: connectWebSocket called');
    final authState = authBloc.state;
    String? userId;

    if (authState is AuthSuccess && authState.user != null) {
      userId = authState.user!.id;
    } else {
      debugPrint(
          '🔌 WebSocket: skip connect (not AuthSuccess or no user: '
          '${authState.runtimeType})');
      return false;
    }

    try {
      debugPrint('🔌 WebSocket: fetching position...');
      final position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();

      if (!isMounted() || position == null) {
        debugPrint(
            '🔌 WebSocket: skip connect (no position or not mounted). '
            'mounted: ${isMounted()}, position: $position');
        return false;
      }

      debugPrint(
          '🔌 WebSocket: connecting (userId: $userId, lat: ${position.latitude}, '
          'lng: ${position.longitude})');
      await webSocketService.connect(
        userId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
        subscribeRadiusM: _wsRadiusIdleM,
      );
      _lastWsRadiusPushed = _wsRadiusIdleM;
      _lastWsPositionPush = DateTime.now();
      return true;
    } catch (e, st) {
      debugPrint('🔌 WebSocket: connect failed: $e');
      debugPrint('🔌 WebSocket: $st');
      // The service's own reconnect loop takes over once a channel existed;
      // if we never got that far, let the caller re-arm and retry.
      return false;
    }
  }

  void dispose() {
    _initialReportFetchFallbackTimer?.cancel();
  }
}
