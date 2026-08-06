import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Distance/speed units. Metric is the default (Northern Cyprus uses km).
enum DistanceUnit { metric, imperial }

/// User-facing driving preferences that affect guidance, routing, and the
/// navigation HUD. Every value is a [ValueNotifier] so widgets and services
/// can react without a bloc, matching MapStylePreference / NavPuckPreference.
///
/// Call [load] once at startup before the first navigation session.
class NavSettings {
  NavSettings._();

  // Keys
  static const _kVoiceEnabled = 'nav_voice_enabled';
  static const _kVoiceVolume = 'nav_voice_volume';
  static const _kUnits = 'nav_distance_unit';
  static const _kAvoidTolls = 'nav_avoid_tolls';
  static const _kAvoidHighways = 'nav_avoid_highways';
  static const _kAvoidFerries = 'nav_avoid_ferries';
  static const _kKeepAwake = 'nav_keep_screen_awake';
  static const _kShowSpeedometer = 'nav_show_speedometer';
  static const _kMutedReportTypes = 'nav_muted_report_types';

  /// Spoken turn-by-turn guidance. Also toggled by the banner's mute tap,
  /// which now persists through this notifier.
  static final ValueNotifier<bool> voiceEnabled = ValueNotifier(true);

  /// Guidance volume, 0–1.
  static final ValueNotifier<double> voiceVolume = ValueNotifier(1);

  static final ValueNotifier<DistanceUnit> units =
      ValueNotifier(DistanceUnit.metric);

  static final ValueNotifier<bool> avoidTolls = ValueNotifier(false);
  static final ValueNotifier<bool> avoidHighways = ValueNotifier(false);
  static final ValueNotifier<bool> avoidFerries = ValueNotifier(false);

  /// Keep the screen on during active navigation.
  static final ValueNotifier<bool> keepScreenAwake = ValueNotifier(true);

  /// Show the speed readout in the navigation HUD.
  static final ValueNotifier<bool> showSpeedometer = ValueNotifier(true);

  /// Report types the user does NOT want to see or be alerted about
  /// (lowercase type strings, e.g. 'police'). Empty = show everything.
  static final ValueNotifier<Set<String>> mutedReportTypes =
      ValueNotifier(<String>{});

  /// Report types offered in settings, in display order.
  static const List<({String type, String label})> reportTypes = [
    (type: 'police', label: 'Police'),
    (type: 'traffic', label: 'Traffic'),
    (type: 'accident', label: 'Accidents'),
    (type: 'photo', label: 'Speed cameras'),
  ];

  static bool isReportTypeEnabled(String type) =>
      !mutedReportTypes.value.contains(type.toLowerCase());

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      voiceEnabled.value = prefs.getBool(_kVoiceEnabled) ?? true;
      voiceVolume.value = prefs.getDouble(_kVoiceVolume) ?? 1.0;
      units.value = DistanceUnit.values.firstWhere(
        (u) => u.name == prefs.getString(_kUnits),
        orElse: () => DistanceUnit.metric,
      );
      avoidTolls.value = prefs.getBool(_kAvoidTolls) ?? false;
      avoidHighways.value = prefs.getBool(_kAvoidHighways) ?? false;
      avoidFerries.value = prefs.getBool(_kAvoidFerries) ?? false;
      keepScreenAwake.value = prefs.getBool(_kKeepAwake) ?? true;
      showSpeedometer.value = prefs.getBool(_kShowSpeedometer) ?? true;
      mutedReportTypes.value =
          (prefs.getStringList(_kMutedReportTypes) ?? const []).toSet();
    } catch (_) {}
  }

  static Future<void> setVoiceEnabled(bool value) async {
    voiceEnabled.value = value;
    await _writeBool(_kVoiceEnabled, value);
  }

  static Future<void> setVoiceVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    voiceVolume.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kVoiceVolume, v);
    } catch (_) {}
  }

  static Future<void> setUnits(DistanceUnit value) async {
    units.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUnits, value.name);
    } catch (_) {}
  }

  static Future<void> setAvoidTolls(bool value) async {
    avoidTolls.value = value;
    await _writeBool(_kAvoidTolls, value);
  }

  static Future<void> setAvoidHighways(bool value) async {
    avoidHighways.value = value;
    await _writeBool(_kAvoidHighways, value);
  }

  static Future<void> setAvoidFerries(bool value) async {
    avoidFerries.value = value;
    await _writeBool(_kAvoidFerries, value);
  }

  static Future<void> setKeepScreenAwake(bool value) async {
    keepScreenAwake.value = value;
    await _writeBool(_kKeepAwake, value);
  }

  static Future<void> setShowSpeedometer(bool value) async {
    showSpeedometer.value = value;
    await _writeBool(_kShowSpeedometer, value);
  }

  static Future<void> setReportTypeEnabled(String type, bool enabled) async {
    final next = Set<String>.from(mutedReportTypes.value);
    if (enabled) {
      next.remove(type.toLowerCase());
    } else {
      next.add(type.toLowerCase());
    }
    mutedReportTypes.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kMutedReportTypes, next.toList());
    } catch (_) {}
  }

  /// Mapbox Directions `exclude` value for the current avoid-settings, or
  /// null when nothing is excluded.
  static String? get routeExcludeParam {
    final parts = <String>[
      if (avoidTolls.value) 'toll',
      if (avoidHighways.value) 'motorway',
      if (avoidFerries.value) 'ferry',
    ];
    return parts.isEmpty ? null : parts.join(',');
  }

  static Future<void> _writeBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}
