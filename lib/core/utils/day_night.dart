import 'dart:math' as math;

/// Day: the modern Mapbox Standard style — the classic navigation-day-v1
/// paints vegetation landcover heavily green, which reads as a "green map"
/// in leafy cities. Night: the dedicated dark navigation style
/// (NavigationStyles.kt:34 in the native SDK).
const String kNavigationDayStyle = 'mapbox://styles/mapbox/standard';
const String kNavigationNightStyle =
    'mapbox://styles/mapbox/navigation-night-v1';

/// Whether it is currently night at the given coordinates, using the NOAA
/// solar position approximation (same approach as the native SDK's
/// StyleManager + Solar, which switches styles exactly at sunrise/sunset).
///
/// [nowUtc] must be in UTC. Accurate to a few minutes, which is plenty for
/// picking a map style.
bool isNightAt(DateTime nowUtc, double latitude, double longitude) {
  final dayOfYear =
      nowUtc.difference(DateTime.utc(nowUtc.year)).inDays + 1;

  // Fractional year (radians)
  final gamma = 2 *
      math.pi /
      365 *
      (dayOfYear - 1 + (nowUtc.hour - 12) / 24);

  // Equation of time (minutes) and solar declination (radians) — NOAA.
  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));
  final decl = 0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);

  final latRad = latitude * math.pi / 180;

  // Hour angle for sunrise/sunset (zenith 90.833° includes refraction).
  final cosHa = math.cos(90.833 * math.pi / 180) /
          (math.cos(latRad) * math.cos(decl)) -
      math.tan(latRad) * math.tan(decl);

  // Polar day/night edge cases.
  if (cosHa < -1) return false; // sun never sets
  if (cosHa > 1) return true; // sun never rises

  final haDeg = math.acos(cosHa) * 180 / math.pi;

  // Sunrise/sunset in minutes-from-UTC-midnight.
  final sunriseUtcMin = 720 - 4 * (longitude + haDeg) - eqTime;
  final sunsetUtcMin = 720 - 4 * (longitude - haDeg) - eqTime;

  final nowMin = nowUtc.hour * 60.0 + nowUtc.minute + nowUtc.second / 60.0;

  // Normalize into the same 0-1440 window as nowMin.
  double norm(double m) => ((m % 1440) + 1440) % 1440;
  final rise = norm(sunriseUtcMin);
  final set = norm(sunsetUtcMin);

  if (rise < set) {
    return nowMin < rise || nowMin > set;
  } else {
    // Window wraps UTC midnight.
    return nowMin > set && nowMin < rise;
  }
}
