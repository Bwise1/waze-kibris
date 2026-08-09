import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/core/services/map_style_preference.dart';

/// The MapWidget layer: fullscreen platform view wrapped in a LayoutBuilder
/// that gates initialisation on non-zero constraints and reports resize
/// events (post-frame) so the parent can update camera padding without
/// side-effecting from build.
///
/// Bindings all come in as constructor params rather than being read from
/// the parent's context/mixin — keeps this file free of dashboard state
/// so it can be reasoned about (and hot-reloaded) in isolation.
class MapLayer extends StatelessWidget {
  const MapLayer({
    required this.mapWidgetKey,
    required this.readyToBuild,
    required this.lastReportFetchPosition,
    required this.initialStyleUri,
    required this.onInitialStyleResolved,
    required this.onMapCreated,
    required this.onMapTap,
    required this.viewport,
    required this.onUserMapGesture,
    required this.onCameraChange,
    required this.onMapResize,
    super.key,
  });

  final GlobalKey mapWidgetKey;

  /// Gate the whole subtree until the parent has run its post-frame boot.
  final bool readyToBuild;

  /// Seed camera position, if we already know where the user is.
  final Position? lastReportFetchPosition;

  /// Style URI the parent has already resolved (may be null the very first
  /// build). When null, [MapLayer] resolves it once from prefs and reports
  /// via [onInitialStyleResolved] so the parent can persist it.
  final String? initialStyleUri;

  /// Callback fired when the initial style URI was resolved by this widget
  /// (i.e. parent passed null). The parent stores it and re-uses it.
  final ValueChanged<String> onInitialStyleResolved;

  /// Forwarded to `mp.MapWidget.onMapCreated`.
  final void Function(mp.MapboxMap controller) onMapCreated;

  /// Forwarded to `mp.MapWidget.onTapListener`.
  final mp.OnMapTapListener onMapTap;

  /// Forwarded to `mp.MapWidget.viewport`.
  final mp.ViewportState? viewport;

  /// Any user pan / pinch-zoom exits follow mode — parent decides how.
  final void Function(mp.MapContentGestureContext ctx) onUserMapGesture;

  /// Fired for programmatic + user camera moves. Parent updates its compass.
  final void Function(mp.CameraChangedEventData data) onCameraChange;

  /// Fired at most once per real resize (>1px), during a post-frame callback.
  /// Parent recomputes viewport padding here — build stays pure.
  final ValueChanged<double> onMapResize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!readyToBuild) {
          return const SizedBox.shrink();
        }
        // Avoid initializing Mapbox while the widget has not been laid out yet.
        if (constraints.maxWidth < 2 || constraints.maxHeight < 2) {
          return const SizedBox.shrink();
        }

        // Report resize post-frame — the parent uses this to keep the nav
        // camera's lower-third puck framing in sync with map size (rotation,
        // resize). Passing the value out (vs computing here) keeps this
        // widget free of dashboard state.
        final newHeight = constraints.maxHeight;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onMapResize(newHeight);
        });

        final styleUri = initialStyleUri ??
            () {
              final resolved = MapStylePreference.resolveStyleUri(
                latitude: lastReportFetchPosition?.latitude,
                longitude: lastReportFetchPosition?.longitude,
              );
              // Report back so the parent latches the same value for
              // subsequent builds (matches the old `??=` behaviour).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                onInitialStyleResolved(resolved);
              });
              return resolved;
            }();

        return mp.MapWidget(
          key: mapWidgetKey,
          // Mapbox's dedicated navigation style (what the native turn-by-turn
          // SDK ships). Resolved once at creation from the Auto/Day/Night
          // preference; later switches go through applyMapStyleUri.
          styleUri: styleUri,
          onMapCreated: onMapCreated,
          onTapListener: onMapTap,
          // Native camera control during navigation (iOS):
          // FollowPuckViewportState keeps camera and puck in 60fps lockstep
          // on the render thread.
          viewport: viewport,
          // Any user pan / pinch-zoom exits follow mode so the recenter pill
          // swaps in for the speedometer. Rotate / tilt gestures aren't
          // exposed by the Flutter plugin as separate listeners — they only
          // surface through onCameraChangeListener, which also fires for our
          // own programmatic easeTo calls and would create a feedback loop.
          // These fire for programmatic camera moves too, so check for a
          // real finger: a genuine gesture always reports a touch position
          // inside the map view.
          onScrollListener: onUserMapGesture,
          onZoomListener: onUserMapGesture,
          // Drives our own compass. Only the notifier updates, so this
          // doesn't rebuild the screen.
          onCameraChangeListener: onCameraChange,
          cameraOptions: lastReportFetchPosition != null
              ? mp.CameraOptions(
                  center: mp.Point(
                    coordinates: mp.Position(
                      lastReportFetchPosition!.longitude,
                      lastReportFetchPosition!.latitude,
                    ),
                  ),
                  zoom: 15.0,
                )
              : null,
        );
      },
    );
  }
}
