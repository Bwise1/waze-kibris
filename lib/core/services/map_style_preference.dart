import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waze_kibris/core/utils/day_night.dart';

/// Waze-style map appearance setting: Auto follows solar sunrise/sunset at
/// the user's location (native Mapbox behavior); Day/Night force a style.
enum MapStyleMode { auto, day, night }

class MapStylePreference {
  MapStylePreference._();

  static const String _storeKey = 'map_style_mode';

  /// Current mode. Listen to react to user changes.
  static final ValueNotifier<MapStyleMode> mode =
      ValueNotifier(MapStyleMode.day);

  static Future<void> load() async {
    // TODO: temporarily forcing the light (day) map style on every launch —
    // ignore the persisted preference for now. To restore Auto/Day/Night,
    // swap this back to reading the stored value with an `auto` fallback.
    mode.value = MapStyleMode.day;
  }

  static Future<void> setMode(MapStyleMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey, value.name);
    } catch (_) {}
  }

  /// Style URI for the current mode. [latitude]/[longitude] are only used
  /// in auto mode (solar day/night at the user's location; defaults to
  /// Cyprus when no fix is available yet).
  static String resolveStyleUri({double? latitude, double? longitude}) {
    switch (mode.value) {
      case MapStyleMode.day:
        return kNavigationDayStyle;
      case MapStyleMode.night:
        return kNavigationNightStyle;
      case MapStyleMode.auto:
        final night = isNightAt(
          DateTime.now().toUtc(),
          latitude ?? 35.19,
          longitude ?? 33.36,
        );
        return night ? kNavigationNightStyle : kNavigationDayStyle;
    }
  }
}
