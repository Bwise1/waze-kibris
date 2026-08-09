import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/core/services/nav_puck_preference.dart';
import 'package:waze_kibris/core/services/puck_icon_factory.dart';

/// Loads and applies the location-puck icon on the Mapbox `LocationComponent`.
///
/// Puck choice priority (matches Google/Apple Maps on foot):
/// 1. If the current [NavPuckMode] isn't `vehicle`, use the mode-specific
///    icon (walk/cycle) — a car icon while walking is wrong regardless of
///    the user's saved preference.
/// 2. Otherwise honour [NavPuckPreference.style] (car/bus/truck) via the
///    runtime factory — the native SDKs only ship the chevron.
/// 3. Fall back to the 4.0x arrow asset for maximum sharpness.
Future<Uint8List> loadLocationPuckImage() async {
  final mode = NavPuckPreference.mode.value;
  if (mode != NavPuckMode.vehicle) {
    final bytes = await PuckIconFactory.renderMode(mode);
    if (bytes != null) return bytes;
  }

  // Vehicle pucks (car/bus/truck) are rendered at runtime — the native SDKs
  // only ship the chevron, so these are ours (PuckIconFactory).
  final style = NavPuckPreference.style.value;
  if (style != NavPuckStyle.arrow) {
    final bytes = await PuckIconFactory.render(style);
    if (bytes != null) return bytes;
  }

  // Default arrow: force the 4.0x resolution for maximum sharpness.
  final ByteData byteData =
      await rootBundle.load('assets/icons/4.0x/CurrentPosition.png');
  return byteData.buffer.asUint8List();
}

/// Push the currently-preferred puck image into the map's LocationComponent.
/// [isMounted] is a callback into the caller's `State.mounted` so we can
/// abandon safely across async gaps.
Future<void> applyLocationPuck(
  mp.MapboxMap? controller, {
  required bool Function() isMounted,
}) async {
  if (controller == null || !isMounted()) return;
  try {
    final locationPuckBytes = await loadLocationPuckImage();

    if (!isMounted()) return;

    await controller.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        puckBearing: mp.PuckBearing.COURSE,
        locationPuck: mp.LocationPuck(
          locationPuck2D: mp.LocationPuck2D(
            topImage: locationPuckBytes,
            scaleExpression: json.encode([
              'interpolate',
              ['linear'],
              ['zoom'],
              10.0,
              1.0,
              16.0,
              1.2,
              20.0,
              1.3
            ]),
          ),
        ),
        pulsingColor: 0xFF4285F4, // Blue for default mode
        pulsingEnabled: true,
        showAccuracyRing: false,
      ),
    );
  } catch (e) {
    debugPrint('Error setting up location puck: $e');
    // Fallback to default location puck
    if (isMounted()) {
      await controller.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
          puckBearing: mp.PuckBearing.COURSE,
        ),
      );
    }
  }
}

/// Re-assert the puck's LocationComponent so it renders on top of route
/// layers added since the last call. No image swap; the settings values
/// mirror the default vehicle style with pulsing.
void bringLocationPuckToTop(
  mp.MapboxMap? controller, {
  required bool Function() isMounted,
}) {
  if (controller == null || !isMounted()) return;
  try {
    controller.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,
        puckBearing: mp.PuckBearing.COURSE,
        pulsingEnabled: true,
        showAccuracyRing: false,
        pulsingColor: 0xFF4285F4, // Blue pulsing color
      ),
    );
    debugPrint('🎯 Location puck refreshed to stay on top of route layers');
  } catch (e) {
    debugPrint('Error refreshing location puck: $e');
  }
}
