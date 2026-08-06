import 'dart:developer' as developer;

import 'package:geocoding/geocoding.dart';

/// Turns coordinates into a short, human place label like "Abayomi St" or
/// "Ikate, Lagos" — enough to tell two reports of the same type apart.
///
/// Results are cached per rounded coordinate for the app's lifetime: reverse
/// geocoding is a platform call with rate limits, and reports don't move.
class PlaceLabelService {
  PlaceLabelService._();

  static final Map<String, String?> _cache = {};

  /// ~11 m of precision — fine enough that two distinct reports on the same
  /// street still share a cache entry only when they are effectively at the
  /// same spot.
  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// Short label for the coordinate, or null when nothing useful resolves.
  /// Never throws — a missing label is always acceptable.
  static Future<String?> shortLabel(double lat, double lng) async {
    final key = _key(lat, lng);
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        _cache[key] = null;
        return null;
      }
      final label = _labelFrom(placemarks.first);
      _cache[key] = label;
      return label;
    } catch (e) {
      developer.log('reverse geocode failed: $e', name: 'PlaceLabelService');
      // Cache the miss so a failing lookup isn't retried on every rebuild.
      _cache[key] = null;
      return null;
    }
  }

  /// Prefer the street, then the neighbourhood, then the city — whichever is
  /// the most specific thing available.
  static String? _labelFrom(Placemark p) {
    final street = p.thoroughfare?.trim();
    final area = p.subLocality?.trim();
    final city = p.locality?.trim();

    if (street != null && street.isNotEmpty) {
      // "Abayomi St, Ikate" reads better than the street alone when we have
      // the neighbourhood too.
      if (area != null && area.isNotEmpty && area != street) {
        return '$street, $area';
      }
      return street;
    }
    if (area != null && area.isNotEmpty) {
      if (city != null && city.isNotEmpty && city != area) {
        return '$area, $city';
      }
      return area;
    }
    if (city != null && city.isNotEmpty) return city;

    final name = p.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }
}
