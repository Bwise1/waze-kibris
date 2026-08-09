import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/core/models/user/nearby_user.dart';

/// Rebuild the "nearby drivers" annotation layer from scratch: delete every
/// existing pin, then create one per user. The layer is small (a handful of
/// users, refreshed on a 30s cadence upstream), so wholesale replace is
/// cheaper than diffing.
Future<void> renderNearbyUsers(
  mp.PointAnnotationManager? manager,
  List<NearbyUser> users,
) async {
  if (manager == null) return;

  try {
    await manager.deleteAll();

    for (final user in users) {
      await manager.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(user.longitude, user.latitude),
          ),
          iconImage: 'group-member-icon',
          iconSize: 0.8,
          iconAnchor: mp.IconAnchor.BOTTOM,
        ),
      );
    }
  } catch (e) {
    debugPrint('❌ Error displaying nearby users on map: $e');
  }
}

/// Rebuild the "group members" annotation layer from a map keyed by user
/// id, values `{lat, lng}`. Missing/invalid values are skipped.
Future<void> renderGroupLocations(
  mp.PointAnnotationManager? manager,
  Map<String, dynamic> groupLocations,
) async {
  if (manager == null) return;

  try {
    await manager.deleteAll();

    for (final entry in groupLocations.entries) {
      final loc = entry.value as Map<String, dynamic>;
      final lat = loc['lat'] as double?;
      final lng = loc['lng'] as double?;

      if (lat != null && lng != null) {
        await manager.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(
              coordinates: mp.Position(lng, lat),
            ),
            iconImage: 'group-member-icon',
            iconSize: 0.8,
            iconAnchor: mp.IconAnchor.BOTTOM,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Error displaying group locations: $e');
  }
}
