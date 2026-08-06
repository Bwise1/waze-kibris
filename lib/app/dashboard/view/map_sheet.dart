import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:waze_kibris/app/dashboard/view/place_details_screen.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/route_loading_overlay.dart';
import 'package:waze_kibris/app/dashboard/view/route_selection_widget.dart';
import 'package:waze_kibris/app/dashboard/view/search_page.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/location/recent_location.dart';
import 'package:waze_kibris/core/models/navigation/travel_mode.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/di.dart';

/// Compact "Where to?" pill that sits at the bottom of the map.
///
/// Tapping it pushes [SearchPage] — a plain [Scaffold] with
/// [resizeToAvoidBottomInset: true] that handles keyboard insets natively.
///
/// All post-selection flows (PlaceDetailsSheet, RouteSelectionSheet) are
/// handled here using the map's [BuildContext], so modals appear correctly
/// on top of the map.
class MapSheet extends StatefulWidget {
  const MapSheet({
    this.onSearchedDestination,
    this.onSuggestionSelected,
    this.onDrawMapboxPolyline,
    this.onStartNavigation,
    this.onLocationSelected,
    this.onRouteSelectionDismissed,
    super.key,
  });

  final ValueChanged<LatLng>? onSearchedDestination;
  final ValueChanged<SearchSuggestion>? onSuggestionSelected;
  final void Function(
    MapboxRoute route, {
    List<MapboxRoute>? alternativeRoutes,
  })? onDrawMapboxPolyline;
  final void Function(MapboxRoute route, {TravelMode mode})? onStartNavigation;
  final VoidCallback?
      onLocationSelected; // Callback to hide MapSheet when location is selected
  final VoidCallback?
      onRouteSelectionDismissed; // Callback to restore MapSheet when route selection is dismissed

  @override
  State<MapSheet> createState() => MapSheetState();
}

class MapSheetState extends State<MapSheet> {
  /// Open the place/route flow for a saved location. Public so the map can
  /// trigger the exact same flow when one of its saved-place pins is
  /// tapped — no duplicated routing logic.
  Future<void> openSavedLocation(SavedLocations location) =>
      _onSavedLocationTap(location);

  final PlacesService _placesService = getIt<PlacesService>();

  /// Refetch routes for a different travel mode when the user toggles the
  /// drive/walk/cycle chip in [RouteSelectionSheet]. Returns the new routes
  /// (or null on failure — the sheet then rolls the toggle back).
  Future<List<MapboxRoute>?> _refetchRoutesForMode({
    required TravelMode mode,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final response = await _placesService.fetchMapboxDirections(
        originLat: position.latitude,
        originLng: position.longitude,
        destinationLat: destLat,
        destinationLng: destLng,
        profile: mode.mapboxProfile,
        alternatives: true,
      );
      if (response.routes.isEmpty) return null;
      return response.routes;
    } catch (e) {
      debugPrint('⚠️ [ROUTE_SHEET] Mode-change refetch failed: $e');
      return null;
    }
  }

  // ── Saved / recent state (mirrors SearchPage) ────────────────────────────
  List<SavedLocations> _savedLocations = [];
  List<RecentLocation> _recentLocations = [];
  bool _recentLocationsLoading = false;
  int _recentBuildCounter = 0;

  // One controller for the sheet's (read-only) search bar. Allocating a new
  // TextEditingController on every rebuild leaked controllers and added
  // per-frame work while the sheet animated.
  final TextEditingController _searchBarController = TextEditingController();

  @override
  void dispose() {
    _searchBarController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReportsBloc>().add(ReportsEvent.getSavedLocations());
        context.read<ReportsBloc>().add(ReportsEvent.getRecentLocations());
      }
    });
  }

  // ── Saved-location helpers ────────────────────────────────────────────────
  List<SavedLocations> _filterAddedLocation(List<SavedLocations> locations) {
    final result = <SavedLocations>[];
    final seen = <String>[];
    for (final e in locations) {
      if (e.name.toLowerCase() == 'home' || e.name.toLowerCase() == 'work') {
        continue;
      }
      if (!seen.contains(e.name) && e.placeId != null) {
        result.add(e);
        seen.add(e.name);
      }
    }
    return result;
  }

  String _getIconType(String type) {
    if (type == 'Home') return Assets.icons.homeBg.path;
    if (type == 'Hospital') return Assets.icons.hospital.path;
    if (type == 'Park') return Assets.icons.park.path;
    if (type == 'Gas') return Assets.icons.gas.path;
    if (type == 'Food') return Assets.icons.food.path;
    if (type == 'Work') return Assets.icons.briefcasePng.path;
    return Assets.icons.globePng.path;
  }

  // ── Post-selection flow: suggestion tapped in SearchPage ────────────────

  Future<void> _onSuggestionTap(SearchSuggestion suggestion) async {
    debugPrint(
        '🟢 [MAP_SHEET] _onSuggestionTap called for: ${suggestion.mainText}');
    debugPrint('🟢 [MAP_SHEET] Place ID: ${suggestion.placeId}');

    // Store root navigator context early - this won't be disposed even if MapSheet is
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    debugPrint('🟢 [MAP_SHEET] Root navigator context stored');

    // Don't call onSuggestionSelected yet - delay until after PlaceDetailsSheet is shown
    // This prevents setState() from triggering rebuilds that dispose the widget
    debugPrint(
        '🟢 [MAP_SHEET] Keeping MapSheet visible during async operations');

    if (!mounted) {
      debugPrint('🟢 [MAP_SHEET] ⚠️ Widget not mounted, returning');
      return;
    }

    debugPrint('🟢 [MAP_SHEET] Showing loading overlay for place details');
    // Show loading overlay using root navigator context
    final dismissLoading = RouteLoadingOverlay.show(rootNavigator.context,
        message: 'Loading place details...');

    try {
      debugPrint('🟢 [MAP_SHEET] Fetching Google Place details...');
      // Fetch place details only (no routes yet)
      final details = await _placesService.fetchGooglePlace(suggestion.placeId);
      debugPrint('🟢 [MAP_SHEET] ✅ Place details fetched: ${details.name}');
      debugPrint(
          '🟢 [MAP_SHEET] Place details - lat: ${details.lat}, lng: ${details.lng}');
      debugPrint(
          '🟢 [MAP_SHEET] Place details - address: ${details.formattedAddress}');

      debugPrint('🟢 [MAP_SHEET] Checking mounted state after fetch...');
      debugPrint('🟢 [MAP_SHEET] Mounted: $mounted');

      if (!mounted) {
        debugPrint(
            '🟢 [MAP_SHEET] ⚠️ Widget not mounted, dismissing loading and returning');
        dismissLoading();
        return;
      }

      debugPrint(
          '🟢 [MAP_SHEET] ✅ Widget is mounted, proceeding with distance calculation');

      // Calculate distance
      debugPrint('🟢 [MAP_SHEET] Starting distance calculation...');
      debugPrint(
          '🟢 [MAP_SHEET] Initial distance from suggestion: ${suggestion.distanceMeters / 1000}km');
      double distanceKm = suggestion.distanceMeters / 1000;

      try {
        debugPrint(
            '🟢 [MAP_SHEET] Getting current position for accurate distance...');
        final position = await Geolocator.getCurrentPosition();
        debugPrint(
            '🟢 [MAP_SHEET] Current position: ${position.latitude}, ${position.longitude}');

        distanceKm = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              details.lat,
              details.lng,
            ) /
            1000;
        debugPrint('🟢 [MAP_SHEET] ✅ Distance calculated: ${distanceKm}km');
      } catch (e, stackTrace) {
        debugPrint('🟢 [MAP_SHEET] ⚠️ Error calculating distance: $e');
        debugPrint('🟢 [MAP_SHEET] Stack trace: $stackTrace');
        debugPrint('🟢 [MAP_SHEET] Using fallback distance: ${distanceKm}km');
      }

      debugPrint(
          '🟢 [MAP_SHEET] Creating RecentLocation object (will save after PlaceDetailsSheet is shown)...');
      // Create RecentLocation object but don't dispatch yet - delay until after PlaceDetailsSheet is shown
      // This prevents BLoC state changes from causing widget disposal during async operations
      final recentLocation = RecentLocation(
        placeId: suggestion.placeId,
        name: details.name,
        address: details.formattedAddress,
        latitude: details.lat,
        longitude: details.lng,
        lastVisited: DateTime.now(),
        category: _inferCategory(details.name),
      );
      debugPrint(
          '🟢 [MAP_SHEET] ✅ RecentLocation created: ${recentLocation.name} (will save later)');

      // Hide loading overlay
      debugPrint('🟢 [MAP_SHEET] Hiding place details loading overlay...');
      debugPrint('🟢 [MAP_SHEET] Mounted before dismissLoading: $mounted');

      try {
        dismissLoading();
        debugPrint('🟢 [MAP_SHEET] ✅ Loading overlay dismissed successfully');
      } catch (e, stackTrace) {
        debugPrint('🟢 [MAP_SHEET] ❌ Error dismissing loading overlay: $e');
        debugPrint('🟢 [MAP_SHEET] Stack trace: $stackTrace');
      }

      debugPrint(
          '🟢 [MAP_SHEET] Checking mounted state after dismissing loading overlay...');
      debugPrint('🟢 [MAP_SHEET] Mounted: $mounted');

      if (!mounted) {
        debugPrint(
            '🟢 [MAP_SHEET] ⚠️ Widget not mounted after dismissing loading, returning');
        return;
      }

      debugPrint('🟢 [MAP_SHEET] ✅ Widget still mounted, proceeding to delay');

      // Small delay to ensure Navigator stack is ready after dismissing loading overlay
      debugPrint(
          '🟢 [MAP_SHEET] Waiting 100ms for Navigator stack to be ready...');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      debugPrint('🟢 [MAP_SHEET] ✅ Delay completed');

      debugPrint('🟢 [MAP_SHEET] Checking mounted state after delay...');
      debugPrint('🟢 [MAP_SHEET] Mounted: $mounted');

      if (!mounted) {
        debugPrint(
            '🟢 [MAP_SHEET] ⚠️ Widget not mounted after delay, returning');
        return;
      }

      debugPrint(
          '🟢 [MAP_SHEET] ✅ Widget still mounted, preparing to show PlaceDetailsSheet');
      debugPrint('🟢 [MAP_SHEET] Showing PlaceDetailsSheet');
      debugPrint('🟢 [MAP_SHEET] Context mounted: ${context.mounted}');
      debugPrint('🟢 [MAP_SHEET] Context: $context');
      debugPrint(
          '🟢 [MAP_SHEET] Details to show - name: ${details.name}, distance: ${distanceKm}km');

      // Hide MapSheet first so it doesn't remain underneath the PlaceDetailsSheet / Route sheet.
      debugPrint('🟢 [MAP_SHEET] Hiding MapSheet before showing PlaceDetailsSheet');
      widget.onLocationSelected?.call();

      // Show PlaceDetailsScreen first using root navigator context
      debugPrint(
          '🟢 [MAP_SHEET] Calling showModalBottomSheet for PlaceDetailsSheet...');
      debugPrint(
          '🟢 [MAP_SHEET] Using root navigator context (independent of MapSheet lifecycle)');

      try {
        final placeDetailsResult = await showModalBottomSheet<String>(
          context: rootNavigator.context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useRootNavigator: true,
          builder: (modalContext) {
            debugPrint('🟢 [MAP_SHEET] ✅ PlaceDetailsSheet builder called');
            debugPrint('🟢 [MAP_SHEET] ModalContext: $modalContext');
            return PlaceDetailsSheet(
              key: UniqueKey(),
              title: details.name,
              address: details.formattedAddress,
              distanceKm: distanceKm,
              showOnlySaveShareAction: false,
              onSave: () async {
                Navigator.of(modalContext).pop();
                await showModalBottomSheet<void>(
                  context: rootNavigator.context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useRootNavigator: true,
                  builder: (saveContext) => SelectAndSaveLocation(
                    placeId: suggestion.placeId,
                    position: LatLng(details.lat, details.lng),
                  ),
                );
              },
              onShare: () {
                Navigator.of(modalContext).pop();
              },
              onMore: () {
                Navigator.of(modalContext).pop();
              },
              onSeeAllRoutes: () async {
                debugPrint('🟡 [ROUTE_SHEET] onSeeAllRoutes clicked');
                debugPrint('🟡 [ROUTE_SHEET] Closing PlaceDetailsSheet');

                // Close PlaceDetailsSheet first
                Navigator.of(modalContext).pop('routes_opened');
                debugPrint('🟡 [ROUTE_SHEET] PlaceDetailsSheet closed');

                debugPrint(
                    '🟡 [ROUTE_SHEET] Showing loading overlay for routes');
                // Show loading overlay for route fetching using root navigator context
                final routeDismissLoading = RouteLoadingOverlay.show(
                    rootNavigator.context,
                    message: 'Finding routes...');
                debugPrint(
                    '🟡 [ROUTE_SHEET] Loading overlay shown, dismiss function stored');

                try {
                  debugPrint('🟡 [ROUTE_SHEET] Getting current position...');
                  final position = await Geolocator.getCurrentPosition();
                  debugPrint(
                      '🟡 [ROUTE_SHEET] Current position: ${position.latitude}, ${position.longitude}');

                  debugPrint(
                      '🟡 [ROUTE_SHEET] Fetching routes from backend...');
                  debugPrint(
                      '🟡 [ROUTE_SHEET] Origin: ${position.latitude}, ${position.longitude}');
                  debugPrint(
                      '🟡 [ROUTE_SHEET] Destination: ${details.lat}, ${details.lng}');

                  // Fetch routes from backend
                  final directions = await _placesService.fetchMapboxDirections(
                    originLat: position.latitude,
                    originLng: position.longitude,
                    destinationLat: details.lat,
                    destinationLng: details.lng,
                    profile: 'driving-traffic',
                    alternatives: true,
                  );

                  debugPrint('🟡 [ROUTE_SHEET] ✅ Routes fetched successfully');
                  debugPrint(
                      '🟡 [ROUTE_SHEET] Routes count: ${directions.routes.length}');

                  if (directions.routes.isNotEmpty) {
                    debugPrint(
                        '🟡 [ROUTE_SHEET] First route: distance=${directions.routes.first.distance}m, duration=${directions.routes.first.duration}s');
                  } else {
                    debugPrint(
                        '🟡 [ROUTE_SHEET] ⚠️ WARNING: Routes list is EMPTY!');
                  }

                  // Hide loading overlay
                  debugPrint('🟡 [ROUTE_SHEET] Hiding loading overlay');
                  routeDismissLoading();

                  // Small delay to ensure Navigator stack is ready
                  debugPrint(
                      '🟡 [ROUTE_SHEET] Waiting 100ms for Navigator stack to be ready');
                  await Future<void>.delayed(const Duration(milliseconds: 100));

                  debugPrint(
                      '🟡 [ROUTE_SHEET] Directions fetched: ${directions.routes.length} routes');

                  // Validate routes before proceeding
                  if (directions.routes.isEmpty) {
                    debugPrint(
                        '🟡 [ROUTE_SHEET] ⚠️ No routes found to destination');
                    // Restore MapSheet visibility since we can't show RouteSelectionSheet
                    widget.onRouteSelectionDismissed?.call();
                    // Use root navigator context to show error even if widget is unmounted
                    ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'No routes found to this destination. Please check your connection and try again.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Validate root navigator context before using it
                  if (!rootNavigator.context.mounted) {
                    debugPrint(
                        '🟡 [ROUTE_SHEET] ⚠️ Root navigator context not mounted');
                    // Restore MapSheet visibility
                    widget.onRouteSelectionDismissed?.call();
                    ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Unable to show route options. Please try again.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  // Parent (MainDashboard) owns the map; forward even if MapSheet is offstage.
                  final firstRoute = directions.routes.first;
                  debugPrint('🟡 [ROUTE_SHEET] Drawing first route polyline');
                  widget.onDrawMapboxPolyline?.call(
                    firstRoute,
                    alternativeRoutes: directions.routes
                        .where((r) => !identical(r, firstRoute))
                        .toList(),
                  );

                  debugPrint(
                      '🟡 [ROUTE_SHEET] Attempting to show RouteSelectionSheet');
                  debugPrint(
                      '🟡 [ROUTE_SHEET] Routes to show: ${directions.routes.length}');
                  debugPrint('🟡 [ROUTE_SHEET] Place details: ${details.name}');
                  debugPrint(
                      '🟡 [ROUTE_SHEET] Using root navigator context (independent of MapSheet lifecycle)');

                  try {
                    // Show RouteSelectionSheet with fetched routes using root navigator context
                    // This works even if MapSheet widget is unmounted
                    debugPrint(
                        '🟡 [ROUTE_SHEET] Calling showModalBottomSheet...');
                    final result = await showModalBottomSheet<String>(
                      context: rootNavigator.context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      useRootNavigator: true,
                      builder: (routeContext) {
                        debugPrint(
                            '🟡 [ROUTE_SHEET] RouteSelectionSheet builder called');
                        debugPrint(
                            '🟡 [ROUTE_SHEET] RouteContext: $routeContext');
                        // Defensive check: ensure routes are not empty
                        if (directions.routes.isEmpty) {
                          debugPrint(
                              '🟡 [ROUTE_SHEET] ⚠️ Routes list is empty in builder!');
                          return const SizedBox.shrink();
                        }
                        return RouteSelectionSheet(
                          routes: directions.routes,
                          placeDetails: details,
                          onRouteSelected: (selectedRoute) {
                            debugPrint(
                                '🟡 [ROUTE_SHEET] Route selected: ${selectedRoute.distance}m');
                            widget.onDrawMapboxPolyline?.call(
                              selectedRoute,
                              alternativeRoutes: directions.routes
                                  .where((r) => !identical(r, selectedRoute))
                                  .toList(),
                            );
                          },
                          onModeChanged: (mode) => _refetchRoutesForMode(
                            mode: mode,
                            destLat: details.lat,
                            destLng: details.lng,
                          ),
                          onStartNavigation: (selectedRoute, {mode = TravelMode.drive}) {
                            debugPrint(
                                '🟡 [ROUTE_SHEET] Navigation started (mode: $mode, distance: ${selectedRoute.distance}m)');
                            widget.onDrawMapboxPolyline?.call(
                              selectedRoute,
                              alternativeRoutes: directions.routes
                                  .where((r) => !identical(r, selectedRoute))
                                  .toList(),
                            );
                            widget.onStartNavigation?.call(selectedRoute, mode: mode);
                          },
                        );
                      },
                    );

                    debugPrint(
                        '🟡 [ROUTE_SHEET] ✅ RouteSelectionSheet dismissed with result: $result');

                    // Restore MapSheet visibility when RouteSelectionSheet is dismissed (if navigation didn't start)
                    if (result != 'navigation_started') {
                      debugPrint(
                          '🟡 [ROUTE_SHEET] Restoring MapSheet visibility');
                      widget.onRouteSelectionDismissed?.call();
                    }
                  } catch (e, stackTrace) {
                    // Critical error - use print for release mode visibility
                    print(
                        '🟡 [ROUTE_SHEET] ❌ ERROR showing RouteSelectionSheet');
                    print('🟡 [ROUTE_SHEET] Error: $e');
                    debugPrint('🟡 [ROUTE_SHEET] Stack trace: $stackTrace');

                    // CRITICAL: Restore MapSheet visibility on error to prevent unusable state
                    print(
                        '🟡 [ROUTE_SHEET] Restoring MapSheet visibility due to error');
                    widget.onRouteSelectionDismissed?.call();

                    // Use root navigator context to show error even if widget is unmounted
                    try {
                      ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Error showing route options: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } catch (snackError) {
                      // If even showing snackbar fails, at least log it
                      print(
                          '🟡 [ROUTE_SHEET] Failed to show error snackbar: $snackError');
                    }
                  }
                } catch (e, stackTrace) {
                  // Critical error - use print for release mode visibility
                  print('🟡 [ROUTE_SHEET] ❌ ERROR fetching routes');
                  print('🟡 [ROUTE_SHEET] Error: $e');
                  debugPrint('🟡 [ROUTE_SHEET] Stack trace: $stackTrace');

                  // Hide loading overlay on error
                  routeDismissLoading();

                  // CRITICAL: Restore MapSheet visibility on error to prevent unusable state
                  print(
                      '🟡 [ROUTE_SHEET] Restoring MapSheet visibility due to route fetching error');
                  widget.onRouteSelectionDismissed?.call();

                  // Use root navigator context to show error even if widget is unmounted
                  final errorMessage =
                      e.toString().replaceFirst('Exception: ', '');
                  try {
                    ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                      SnackBar(
                        content: Text(errorMessage.isNotEmpty
                            ? errorMessage
                            : 'Unable to find routes. Please check your connection and try again.'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  } catch (snackError) {
                    print(
                        '🟡 [ROUTE_SHEET] Failed to show error snackbar: $snackError');
                  }
                }
              },
              info: details.website,
            );
          },
        );

        debugPrint('🟢 [MAP_SHEET] ✅ showModalBottomSheet call completed');
        debugPrint('🟢 [MAP_SHEET] PlaceDetailsSheet should now be visible');

        // Now add to recent locations since PlaceDetailsSheet is successfully shown
        // This is safe to do now because the widget operations are complete
        debugPrint(
            '🟢 [MAP_SHEET] Adding to recent locations now that PlaceDetailsSheet is shown...');
        if (mounted) {
          try {
            context.read<ReportsBloc>().add(
                  ReportsEvent.addRecentLocation(location: recentLocation),
                );
            debugPrint('🟢 [MAP_SHEET] ✅ Recent location event dispatched');
          } catch (e, stackTrace) {
            debugPrint('🟢 [MAP_SHEET] ❌ Error adding to recent locations: $e');
            debugPrint('🟢 [MAP_SHEET] Stack trace: $stackTrace');
          }
        } else {
          debugPrint(
              '🟢 [MAP_SHEET] ⚠️ Widget not mounted, skipping recent location addition');
        }

        // Don't call onSuggestionSelected here - it triggers setState() which rebuilds MainDashboard
        // and disposes MapSheet. We don't need it since PlaceDetailsSheet handles the flow.
        // onSuggestionSelected is only used for RouteBar, which we don't show with PlaceDetailsSheet.

        // Restore MapSheet visibility when PlaceDetailsSheet is dismissed (unless navigation started)
        debugPrint(
            '🟢 [MAP_SHEET] PlaceDetailsSheet dismissed with result: $placeDetailsResult');
        if (placeDetailsResult != 'navigation_started' &&
            placeDetailsResult != 'routes_opened') {
          debugPrint(
              '🟢 [MAP_SHEET] Restoring MapSheet visibility after PlaceDetailsSheet dismissal');
          widget.onRouteSelectionDismissed?.call();
        } else {
          debugPrint(
              '🟢 [MAP_SHEET] Navigation started, keeping MapSheet hidden');
        }
      } catch (e, stackTrace) {
        debugPrint('🟢 [MAP_SHEET] ❌ EXCEPTION in showModalBottomSheet call');
        debugPrint('🟢 [MAP_SHEET] Error type: ${e.runtimeType}');
        debugPrint('🟢 [MAP_SHEET] Error: $e');
        debugPrint('🟢 [MAP_SHEET] Stack trace: $stackTrace');

        // Still add to recent locations even if PlaceDetailsSheet failed to show
        debugPrint(
            '🟢 [MAP_SHEET] Adding to recent locations despite error...');
        if (mounted) {
          try {
            context.read<ReportsBloc>().add(
                  ReportsEvent.addRecentLocation(location: recentLocation),
                );
            debugPrint(
                '🟢 [MAP_SHEET] ✅ Recent location event dispatched (error case)');
          } catch (blocError) {
            debugPrint(
                '🟢 [MAP_SHEET] ❌ Error adding to recent locations: $blocError');
          }
        }

        // PlaceDetailsSheet failed to show: restore MapSheet visibility so users can try again.
        widget.onRouteSelectionDismissed?.call();
        debugPrint(
            '🟢 [MAP_SHEET] Restoring MapSheet due to error showing PlaceDetailsSheet');
        widget.onRouteSelectionDismissed?.call();
      }
    } catch (e, stackTrace) {
      debugPrint('🟢 [MAP_SHEET] ❌ ERROR fetching place details');
      debugPrint('🟢 [MAP_SHEET] Error: $e');
      debugPrint('🟢 [MAP_SHEET] Stack trace: $stackTrace');

      // Hide loading overlay on error
      debugPrint('🟢 [MAP_SHEET] Hiding loading overlay due to error');
      dismissLoading();

      // Place details fetch failed: MapSheet was never hidden, so just show the error.
      // Do NOT call onLocationSelected — that would hide the sheet with no way to restore.
      debugPrint(
          '🟢 [MAP_SHEET] Showing error to user (MapSheet stays visible)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load place details. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onSaveASpecificLocation(
    SearchSuggestion suggestion, {
    required String locationName,
  }) async {
    final details = await _placesService.fetchGooglePlace(suggestion.placeId);

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (contxt) => PlaceDetailsSheet(
        key: UniqueKey(),
        title: details.name,
        address: details.formattedAddress,
        distanceKm: suggestion.distanceMeters / 1000,
        showOnlySaveShareAction: true,
        onSave: () async {
          Navigator.of(contxt).pop();
          context.read<ReportsBloc>().add(
                ReportsEvent.saveLocation(
                  locationName: locationName,
                  lat: details.lat,
                  lng: details.lng,
                  placeId: details.placeId,
                ),
              );
        },
        onShare: () {
          Navigator.of(contxt).pop();
        },
        onMore: () {
          Navigator.of(contxt).pop();
        },
        onSeeAllRoutes: () async {},
        info: details.website,
      ),
    );
  }

  Future<void> _onSavedLocationTap(SavedLocations location) async {
    debugPrint(
        '🔵 [MAP_SHEET] _onSavedLocationTap called for: ${location.name}');
    debugPrint('🔵 [MAP_SHEET] Place ID: ${location.placeId}');
    debugPrint(
        '🔵 [MAP_SHEET] Location: ${location.latitude}, ${location.longitude}');

    // Store root navigator context early - this won't be disposed even if MapSheet is
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    debugPrint('🔵 [MAP_SHEET] Root navigator context stored');

    // Don't call onSuggestionSelected yet - delay until after PlaceDetailsSheet is shown
    // This prevents setState() from triggering rebuilds that dispose the widget
    debugPrint(
        '🔵 [MAP_SHEET] Keeping MapSheet visible during async operations');

    if (!mounted) {
      debugPrint('🔵 [MAP_SHEET] ⚠️ Widget not mounted, returning');
      return;
    }

    // Calculate distance
    debugPrint('🔵 [MAP_SHEET] Calculating distance...');
    double distanceKm = 0;
    try {
      final position = await Geolocator.getCurrentPosition();
      distanceKm = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            location.latitude,
            location.longitude,
          ) /
          1000;
      debugPrint('🔵 [MAP_SHEET] Distance calculated: ${distanceKm}km');
    } catch (e) {
      debugPrint('🔵 [MAP_SHEET] Error calculating distance: $e');
    }

    if (!mounted) {
      debugPrint(
          '🔵 [MAP_SHEET] ⚠️ Widget not mounted after calculating distance, returning');
      return;
    }

    debugPrint('🔵 [MAP_SHEET] Showing PlaceDetailsSheet');
    debugPrint(
        '🔵 [MAP_SHEET] Using root navigator context (independent of MapSheet lifecycle)');

    // Show PlaceDetailsScreen first using root navigator context
    final savedPlaceDetailsResult = await showModalBottomSheet<String>(
      context: rootNavigator.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (modalContext) {
        debugPrint('🔵 [MAP_SHEET] PlaceDetailsSheet builder called');
        return PlaceDetailsSheet(
          key: UniqueKey(),
          title: location.name,
          address: location.address ?? '',
          distanceKm: distanceKm,
          showOnlySaveShareAction: false,
          onSave: () {},
          onShare: () {
            Navigator.of(modalContext).pop();
          },
          onMore: () {
            Navigator.of(modalContext).pop();
          },
          onSeeAllRoutes: () async {
            debugPrint(
                '🔵 [ROUTE_SHEET] onSeeAllRoutes clicked (saved location)');
            debugPrint('🔵 [ROUTE_SHEET] Closing PlaceDetailsSheet');

            // Close PlaceDetailsSheet first
            Navigator.of(modalContext).pop('routes_opened');
            debugPrint('🔵 [ROUTE_SHEET] PlaceDetailsSheet closed');

            debugPrint('🔵 [ROUTE_SHEET] Showing loading overlay for routes');
            // Show loading overlay for route fetching using root navigator context
            final routeDismissLoading = RouteLoadingOverlay.show(
                rootNavigator.context,
                message: 'Finding routes...');
            debugPrint(
                '🔵 [ROUTE_SHEET] Loading overlay shown, dismiss function stored');

            try {
              debugPrint('🔵 [ROUTE_SHEET] Getting current position...');
              final position = await Geolocator.getCurrentPosition();
              debugPrint(
                  '🔵 [ROUTE_SHEET] Current position: ${position.latitude}, ${position.longitude}');

              debugPrint('🔵 [ROUTE_SHEET] Fetching routes from backend...');
              debugPrint(
                  '🔵 [ROUTE_SHEET] Origin: ${position.latitude}, ${position.longitude}');
              debugPrint(
                  '🔵 [ROUTE_SHEET] Destination: ${location.latitude}, ${location.longitude}');

              // Fetch routes from backend
              final directions = await _placesService.fetchMapboxDirections(
                originLat: position.latitude,
                originLng: position.longitude,
                destinationLat: location.latitude,
                destinationLng: location.longitude,
                profile: 'driving-traffic',
                alternatives: true,
              );

              debugPrint('🔵 [ROUTE_SHEET] ✅ Routes fetched successfully');
              debugPrint(
                  '🔵 [ROUTE_SHEET] Routes count: ${directions.routes.length}');

              if (directions.routes.isNotEmpty) {
                debugPrint(
                    '🔵 [ROUTE_SHEET] First route: distance=${directions.routes.first.distance}m, duration=${directions.routes.first.duration}s');
              } else {
                debugPrint(
                    '🔵 [ROUTE_SHEET] ⚠️ WARNING: Routes list is EMPTY!');
              }

              // Hide loading overlay
              debugPrint('🔵 [ROUTE_SHEET] Hiding loading overlay');
              routeDismissLoading();

              // Small delay to ensure Navigator stack is ready
              debugPrint(
                  '🔵 [ROUTE_SHEET] Waiting 100ms for Navigator stack to be ready');
              await Future<void>.delayed(const Duration(milliseconds: 100));

              debugPrint(
                  '🔵 [ROUTE_SHEET] Directions fetched: ${directions.routes.length} routes');

              // Validate routes before proceeding
              if (directions.routes.isEmpty) {
                debugPrint(
                    '🔵 [ROUTE_SHEET] ⚠️ No routes found to destination');
                // Restore MapSheet visibility since we can't show RouteSelectionSheet
                widget.onRouteSelectionDismissed?.call();
                // Use root navigator context to show error even if widget is unmounted
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'No routes found to this destination. Please check your connection and try again.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ),
                );
                return;
              }

              // Validate root navigator context before using it
              if (!rootNavigator.context.mounted) {
                debugPrint(
                    '🔵 [ROUTE_SHEET] ⚠️ Root navigator context not mounted');
                // Restore MapSheet visibility
                widget.onRouteSelectionDismissed?.call();
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Unable to show route options. Please try again.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ),
                );
                return;
              }

              final firstRoute = directions.routes.first;
              debugPrint('🔵 [ROUTE_SHEET] Drawing first route polyline');
              widget.onDrawMapboxPolyline?.call(
                firstRoute,
                alternativeRoutes: directions.routes
                    .where((r) => !identical(r, firstRoute))
                    .toList(),
              );

              debugPrint(
                  '🔵 [ROUTE_SHEET] Attempting to show RouteSelectionSheet');
              debugPrint(
                  '🔵 [ROUTE_SHEET] Routes to show: ${directions.routes.length}');
              debugPrint('🔵 [ROUTE_SHEET] Place details: ${location.name}');
              debugPrint(
                  '🔵 [ROUTE_SHEET] Using root navigator context (independent of MapSheet lifecycle)');

              try {
                // Show RouteSelectionSheet with fetched routes using root navigator context
                // This works even if MapSheet widget is unmounted
                debugPrint('🔵 [ROUTE_SHEET] Calling showModalBottomSheet...');
                final result = await showModalBottomSheet<String>(
                  context: rootNavigator.context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useRootNavigator: true,
                  builder: (routeContext) {
                    debugPrint(
                        '🔵 [ROUTE_SHEET] RouteSelectionSheet builder called');
                    debugPrint('🔵 [ROUTE_SHEET] RouteContext: $routeContext');
                    // Defensive check: ensure routes are not empty
                    if (directions.routes.isEmpty) {
                      debugPrint(
                          '🔵 [ROUTE_SHEET] ⚠️ Routes list is empty in builder!');
                      return const SizedBox.shrink();
                    }
                    return RouteSelectionSheet(
                      routes: directions.routes,
                      placeDetails: GooglePlaceDetails(
                        placeId: location.placeId ?? '',
                        name: location.name,
                        formattedAddress: location.address ?? '',
                        lat: location.latitude,
                        lng: location.longitude,
                        website: '',
                      ),
                      onRouteSelected: (selectedRoute) {
                        debugPrint(
                            '🔵 [ROUTE_SHEET] Route selected: ${selectedRoute.distance}m');
                        widget.onDrawMapboxPolyline?.call(
                          selectedRoute,
                          alternativeRoutes: directions.routes
                              .where((r) => !identical(r, selectedRoute))
                              .toList(),
                        );
                      },
                      onModeChanged: (mode) => _refetchRoutesForMode(
                        mode: mode,
                        destLat: location.latitude,
                        destLng: location.longitude,
                      ),
                      onStartNavigation: (selectedRoute, {mode = TravelMode.drive}) {
                        debugPrint(
                            '🔵 [ROUTE_SHEET] Navigation started (mode: $mode, distance: ${selectedRoute.distance}m)');
                        widget.onDrawMapboxPolyline?.call(
                          selectedRoute,
                          alternativeRoutes: directions.routes
                              .where((r) => !identical(r, selectedRoute))
                              .toList(),
                        );
                        widget.onStartNavigation?.call(selectedRoute, mode: mode);
                      },
                    );
                  },
                );

                debugPrint(
                    '🔵 [ROUTE_SHEET] ✅ RouteSelectionSheet dismissed with result: $result');

                // Restore MapSheet visibility when RouteSelectionSheet is dismissed (if navigation didn't start)
                if (result != 'navigation_started') {
                  debugPrint('🔵 [ROUTE_SHEET] Restoring MapSheet visibility');
                  widget.onRouteSelectionDismissed?.call();
                }
              } catch (e, stackTrace) {
                // Critical error - use print for release mode visibility
                print('🔵 [ROUTE_SHEET] ❌ ERROR showing RouteSelectionSheet');
                print('🔵 [ROUTE_SHEET] Error: $e');
                debugPrint('🔵 [ROUTE_SHEET] Stack trace: $stackTrace');

                // CRITICAL: Restore MapSheet visibility on error to prevent unusable state
                print(
                    '🔵 [ROUTE_SHEET] Restoring MapSheet visibility due to error');
                widget.onRouteSelectionDismissed?.call();

                // Use root navigator context to show error even if widget is unmounted
                try {
                  ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Error showing route options: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } catch (snackError) {
                  // If even showing snackbar fails, at least log it
                  print(
                      '🔵 [ROUTE_SHEET] Failed to show error snackbar: $snackError');
                }
              }
            } catch (e, stackTrace) {
              // Critical error - use print for release mode visibility
              print('🔵 [ROUTE_SHEET] ❌ ERROR fetching routes');
              print('🔵 [ROUTE_SHEET] Error: $e');
              debugPrint('🔵 [ROUTE_SHEET] Stack trace: $stackTrace');

              // Hide loading overlay on error
              debugPrint(
                  '🔵 [ROUTE_SHEET] Hiding loading overlay due to error');
              routeDismissLoading();

              // CRITICAL: Restore MapSheet visibility on error to prevent unusable state
              print(
                  '🔵 [ROUTE_SHEET] Restoring MapSheet visibility due to route fetching error');
              widget.onRouteSelectionDismissed?.call();

              // Use root navigator context to show error even if widget is unmounted
              final errorMessage = e.toString().replaceFirst('Exception: ', '');
              try {
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage.isNotEmpty
                        ? errorMessage
                        : 'Unable to find routes. Please check your connection and try again.'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              } catch (snackError) {
                print(
                    '🔵 [ROUTE_SHEET] Failed to show error snackbar: $snackError');
              }
            }
          },
          info: '',
        );
      },
    );

    // Don't call onSuggestionSelected here - it triggers setState() which rebuilds MainDashboard
    // and disposes MapSheet. We don't need it since PlaceDetailsSheet handles the flow.
    // onSuggestionSelected is only used for RouteBar, which we don't show with PlaceDetailsSheet.

    // Now hide MapSheet since PlaceDetailsSheet is successfully shown
    debugPrint('🔵 [MAP_SHEET] PlaceDetailsSheet shown, hiding MapSheet');
    widget.onLocationSelected?.call();

    // Restore MapSheet visibility when PlaceDetailsSheet is dismissed (unless navigation started)
    debugPrint(
        '🔵 [MAP_SHEET] PlaceDetailsSheet dismissed with result: $savedPlaceDetailsResult');
    if (savedPlaceDetailsResult != 'navigation_started' &&
        savedPlaceDetailsResult != 'routes_opened') {
      debugPrint(
          '🔵 [MAP_SHEET] Restoring MapSheet visibility after PlaceDetailsSheet dismissal');
      widget.onRouteSelectionDismissed?.call();
    } else {
      debugPrint('🔵 [MAP_SHEET] Navigation started, keeping MapSheet hidden');
    }
  }

  Future<void> _onRecentLocationTap(RecentLocation location) async {
    debugPrint(
        '🟣 [MAP_SHEET] _onRecentLocationTap called for: ${location.name}');
    debugPrint('🟣 [MAP_SHEET] Place ID: ${location.placeId}');
    debugPrint(
        '🟣 [MAP_SHEET] Location: ${location.latitude}, ${location.longitude}');

    // Store root navigator context early - this won't be disposed even if MapSheet is
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    debugPrint('🟣 [MAP_SHEET] Root navigator context stored');

    if (!mounted) {
      debugPrint('🟣 [MAP_SHEET] ⚠️ Widget not mounted, returning');
      return;
    }

    // Calculate distance
    debugPrint('🟣 [MAP_SHEET] Calculating distance...');
    double distanceKm = 0;
    try {
      final position = await Geolocator.getCurrentPosition();
      distanceKm = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            location.latitude,
            location.longitude,
          ) /
          1000;
      debugPrint('🟣 [MAP_SHEET] Distance calculated: ${distanceKm}km');
    } catch (e) {
      debugPrint('🟣 [MAP_SHEET] Error calculating distance: $e');
    }

    if (!mounted) {
      debugPrint(
          '🟣 [MAP_SHEET] ⚠️ Widget not mounted after calculating distance, returning');
      return;
    }

    debugPrint('🟣 [MAP_SHEET] Showing PlaceDetailsSheet');
    debugPrint(
        '🟣 [MAP_SHEET] Using root navigator context (independent of MapSheet lifecycle)');

    // Hide MapSheet first so it doesn't remain underneath the PlaceDetailsSheet / Route sheet.
    debugPrint('🟣 [MAP_SHEET] Hiding MapSheet before showing PlaceDetailsSheet');
    widget.onLocationSelected?.call();

    // Show PlaceDetailsScreen first using root navigator context
    final recentPlaceDetailsResult = await showModalBottomSheet<String>(
      context: rootNavigator.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (modalContext) {
        debugPrint('🟣 [MAP_SHEET] PlaceDetailsSheet builder called');
        return PlaceDetailsSheet(
          key: UniqueKey(),
          title: location.name,
          address: location.address,
          distanceKm: distanceKm,
          showOnlySaveShareAction: false,
          onSave: () {},
          onShare: () {
            Navigator.of(modalContext).pop();
          },
          onMore: () {
            Navigator.of(modalContext).pop();
          },
          onSeeAllRoutes: () async {
            debugPrint(
                '🟣 [ROUTE_SHEET] onSeeAllRoutes clicked (recent location)');
            debugPrint('🟣 [ROUTE_SHEET] Closing PlaceDetailsSheet');

            // Close PlaceDetailsSheet first
            Navigator.of(modalContext).pop('routes_opened');
            debugPrint('🟣 [ROUTE_SHEET] PlaceDetailsSheet closed');

            debugPrint('🟣 [ROUTE_SHEET] Showing loading overlay for routes');
            // Show loading overlay for route fetching using root navigator context
            final routeDismissLoading = RouteLoadingOverlay.show(
                rootNavigator.context,
                message: 'Finding routes...');
            debugPrint(
                '🟣 [ROUTE_SHEET] Loading overlay shown, dismiss function stored');

            try {
              debugPrint('🟣 [ROUTE_SHEET] Getting current position...');
              final position = await Geolocator.getCurrentPosition();
              debugPrint(
                  '🟣 [ROUTE_SHEET] Current position: ${position.latitude}, ${position.longitude}');

              debugPrint('🟣 [ROUTE_SHEET] Fetching routes from backend...');
              debugPrint(
                  '🟣 [ROUTE_SHEET] Origin: ${position.latitude}, ${position.longitude}');
              debugPrint(
                  '🟣 [ROUTE_SHEET] Destination: ${location.latitude}, ${location.longitude}');

              // Fetch routes from backend
              final directions = await _placesService.fetchMapboxDirections(
                originLat: position.latitude,
                originLng: position.longitude,
                destinationLat: location.latitude,
                destinationLng: location.longitude,
                profile: 'driving-traffic',
                alternatives: true,
              );

              debugPrint('🟣 [ROUTE_SHEET] ✅ Routes fetched successfully');
              debugPrint(
                  '🟣 [ROUTE_SHEET] Routes count: ${directions.routes.length}');

              if (directions.routes.isNotEmpty) {
                debugPrint(
                    '🟣 [ROUTE_SHEET] First route: distance=${directions.routes.first.distance}m, duration=${directions.routes.first.duration}s');
              } else {
                debugPrint(
                    '🟣 [ROUTE_SHEET] ⚠️ WARNING: Routes list is EMPTY!');
              }

              // Hide loading overlay
              debugPrint('🟣 [ROUTE_SHEET] Hiding loading overlay');
              routeDismissLoading();

              // Small delay to ensure Navigator stack is ready
              debugPrint(
                  '🟣 [ROUTE_SHEET] Waiting 100ms for Navigator stack to be ready');
              await Future<void>.delayed(const Duration(milliseconds: 100));

              debugPrint(
                  '🟣 [ROUTE_SHEET] Directions fetched: ${directions.routes.length} routes');

              // Validate routes before proceeding
              if (directions.routes.isEmpty) {
                debugPrint(
                    '🟣 [ROUTE_SHEET] ⚠️ No routes found to destination');
                // Restore MapSheet visibility since we can't show RouteSelectionSheet
                widget.onRouteSelectionDismissed?.call();
                // Use root navigator context to show error even if widget is unmounted
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'No routes found to this destination. Please check your connection and try again.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ),
                );
                return;
              }

              // Validate root navigator context before using it
              if (!rootNavigator.context.mounted) {
                debugPrint(
                    '🟣 [ROUTE_SHEET] ⚠️ Root navigator context not mounted');
                // Restore MapSheet visibility
                widget.onRouteSelectionDismissed?.call();
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Unable to show route options. Please try again.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ),
                );
                return;
              }

              final firstRoute = directions.routes.first;
              debugPrint('🟣 [ROUTE_SHEET] Drawing first route polyline');
              widget.onDrawMapboxPolyline?.call(
                firstRoute,
                alternativeRoutes: directions.routes
                    .where((r) => !identical(r, firstRoute))
                    .toList(),
              );

              debugPrint(
                  '🟣 [ROUTE_SHEET] Attempting to show RouteSelectionSheet');
              debugPrint(
                  '🟣 [ROUTE_SHEET] Routes to show: ${directions.routes.length}');
              debugPrint('🟣 [ROUTE_SHEET] Place details: ${location.name}');
              debugPrint(
                  '🟣 [ROUTE_SHEET] Using root navigator context (independent of MapSheet lifecycle)');

              try {
                // Show RouteSelectionSheet with fetched routes using root navigator context
                // This works even if MapSheet widget is unmounted
                debugPrint('🟣 [ROUTE_SHEET] Calling showModalBottomSheet...');
                final result = await showModalBottomSheet<String>(
                  context: rootNavigator.context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useRootNavigator: true,
                  builder: (routeContext) {
                    debugPrint(
                        '🟣 [ROUTE_SHEET] RouteSelectionSheet builder called');
                    debugPrint('🟣 [ROUTE_SHEET] RouteContext: $routeContext');
                    // Defensive check: ensure routes are not empty
                    if (directions.routes.isEmpty) {
                      debugPrint(
                          '🟣 [ROUTE_SHEET] ⚠️ Routes list is empty in builder!');
                      return const SizedBox.shrink();
                    }
                    return RouteSelectionSheet(
                      routes: directions.routes,
                      placeDetails: GooglePlaceDetails(
                        placeId: location.placeId,
                        name: location.name,
                        formattedAddress: location.address,
                        lat: location.latitude,
                        lng: location.longitude,
                        website: '',
                      ),
                      onRouteSelected: (selectedRoute) {
                        debugPrint(
                            '🟣 [ROUTE_SHEET] Route selected: ${selectedRoute.distance}m');
                        widget.onDrawMapboxPolyline?.call(
                          selectedRoute,
                          alternativeRoutes: directions.routes
                              .where((r) => !identical(r, selectedRoute))
                              .toList(),
                        );
                      },
                      onModeChanged: (mode) => _refetchRoutesForMode(
                        mode: mode,
                        destLat: location.latitude,
                        destLng: location.longitude,
                      ),
                      onStartNavigation: (selectedRoute, {mode = TravelMode.drive}) {
                        debugPrint(
                            '🟣 [ROUTE_SHEET] Navigation started (mode: $mode, distance: ${selectedRoute.distance}m)');
                        widget.onDrawMapboxPolyline?.call(
                          selectedRoute,
                          alternativeRoutes: directions.routes
                              .where((r) => !identical(r, selectedRoute))
                              .toList(),
                        );
                        widget.onStartNavigation?.call(selectedRoute, mode: mode);
                      },
                    );
                  },
                );

                debugPrint(
                    '🟣 [ROUTE_SHEET] ✅ RouteSelectionSheet dismissed with result: $result');

                // Restore MapSheet visibility when RouteSelectionSheet is dismissed (if navigation didn't start)
                if (result != 'navigation_started') {
                  debugPrint('🟣 [ROUTE_SHEET] Restoring MapSheet visibility');
                  widget.onRouteSelectionDismissed?.call();
                }
              } catch (e, stackTrace) {
                // Critical error - use print for release mode visibility
                print('🟣 [ROUTE_SHEET] ❌ ERROR showing RouteSelectionSheet');
                print('🟣 [ROUTE_SHEET] Error: $e');
                debugPrint('🟣 [ROUTE_SHEET] Stack trace: $stackTrace');

                // CRITICAL: Restore MapSheet visibility on error to prevent unusable state
                print(
                    '🟣 [ROUTE_SHEET] Restoring MapSheet visibility due to error');
                widget.onRouteSelectionDismissed?.call();

                // Use root navigator context to show error even if widget is unmounted
                try {
                  ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Error showing route options: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } catch (snackError) {
                  // If even showing snackbar fails, at least log it
                  print(
                      '🟣 [ROUTE_SHEET] Failed to show error snackbar: $snackError');
                }
              }
            } catch (e, stackTrace) {
              // Critical error - use print for release mode visibility
              print('🟣 [ROUTE_SHEET] ❌ ERROR fetching routes');
              print('🟣 [ROUTE_SHEET] Error: $e');
              debugPrint('🟣 [ROUTE_SHEET] Stack trace: $stackTrace');

              // Hide loading overlay on error
              debugPrint(
                  '🟣 [ROUTE_SHEET] Hiding loading overlay due to error');
              routeDismissLoading();

              // CRITICAL: Restore MapSheet visibility on error to prevent unusable state
              print(
                  '🟣 [ROUTE_SHEET] Restoring MapSheet visibility due to route fetching error');
              widget.onRouteSelectionDismissed?.call();

              // Use root navigator context to show error even if widget is unmounted
              final errorMessage = e.toString().replaceFirst('Exception: ', '');
              try {
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage.isNotEmpty
                        ? errorMessage
                        : 'Unable to find routes. Please check your connection and try again.'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              } catch (snackError) {
                print(
                    '🟣 [ROUTE_SHEET] Failed to show error snackbar: $snackError');
              }
            }
          },
          info: '',
        );
      },
    );

    // Restore MapSheet visibility when PlaceDetailsSheet is dismissed (unless navigation started)
    debugPrint(
        '🟣 [MAP_SHEET] PlaceDetailsSheet dismissed with result: $recentPlaceDetailsResult');
    if (recentPlaceDetailsResult != 'navigation_started' &&
        recentPlaceDetailsResult != 'routes_opened') {
      debugPrint(
          '🟣 [MAP_SHEET] Restoring MapSheet visibility after PlaceDetailsSheet dismissal');
      widget.onRouteSelectionDismissed?.call();
    } else {
      debugPrint('🟣 [MAP_SHEET] Navigation started, keeping MapSheet hidden');
    }
  }

  Future<void> _onAddLocationTapped(String? specificType) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => AddALocationBySuggestionSearch(
        onSuggestionTap: (suggestion) async {
          Navigator.of(modalContext).pop();
          if (specificType != null) {
            _onSaveASpecificLocation(
              suggestion,
              locationName: specificType,
            );
          } else {
            final details =
                await _placesService.fetchGooglePlace(suggestion.placeId);
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (modalContext) => SelectAndSaveLocation(
                position: LatLng(details.lat, details.lng),
                placeId: suggestion.placeId,
              ),
            );
          }
        },
      ),
    );
  }

  // ── Expandable sheet UI ───────────────────────────────────────────────────

  void _openSearchPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(
          onSuggestionTap: _onSuggestionTap,
          onSavedLocationTap: _onSavedLocationTap,
          onAddLocationTapped: _onAddLocationTapped,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Height of the OS gesture strip (iPhone home indicator / Android
    // gesture nav). Touches starting there are meant for the SYSTEM
    // (swipe up = minimize app), but the sheet's drag recognizer grabs the
    // first few pixels and pops the sheet open. A transparent absorber over
    // that strip keeps app gestures out; the OS gesture itself is handled
    // above the app and is unaffected.
    final systemGestureStrip =
        math.max(MediaQuery.of(context).padding.bottom, 16.0) + 2;

    return Stack(
      children: [
        _buildSheetBody(context),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: systemGestureStrip,
          child: AbsorbPointer(
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetBody(BuildContext context) {
    return BlocListener<ReportsBloc, ReportState>(
      listener: (context, state) {
        if (state is GetRecentLocationsSuccess) {
          setState(() {
            _recentLocations = state.data;
            _recentLocationsLoading = false;
            _recentBuildCounter++;
          });
        } else if (state is RecentLocationsLoading) {
          setState(() {
            _recentLocationsLoading = true;
            _recentBuildCounter++;
          });
        } else if (state is GetSavedLocationsSuccess) {
          setState(() {
            _savedLocations = state.data;
          });
        }
      },
      child: DraggableScrollableSheet(
        // Resting height shows the search bar, compact Home/Work shortcuts,
        // and the first Recent row — the driver's likeliest next tap.
        initialChildSize: 0.36,
        minChildSize: 0.13,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.13, 0.36, 0.85],
        // Fixed, quick settle. The default spring simulation takes visibly
        // long over the full 85%→13% travel and reads as lag.
        snapAnimationDuration: const Duration(milliseconds: 220),
        builder: (BuildContext ctx, ScrollController scrollController) {
          final homeLocation = _savedLocations.firstWhereOrNull(
            (e) => e.name.toLowerCase() == 'home',
          );
          final workLocation = _savedLocations.firstWhereOrNull(
            (e) => e.name.toLowerCase() == 'work',
          );
          final otherLocations = _filterAddedLocation(_savedLocations);

          // RepaintBoundary: while the sheet animates over the map platform
          // view, only the sheet's own layer moves — its contents aren't
          // re-rasterized every frame.
          return RepaintBoundary(
            child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // ── Drag handle ──────────────────────────────────────────
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── "Where to?" search bar (tap → opens SearchPage) ──────
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: styles.insets.md,
                    vertical: styles.insets.xs,
                  ),
                  child: GestureDetector(
                    onTap: _openSearchPage,
                    child: AbsorbPointer(
                      child: CustomSearchBar(
                        controller: _searchBarController,
                        onChanged: (_) {},
                        onClear: () {},
                        onFocus: () {},
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Saved locations horizontal row ────────────────────────
                // A horizontal ListView needs a bounded height, so this is
                // fixed — but sized off the card's real content (8+8
                // padding, ~20pt title line, 2pt gap, ~17pt subtitle line)
                // with headroom, because text metrics differ per platform:
                // 56 fit on iOS and overflowed by 1px on Android.
                SizedBox(
                  height: 62,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
                    clipBehavior: Clip.none,
                    children: [
                      SavedLocationCard(
                        title: 'Home',
                        icon: Assets.icons.homeSmile,
                        subtitle: (homeLocation != null)
                            ? (homeLocation.address != null &&
                                    homeLocation.address!.isNotEmpty)
                                ? homeLocation.address!
                                : 'Tap to navigate'
                            : 'Add Home',
                        isSaved: homeLocation != null,
                        placeId: homeLocation?.placeId,
                        onTap: () {
                          if (homeLocation != null) {
                            _onSavedLocationTap(homeLocation);
                          } else {
                            _onAddLocationTapped('Home');
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      SavedLocationCard(
                        title: 'Work',
                        icon: Assets.icons.briefcaseSvg,
                        subtitle: (workLocation != null)
                            ? (workLocation.address != null &&
                                    workLocation.address!.isNotEmpty)
                                ? workLocation.address!
                                : 'Tap to navigate'
                            : 'Add Work',
                        isSaved: workLocation != null,
                        placeId: workLocation?.placeId,
                        onTap: () {
                          if (workLocation != null) {
                            _onSavedLocationTap(workLocation);
                          } else {
                            _onAddLocationTapped('Work');
                          }
                        },
                      ),
                      ...otherLocations.map(
                        (location) => Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: SavedLocationCard(
                            title: location.name,
                            icon: _getIconType(location.name),
                            subtitle: location.address ?? '',
                            isSaved: true,
                            isImageFile: true,
                            placeId: location.placeId,
                            onTap: () => _onSavedLocationTap(location),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: SavedLocationCard(
                          title: 'Add',
                          icon: Assets.icons.plusSvg,
                          subtitle: 'New',
                          isSaved: false,
                          onTap: () => _onAddLocationTapped(null),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Recent locations ──────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
                  child: Text(
                    'Recent',
                    style: styles.typography.h4.textColor(styles.theme.text),
                  ),
                ),
                const SizedBox(height: 8),
                _SheetRecentLocationsWidget(
                  locations: _recentLocations,
                  isLoading: _recentLocationsLoading,
                  buildCounter: _recentBuildCounter,
                  onLocationTap: _onRecentLocationTap,
                  onLocationLongPress: _showRecentOptionsSheet,
                ),
                const SizedBox(height: 24),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  // ── Recent long-press options ─────────────────────────────────────────────

  /// Modal action sheet for a recent location. Uses the ROOT navigator so it
  /// renders above (and dims) the persistent draggable sheet underneath.
  Future<void> _showRecentOptionsSheet(RecentLocation location) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header: what this menu is about.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: styles.theme.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.history,
                          size: 20, color: styles.theme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: styles.typography.t2.medium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            location.address,
                            style: styles.typography.t3
                                .textColor(styles.theme.ash),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: styles.theme.divider),
              _RecentOptionTile(
                icon: Icons.navigation_outlined,
                label: 'Navigate here',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _onRecentLocationTap(location);
                },
              ),
              _RecentOptionTile(
                icon: Icons.bookmark_add_outlined,
                label: 'Save place',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.read<ReportsBloc>()
                    ..add(ReportsEvent.saveLocation(
                      locationName: location.name,
                      address: location.address,
                      lat: location.latitude,
                      lng: location.longitude,
                      placeId: location.placeId,
                    ))
                    ..add(ReportsEvent.getSavedLocations());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${location.name} saved to your places')),
                  );
                },
              ),
              _RecentOptionTile(
                icon: Icons.ios_share,
                label: 'Copy address',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Clipboard.setData(ClipboardData(text: location.address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied')),
                  );
                },
              ),
              _RecentOptionTile(
                icon: Icons.info_outline,
                label: 'Info',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRecentInfoDialog(location);
                },
              ),
              _RecentOptionTile(
                icon: Icons.delete_outline,
                label: 'Remove from recents',
                destructive: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.read<ReportsBloc>()
                    ..add(ReportsEvent.removeRecentLocation(
                        placeId: location.placeId))
                    ..add(ReportsEvent.getRecentLocations());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showRecentInfoDialog(RecentLocation location) {
    final visited = location.lastVisited;
    final visitedLabel =
        '${visited.day.toString().padLeft(2, '0')}/${visited.month.toString().padLeft(2, '0')}/${visited.year}';
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(location.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location.address),
            const SizedBox(height: 12),
            Text('Visited ${location.visitCount} '
                '${location.visitCount == 1 ? 'time' : 'times'} · last on $visitedLabel'),
            const SizedBox(height: 4),
            Text(
              '${location.latitude.toStringAsFixed(5)}, '
              '${location.longitude.toStringAsFixed(5)}',
              style: styles.typography.t3.textColor(styles.theme.ash),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _inferCategory(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('home')) return 'home';
    if (lowerName.contains('work') || lowerName.contains('office')) {
      return 'work';
    }
    if (lowerName.contains('gas') || lowerName.contains('fuel')) return 'gas';
    if (lowerName.contains('restaurant') || lowerName.contains('food')) {
      return 'food';
    }
    if (lowerName.contains('hospital') || lowerName.contains('medical')) {
      return 'hospital';
    }
    if (lowerName.contains('park')) return 'park';
    return 'location';
  }
}

// ── Private: recent locations list inside the draggable sheet ────────────────

/// A single row in the recent-options modal sheet.
class _RecentOptionTile extends StatelessWidget {
  const _RecentOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? styles.theme.red : styles.theme.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Text(label, style: styles.typography.t2.textColor(color)),
          ],
        ),
      ),
    );
  }
}

class _SheetRecentLocationsWidget extends StatelessWidget {
  const _SheetRecentLocationsWidget({
    required this.locations,
    required this.isLoading,
    required this.buildCounter,
    required this.onLocationTap,
    required this.onLocationLongPress,
  });

  final List<RecentLocation> locations;
  final bool isLoading;
  final int buildCounter;
  final void Function(RecentLocation) onLocationTap;
  final void Function(RecentLocation) onLocationLongPress;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (locations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Text(
          'No recent locations yet',
          style: styles.typography.t3
              .textColor(styles.theme.text.withOpacity(0.6)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < locations.length; i++)
          _SheetRecentLocationItem(
            key: ValueKey('${locations[i].placeId}_$buildCounter'),
            location: locations[i],
            showDivider: i < locations.length - 1,
            onTap: () => onLocationTap(locations[i]),
            onLongPress: () => onLocationLongPress(locations[i]),
          ),
      ],
    );
  }
}

class _SheetRecentLocationItem extends StatelessWidget {
  const _SheetRecentLocationItem({
    required this.location,
    required this.showDivider,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final RecentLocation location;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _buildIcon(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: styles.typography.t2.medium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (location.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            location.address,
                            style: styles.typography.t3.textColor(
                              styles.theme.text.withOpacity(0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showDivider) Divider(color: styles.theme.secondary, height: 1),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    final iconType = location.iconType;
    if (iconType != null && iconType.endsWith('.svg')) {
      return AppIcon(iconType, size: 20);
    }
    if (iconType != null && iconType.endsWith('.png')) {
      return Image.asset(
        iconType,
        width: 20,
        height: 20,
        errorBuilder: (_, __, ___) =>
            AppIcon(Assets.icons.recentPlaces, size: 20),
      );
    }
    return _categoryIcon(location.category ?? 'location');
  }

  Widget _categoryIcon(String type) {
    final path = _iconPath(type);
    if (path.endsWith('.svg')) return AppIcon(path, size: 20);
    return Image.asset(
      path,
      width: 20,
      height: 20,
      errorBuilder: (_, __, ___) =>
          AppIcon(Assets.icons.recentPlaces, size: 20),
    );
  }

  String _iconPath(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Assets.icons.homeBg.path;
      case 'hospital':
      case 'medical':
        return Assets.icons.hospital.path;
      case 'park':
        return Assets.icons.park.path;
      case 'gas':
      case 'fuel':
        return Assets.icons.gas.path;
      case 'food':
      case 'restaurant':
        return Assets.icons.food.path;
      case 'location':
      default:
        return Assets.icons.recentPlaces;
    }
  }
}

// ── Supporting widgets (public — also used by SearchPage) ────────────────────

class AddALocationBySuggestionSearch extends StatefulWidget {
  const AddALocationBySuggestionSearch({
    required this.onSuggestionTap,
    super.key,
  });
  final ValueChanged<SearchSuggestion> onSuggestionTap;
  @override
  State<AddALocationBySuggestionSearch> createState() =>
      _AddALocationBySuggestionSearchState();
}

class _AddALocationBySuggestionSearchState
    extends State<AddALocationBySuggestionSearch> {
  List<SearchSuggestion> _suggestions = [];
  final TextEditingController locationController = TextEditingController();
  Timer? _debounceTimer;
  final PlacesService _placesService = getIt<PlacesService>();
  bool isSearching = false;

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final position = await Geolocator.getCurrentPosition();
        final results = await _placesService.fetchGoogleAutocomplete(
          query,
          lat: position.latitude,
          lon: position.longitude,
          radius: 5000,
        );

        setState(() {
          _suggestions = results;
          isSearching = false;
        });
      } catch (e) {
        debugPrint('Error fetching suggestions: $e');
        setState(() {
          _suggestions = [];
          isSearching = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Gap(50),
              CustomSearchBar(
                controller: locationController,
                onChanged: (v) {
                  _onSearchChanged(v);
                },
                onClear: () {
                  locationController.clear();
                  setState(() {
                    _suggestions = [];
                  });
                },
                onFocus: () {},
              ),
              if (_suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SearchSuggestionList(
                    suggestions: _suggestions,
                    onTap: (suggestion) {
                      widget.onSuggestionTap(suggestion);
                      debugPrint('Suggestion tapped: ${suggestion.placeId}');
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectAndSaveLocation extends StatefulWidget {
  const SelectAndSaveLocation(
      {super.key, required this.position, required this.placeId});
  final LatLng position;
  final String placeId;
  @override
  State<SelectAndSaveLocation> createState() => _SelectAndSaveLocationState();
}

class _SelectAndSaveLocationState extends State<SelectAndSaveLocation> {
  var locationName = '';
  bool selectTypeOfName = false;
  final TextEditingController nameTypeController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          topLeft: Radius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: BlocConsumer<ReportsBloc, ReportState>(
            listener: (blocContext, state) {
              if (state is SaveLocationSuccess) {
                RSnackBar.success(
                  'Location has been saved successfully.',
                ).show(context);
                Navigator.of(context).pop();
              }
            },
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Gap(40),
                  Text(
                    (selectTypeOfName == true)
                        ? 'Enter a preferred name'
                        : 'Select location name',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),
                  const Gap(20),
                  if (selectTypeOfName == false) ...[
                    SizedBox(
                      height: 100,
                      child: ListView(
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          const Gap(30),
                          if (state is GetSavedLocationsSuccess &&
                              state.data.isNotEmpty &&
                              confirmAddedLocation(state.data,
                                      locationType: 'Home') ==
                                  false) ...[
                            LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Home';
                                });
                              },
                              image: Assets.icons.homeBg
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.homeBg.path,
                              locationName: 'Home',
                              isSelected: locationName == 'Home' ? true : false,
                            )
                          ],
                          if (state is GetSavedLocationsSuccess &&
                              state.data.isNotEmpty &&
                              confirmAddedLocation(state.data,
                                      locationType: 'Work') ==
                                  false) ...[
                            LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Work';
                                });
                              },
                              image: Assets.icons.homeBg
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.homeBg.path,
                              locationName: 'Work',
                              isSelected: locationName == 'Work' ? true : false,
                            ),
                          ],
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Gas';
                                });
                              },
                              image:
                                  Assets.icons.gas.image(width: 35, height: 35),
                              bgImagePath: Assets.icons.gasBg.path,
                              locationName: 'Gas',
                              isSelected: locationName == 'Gas' ? true : false),
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Food';
                                });
                              },
                              image: Assets.icons.food
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.foodBg.path,
                              locationName: 'Food',
                              isSelected:
                                  locationName == 'Food' ? true : false),
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Hospital';
                                });
                              },
                              image: Assets.icons.hospital
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.hospitalBg.path,
                              locationName: 'Hospital',
                              isSelected:
                                  locationName == 'Hospital' ? true : false),
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Park';
                                });
                              },
                              image: Assets.icons.park
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.parkBg.path,
                              locationName: 'Park',
                              isSelected:
                                  locationName == 'Park' ? true : false),
                          LocationItem(
                            key: UniqueKey(),
                            onSelect: () {
                              setState(() {
                                selectTypeOfName = true;
                              });
                            },
                            image: Assets.icons.plusPng
                                .image(width: 35, height: 35),
                            bgImagePath: Assets.icons.plusPng.path,
                            locationName: 'Add new',
                            isSelected: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (selectTypeOfName == true) ...[
                    SizedBox(
                      height: 100,
                      child: CustomTextField(
                        hintText: 'Enter location name ',
                        prefix: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 45,
                              width: 45,
                              child: AppIcon(
                                Assets.icons.globeSvg,
                                color: styles.theme.grey,
                                size: 18,
                              ),
                            ),
                            Text(
                              '|',
                              style: styles.typography.h4
                                  .textColor(styles.theme.ash),
                            ),
                          ],
                        ),
                        onChanged: (value) {},
                        controller: nameTypeController,
                      ),
                    )
                  ],
                  const Gap(50),
                  PrimaryButton(
                    textColor: styles.theme.white,
                    isLoading: state is SaveLocationLoading,
                    onPressed: () {
                      if (locationName == '') {
                        RSnackBar.info(
                          'Please select a location name to save this location.',
                        );
                      }
                      if (selectTypeOfName == true && locationName == '') {
                        context.read<ReportsBloc>().add(
                              ReportsEvent.saveLocation(
                                locationName: nameTypeController.text,
                                lat: widget.position.latitude,
                                lng: widget.position.longitude,
                                placeId: widget.placeId,
                              ),
                            );
                      } else {
                        context.read<ReportsBloc>().add(
                              ReportsEvent.saveLocation(
                                locationName: locationName,
                                lat: widget.position.latitude,
                                lng: widget.position.longitude,
                                placeId: widget.placeId,
                              ),
                            );
                      }
                    },
                    text: 'Save',
                  ),
                  Gap((selectTypeOfName == true) ? context.heightPx * 0.2 : 5),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class LocationItem extends StatelessWidget {
  const LocationItem({
    required this.onSelect,
    super.key,
    required this.image,
    required this.bgImagePath,
    required this.locationName,
    required this.isSelected,
  });
  final VoidCallback onSelect;
  final Widget image;
  final String bgImagePath;
  final String locationName;
  final bool isSelected;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        height: 371,
        width: 74,
        margin: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: styles.theme.white,
          border: Border.all(color: const Color(0xffFFDBDB), width: 1.5),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? styles.theme.primary.withValues(alpha: 0.4)
                  : styles.theme.grey.withValues(alpha: 0.2),
              offset: const Offset(-0.4, 4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
          image: DecorationImage(
              image: AssetImage(bgImagePath), fit: BoxFit.cover),
        ),
        duration: Duration(seconds: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 351,
              width: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: image,
                ),
                const Gap(4),
                Text(locationName, style: styles.typography.t3.medium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Universal helpers ─────────────────────────────────────────────────────────

bool confirmAddedLocation(
  List<SavedLocations> locations, {
  required String locationType,
}) {
  final savedHome = <SavedLocations>[];
  var containsLocationType = false;
  for (final e in locations) {
    if (e.name.toLowerCase() == locationType.toLowerCase() &&
        e.placeId != null &&
        savedHome.isEmpty) {
      savedHome.add(e);
      containsLocationType = true;
    }
  }
  return containsLocationType;
}

String? getSavedLocationAddress(List<SavedLocations> locations, String type) {
  for (final location in locations) {
    if (location.name.toLowerCase() == type.toLowerCase() &&
        location.placeId != null) {
      return location.address;
    }
  }
  return null;
}

class SavedLocationCard extends StatefulWidget {
  const SavedLocationCard({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.isSaved,
    required this.onTap,
    this.placeId,
    this.isImageFile = false,
    super.key,
  });

  final String title;
  final String icon;
  final String subtitle;
  final bool isSaved;
  final VoidCallback onTap;
  final String? placeId;
  final bool isImageFile;

  @override
  State<SavedLocationCard> createState() => _SavedLocationCardState();
}

class _SavedLocationCardState extends State<SavedLocationCard> {
  String? _fetchedAddress;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    if (widget.isSaved &&
        (widget.subtitle.isEmpty || widget.subtitle == 'Tap to navigate') &&
        widget.placeId != null) {
      _fetchAddress();
    }
  }

  Future<void> _fetchAddress() async {
    if (_isLoadingAddress) return;
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final placesService = getIt<PlacesService>();
      final details = await placesService.fetchGooglePlace(widget.placeId!);
      if (mounted) {
        setState(() {
          _fetchedAddress = details.formattedAddress;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displaySubtitle = _fetchedAddress ?? widget.subtitle;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.isImageFile
                    ? Image.asset(widget.icon, width: 20, height: 20)
                    : AppIcon(widget.icon,
                        size: 20, color: styles.theme.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                // The row that holds these cards has a bounded height, so
                // the column must not try to grow past it — otherwise a
                // taller-than-expected line (platform font metrics, or a
                // large system text scale) overflows the card.
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (_isLoadingAddress)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      displaySubtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
