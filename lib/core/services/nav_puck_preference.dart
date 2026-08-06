import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which icon represents the driver on the map during navigation.
///
/// The native Mapbox SDKs ship only the blue chevron ("arrow") — vehicle
/// pucks are an app-level feature (Waze draws its own), so the car/bus/truck
/// icons are rendered by [PuckIconFactory] rather than copied from the SDK.
enum NavPuckStyle { arrow, car, bike, bus, truck }

/// Puck shown while walking or cycling. These aren't user-selectable: the
/// vehicle preference above describes how you drive, and showing a car
/// while someone is on foot is simply wrong, so the active travel mode
/// overrides it (matching Google/Apple Maps).
enum NavPuckMode { vehicle, walk, cycle }

class NavPuckPreference {
  NavPuckPreference._();

  static const String _storeKey = 'nav_puck_style';

  /// Current puck style. Listen to re-apply the location puck on change.
  static final ValueNotifier<NavPuckStyle> style =
      ValueNotifier(NavPuckStyle.arrow);

  /// Active travel mode. Set from navigation state; not persisted, since it
  /// only applies for the duration of a trip.
  static final ValueNotifier<NavPuckMode> mode =
      ValueNotifier(NavPuckMode.vehicle);

  static void setMode(NavPuckMode value) => mode.value = value;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_storeKey);
      if (stored != null) {
        style.value = NavPuckStyle.values.firstWhere(
          (s) => s.name == stored,
          orElse: () => NavPuckStyle.arrow,
        );
      }
    } catch (_) {}
  }

  static Future<void> setStyle(NavPuckStyle value) async {
    style.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey, value.name);
    } catch (_) {}
  }
}
