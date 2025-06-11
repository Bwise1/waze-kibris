import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MarkerHelper {
  /// Loads a marker image from assets and adds it to the map controller.
  /// [name] is the key you will use for iconImage in SymbolOptions.
  static Future<void> loadMarkerImage({
    required MapLibreMapController controller,
    required String name,
    required String assetPath,
  }) async {
    final data = await rootBundle.load(assetPath);
    await controller.addImage(name, data.buffer.asUint8List());
  }

  /// Adds or updates a marker (symbol) at [location] with the given [iconImage], [iconSize], and [iconRotate].
  /// If [existingMarker] is provided, it will be removed before adding the new one.
  static Future<Symbol> addOrUpdateMarker({
    required MapLibreMapController controller,
    Symbol? existingMarker,
    required LatLng location,
    required String iconImage,
    double iconSize = 1.5,
    double? iconRotate,
  }) async {
    if (existingMarker != null) {
      await controller.removeSymbol(existingMarker);
    }
    return await controller.addSymbol(
      SymbolOptions(
        geometry: location,
        iconImage: iconImage,
        iconSize: iconSize,
        iconRotate: iconRotate,
      ),
    );
  }
}
