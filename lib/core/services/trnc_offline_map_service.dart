import 'dart:developer';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Downloads Mapbox tiles + style resources for Northern Cyprus (approx. bbox).
///
/// Call after the user opts in (e.g. from profile). Requires network and
/// valid Mapbox access token configured for the app.
class TrncOfflineMapService {
  TrncOfflineMapService._();

  static const String regionId = 'trnc-offline-v1';

  /// Rough bounding polygon: TRNC + surrounding useful map context.
  static Map<String?, Object?> get trncPolygonGeometry => {
        'type': 'Polygon',
        'coordinates': <Object>[
          <Object>[
            <Object>[32.35, 34.95],
            <Object>[34.65, 34.95],
            <Object>[34.65, 35.75],
            <Object>[32.35, 35.75],
            <Object>[32.35, 34.95],
          ],
        ],
      };

  /// Starts style pack + tile region download. Progress logs to console.
  static Future<void> downloadTrncRegion({
    void Function(String message)? onLog,
  }) async {
    void emit(String m) {
      log(m, name: 'TrncOfflineMap');
      onLog?.call(m);
    }

    const styleUri = MapboxStyles.STANDARD;
    final offline = await OfflineManager.create();
    await offline.loadStylePack(
      styleUri,
      StylePackLoadOptions(acceptExpired: false),
      (p) => emit(
            'Style pack $styleUri: '
            '${p.completedResourceCount}/${p.requiredResourceCount}',
          ),
    );

    final tileStore = await TileStore.createDefault();
    final opts = TileRegionLoadOptions(
      geometry: trncPolygonGeometry,
      descriptorsOptions: [
        TilesetDescriptorOptions(
          styleURI: styleUri,
          minZoom: 6,
          maxZoom: 16,
          stylePackOptions: StylePackLoadOptions(acceptExpired: false),
        ),
      ],
      metadata: <String?, Object?>{'region': 'TRNC'},
      acceptExpired: false,
      networkRestriction: NetworkRestriction.NONE,
    );

    await tileStore.loadTileRegion(
      regionId,
      opts,
      (p) => emit(
            'Tiles ${p.completedResourceCount}/${p.completedResourceSize} bytes',
          ),
    );
    emit('TRNC offline region download finished.');
  }
}
