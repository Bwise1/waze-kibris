import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which icon represents the driver on the map during navigation.
///
/// The native Mapbox SDKs ship only the blue chevron ("arrow") — vehicle
/// pucks are an app-level feature (Waze draws its own), so the car/bus/truck
/// icons are rendered by [PuckIconFactory] rather than copied from the SDK.
enum NavPuckStyle { arrow, car, bus, truck }

class NavPuckPreference {
  NavPuckPreference._();

  static const String _storeKey = 'nav_puck_style';

  /// Current puck style. Listen to re-apply the location puck on change.
  static final ValueNotifier<NavPuckStyle> style =
      ValueNotifier(NavPuckStyle.arrow);

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
