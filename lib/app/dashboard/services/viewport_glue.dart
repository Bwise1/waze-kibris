import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/core/controllers/camera_controller.dart';

/// Compute and apply the nav-mode viewport padding from the map's laid-out
/// size. Top padding pushes the camera center down so the puck sits at
/// ~70% of screen height and the viewport shows road ahead, matching
/// Waze/Google framing.
///
/// Mapbox expects logical points on both platforms — NO devicePixelRatio
/// scaling. MbxEdgeInsets is documented as "All fields' values are in
/// `logical pixel` units", and the plugin's changelog records the change
/// that made every screen-related unit logical pixels on both platforms,
/// matching Flutter. The old `Platform.isAndroid ? devicePixelRatio : 1.0`
/// multiplier inflated Android padding ~2.75x — that's why the trace
/// logged navPadding 1488 and the puck ended up first behind the sheet
/// and then far too high. Verified against the plugin source, not
/// inferred. The `devicePixelRatio` parameter is retained so callers can
/// keep passing it and stay platform-agnostic, but is intentionally
/// unused.
void applyNavigationViewportPadding({
  required CameraController cameraController,
  required double mapHeightLogical,
  // ignore: avoid_unused_constructor_parameters
  required double devicePixelRatio,
  double bottomObstructionLogical = 0,
}) {
  // The bottom sheet covers the lower part of the map, so padding must
  // describe the visible area — otherwise the camera centres the puck
  // behind the sheet.
  final bottom = bottomObstructionLogical.clamp(0.0, mapHeightLogical * 0.5);

  // Mapbox centres the camera in the box left *between* the paddings, so
  // the puck's screen position is (top + bottom_edge) / 2 — not `top`.
  // Solve for the top inset that lands the puck where we want it, instead
  // of picking a fraction and hoping: with a bottom inset, a "55%" top
  // padding actually put the puck at ~41% (too high), which is what went
  // wrong.
  //
  // 0.72 keeps the puck low enough that the viewport is mostly road ahead,
  // while staying clear of the nav card.
  const puckScreenFraction = 0.72;
  final target = mapHeightLogical * puckScreenFraction;
  final top = (2 * target - mapHeightLogical + bottom)
      .clamp(0.0, mapHeightLogical * 0.8);

  cameraController.setNavigationPadding(
    mp.MbxEdgeInsets(
      top: top,
      left: 0,
      bottom: bottom,
      right: 0,
    ),
  );
}
