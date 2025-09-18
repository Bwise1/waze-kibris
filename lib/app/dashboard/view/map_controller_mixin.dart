import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/services/snap_to_road_service.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';

mixin MapControllerMixin<T extends StatefulWidget> on State<T> {
  mp.MapboxMap? _mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;
  // Removed: Using LineLayer instead of PolylineAnnotationManager
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.PointAnnotationManager? reportAnnotationManager;

  // Camera tracking variables
  bool _isFollowingUser = true;
  Timer? _cameraResetTimer;
  Timer? _cameraUpdateTimer;
  Timer? _polylineUpdateTimer;
  Timer? _reportIconUpdateTimer;
  Position? _lastCameraPosition;
  
  // Store current reports for zoom updates
  List<ReportData> _currentReports = [];
  // Removed: LineLayer handles width automatically

  // Track current polyline for adaptive width updates
  // Removed: No longer using encoded polylines
  List<PointLatLng>? _currentPolylinePoints;

  // Snap to road service
  final SnapToRoadService _snapToRoadService = SnapToRoadService();

  // Getters for subclasses
  mp.MapboxMap? get mapboxMapController => _mapboxMapController;
  bool get isFollowingUser => _isFollowingUser;

  // Navigation bloc must be provided by the implementing class
  NavigationBloc get navigationBloc;

  // Optional method for position updates - can be overridden
  void onPositionUpdate(Position position) {
    // Override in implementing class to handle position updates
  }

  // Setters for camera following
  void setIsFollowingUser(bool value) {
    setState(() {
      _isFollowingUser = value;
    });
  }

  void onMapCreated(mp.MapboxMap controller) {
    setState(() {
      _mapboxMapController = controller;
    });

    // Setup annotation managers
    _mapboxMapController?.annotations
        .createPointAnnotationManager()
        .then((manager) {
      setState(() {
        pointAnnotationManager = manager;
      });
    });

    // Setup report annotation manager
    _mapboxMapController?.annotations
        .createPointAnnotationManager()
        .then((manager) {
      setState(() {
        reportAnnotationManager = manager;
      });
    });

    // Listen for map interactions to update polyline width
    _setupMapListeners();

    // Setup location component with custom CurrentPosition.png
    _setupLocationPuck();

    // Hide UI elements
    _mapboxMapController?.logo.updateSettings(mp.LogoSettings(enabled: false));
    _mapboxMapController?.attribution
        .updateSettings(mp.AttributionSettings(enabled: false));
    _mapboxMapController?.compass
        .updateSettings(mp.CompassSettings(enabled: false));
    _mapboxMapController?.scaleBar
        .updateSettings(mp.ScaleBarSettings(enabled: false));

    // Add report icons to map style
    _setupReportIcons();
  }

  /// Add report icons to map style for different report types (Waze-style)
  Future<void> _setupReportIcons() async {
    if (_mapboxMapController == null) return;

    try {
      // Create Waze-style circular report icons with chat bubbles
      await _createWazeStyleReportIcon('police-icon', 'assets/icons/police.png',
          const Color(0xFF4285F4)); // Blue
      await _createWazeStyleReportIcon('traffic-icon',
          'assets/icons/warning-cars.png', const Color(0xFFFF9800)); // Orange
      await _createWazeStyleReportIcon('accident-icon',
          'assets/icons/accident.png', const Color(0xFFF44336)); // Red

      debugPrint('✅ Waze-style report icons created successfully');
    } catch (e) {
      debugPrint('❌ Error creating Waze-style report icons: $e');
    }
  }

  /// Create a Waze-style circular report icon with chat bubble effect
  Future<void> _createWazeStyleReportIcon(
      String iconId, String assetPath, Color backgroundColor) async {
    try {
      // Load the original icon
      final ByteData iconData = await rootBundle.load(assetPath);
      final Uint8List iconBytes = iconData.buffer.asUint8List();
      final ui.Codec iconCodec = await ui.instantiateImageCodec(iconBytes);
      final ui.FrameInfo iconFrame = await iconCodec.getNextFrame();
      final ui.Image originalIcon = iconFrame.image;

      // Create a larger canvas for the Waze-style bubble
      const double bubbleSize = 64.0;
      const double iconSize = 32.0;
      const double bubbleRadius = 28.0;
      const double tailHeight = 12.0;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint bubblePaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;

      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      // Draw shadow (slightly offset)
      const double shadowOffset = 2.0;
      canvas.drawCircle(
        Offset(bubbleRadius + shadowOffset, bubbleRadius + shadowOffset),
        bubbleRadius,
        shadowPaint,
      );

      // Draw chat bubble tail shadow
      final Path tailShadowPath = Path();
      tailShadowPath.moveTo(
          bubbleRadius + shadowOffset, bubbleSize - tailHeight + shadowOffset);
      tailShadowPath.lineTo(
          bubbleRadius - 6 + shadowOffset, bubbleSize + shadowOffset);
      tailShadowPath.lineTo(
          bubbleRadius + 6 + shadowOffset, bubbleSize + shadowOffset);
      tailShadowPath.close();
      canvas.drawPath(tailShadowPath, shadowPaint);

      // Draw main circular background
      canvas.drawCircle(
        Offset(bubbleRadius, bubbleRadius),
        bubbleRadius,
        bubblePaint,
      );

      // Draw chat bubble tail
      final Path tailPath = Path();
      tailPath.moveTo(bubbleRadius, bubbleSize - tailHeight);
      tailPath.lineTo(bubbleRadius - 6, bubbleSize);
      tailPath.lineTo(bubbleRadius + 6, bubbleSize);
      tailPath.close();
      canvas.drawPath(tailPath, bubblePaint);

      // Draw white border around circle
      canvas.drawCircle(
        Offset(bubbleRadius, bubbleRadius),
        bubbleRadius,
        borderPaint,
      );

      // Draw white border around tail
      canvas.drawPath(tailPath, borderPaint);

      // Draw the icon in the center of the circle
      final Offset iconOffset = Offset(
        bubbleRadius - (iconSize / 2),
        bubbleRadius - (iconSize / 2),
      );

      canvas.drawImageRect(
        originalIcon,
        Rect.fromLTWH(0, 0, originalIcon.width.toDouble(),
            originalIcon.height.toDouble()),
        Rect.fromLTWH(iconOffset.dx, iconOffset.dy, iconSize, iconSize),
        Paint(),
      );

      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image finalImage = await picture.toImage(
          bubbleSize.toInt(), (bubbleSize + tailHeight).toInt());
      final ByteData? byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List finalImageBytes = byteData.buffer.asUint8List();

        final mp.MbxImage mbxImage = mp.MbxImage(
          width: bubbleSize.toInt(),
          height: (bubbleSize + tailHeight).toInt(),
          data: finalImageBytes,
        );

        await _mapboxMapController!.style.addStyleImage(
          iconId,
          1.0,
          mbxImage,
          false,
          [],
          [],
          null,
        );

        debugPrint('✅ Created Waze-style icon: $iconId');
      }
    } catch (e) {
      debugPrint('❌ Error creating Waze-style icon $iconId: $e');
      // Fallback to simple icon
      await _addReportIconToStyle(iconId, assetPath);
    }
  }

  /// Add a specific report icon to map style
  Future<void> _addReportIconToStyle(String iconId, String assetPath) async {
    try {
      final ByteData byteData = await rootBundle.load(assetPath);
      final Uint8List imageBytes = byteData.buffer.asUint8List();

      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final mbxImage = mp.MbxImage(
        width: image.width,
        height: image.height,
        data: imageBytes,
      );

      await _mapboxMapController!.style.addStyleImage(
        iconId,
        1.0, // Scale factor
        mbxImage,
        false, // Not SDF
        [], // No stretch
        [], // No stretch
        null, // No content
      );
    } catch (e) {
      debugPrint('Error adding $iconId to style: $e');
    }
  }

  /// Display reports as markers on the map
  Future<void> displayReportsOnMap(List<ReportData> reports) async {
    if (reportAnnotationManager == null) {
      debugPrint('Report annotation manager not ready');
      return;
    }

    try {
      // Store current reports for zoom updates
      _currentReports = reports;
      
      // Clear existing report markers
      await reportAnnotationManager!.deleteAll();

      debugPrint('🗺️ Adding ${reports.length} report markers to map');

      for (final report in reports) {
        await _addReportMarker(report);
      }

      debugPrint('✅ Successfully added ${reports.length} report markers');
    } catch (e) {
      debugPrint('❌ Error displaying reports on map: $e');
    }
  }

  /// Add a single report marker to the map (Waze-style optimized)
  Future<void> _addReportMarker(ReportData report) async {
    if (reportAnnotationManager == null) return;

    try {
      final iconId = _getReportIcon(report.type);
      final iconSize = await _getAdaptiveReportIconSize();

      await reportAnnotationManager!.create(
        mp.PointAnnotationOptions(
          geometry: mp.Point(
            coordinates: mp.Position(
              report.longitude,
              report.latitude,
            ),
          ),
          iconImage: iconId,
          iconSize: iconSize, // Dynamic size based on zoom level
          iconOpacity: 1.0, // Full opacity for better visibility
          // Ensure reports appear above other elements but below user location
          iconAnchor: mp.IconAnchor.BOTTOM, // Anchor at bottom like chat bubble
          // Add slight offset to avoid overlap with user location
          iconOffset: [0.0, -5.0], // Lift slightly above ground level
        ),
      );

      debugPrint(
          '📍 Added Waze-style ${report.type} report marker at ${report.latitude}, ${report.longitude}');
    } catch (e) {
      debugPrint('Error adding report marker: $e');
    }
  }

  /// Get appropriate icon ID for report type
  String _getReportIcon(String reportType) {
    switch (reportType.toLowerCase()) {
      case 'police':
        return 'police-icon';
      case 'traffic':
        return 'traffic-icon';
      case 'accident':
        return 'accident-icon';
      default:
        return 'police-icon'; // Default fallback
    }
  }

  void updateMapForNavigationMode(bool isNavigating) async {
    if (_mapboxMapController == null) return;

    final locationPuckBytes = await _loadLocationPuckImage();

    if (isNavigating) {
      // Navigation mode: enhanced location tracking like Waze with larger, more visible icon
      await _mapboxMapController?.location.updateSettings(
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
                14.0,
                1.0,
                16.0,
                1.0,
                18.0,
                1.0,
                20.0,
                1.0
              ]),
            ),
          ),
          pulsingColor: 0xFFFF0000,
          pulsingEnabled: true,
          showAccuracyRing: false,
        ),
      );
    } else {
      // Normal mode: smaller, standard location display
      await _mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: false,
          locationPuck: mp.LocationPuck(
            locationPuck2D: mp.LocationPuck2D(
              topImage: locationPuckBytes,
              scaleExpression: json.encode([
                'interpolate',
                ['linear'],
                ['zoom'],
                10.0,
                1.0,
                14.0,
                1.0,
                16.0,
                1.0,
                18.0,
                1.0,
                20.0,
                1.0
              ]),
            ),
          ),
          pulsingColor: 0xFF4285F4, // Blue for normal mode
          pulsingEnabled: false, // No pulsing in normal mode
          showAccuracyRing: true,
        ),
      );
    }
  }

  // Removed: Old drawPolyline method - now using professional LineLayer approach

  /// Draw polyline using professional GeoJsonSource + LineLayer (Waze-style)
  Future<void> drawMapboxPolyline(MapboxRoute route) async {
    await clearRoutePolyline();

    if (_mapboxMapController == null) {
      debugPrint('Map controller not ready.');
      return;
    }

    try {
      // Convert Mapbox geometry coordinates to PointLatLng for marker placement
      final List<PointLatLng> routePoints = [];
      for (final coordinate in route.geometry.coordinates) {
        if (coordinate.length >= 2) {
          routePoints
              .add(PointLatLng(coordinate[1], coordinate[0])); // lat, lng
        }
      }

      if (routePoints.isEmpty) {
        debugPrint('Mapbox route has no geometry points.');
        return;
      }

      // Store points for adaptive updates
      _currentPolylinePoints = routePoints;

      // Create GeoJSON source with route data
      final geoJsonData = {
        'type': 'Feature',
        'properties': {
          'route-color': _getTrafficColor(route), // Traffic-aware color
          'route-congestion': _getCongestionLevel(route), // Congestion data
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': route.geometry.coordinates,
        }
      };

      // Remove existing sources and layers
      await _removeRouteLayer();

      // Add GeoJSON source
      await _mapboxMapController!.style.addSource(mp.GeoJsonSource(
        id: "route-source",
        data: json.encode(geoJsonData),
      ));

      // Add main route layer with professional Waze-style expressions
      // Add below location puck to ensure user location stays on top
      await _mapboxMapController!.style.addLayer(mp.LineLayer(
        id: "route-layer-main",
        sourceId: "route-source",
        lineJoin: mp.LineJoin.ROUND,
        lineCap: mp.LineCap.ROUND,
        // Dynamic width based on zoom level (Waze-style)
        lineWidthExpression: [
          'interpolate',
          ['exponential', 1.5],
          ['zoom'],
          10.0, 4.0, // Far zoom: thin line
          13.0, 8.0, // Medium zoom
          16.0, 12.0, // Close zoom
          19.0, 18.0, // Very close: thick navigation line
          22.0, 24.0, // Maximum zoom: very thick
        ],
        // Traffic-aware color with fallback (Waze-style)
        lineColorExpression: [
          'interpolate',
          ['linear'],
          ['zoom'],
          8.0, '#3366ff', // Blue at far zoom
          11.0,
          [
            'coalesce',
            ['get', 'route-color'],
            '#ff4444' // Default red for navigation
          ],
        ],
        lineOpacity: 0.9,
      ));

      // Add route border/outline layer for depth (like Waze)
      await _mapboxMapController!.style.addLayer(mp.LineLayer(
        id: "route-layer-border",
        sourceId: "route-source",
        lineJoin: mp.LineJoin.ROUND,
        lineCap: mp.LineCap.ROUND,
        // Border is slightly wider than main line
        lineWidthExpression: [
          'interpolate',
          ['exponential', 1.5],
          ['zoom'],
          10.0, 6.0, // Far zoom: thin border
          13.0, 10.0, // Medium zoom
          16.0, 14.0, // Close zoom
          19.0, 20.0, // Very close
          22.0, 26.0, // Maximum zoom
        ],
        lineColor: 0xFFCC0000, // Darker red border
        lineOpacity: 0.6,
      ));

      // Add route markers
      await _addRouteMarkers(routePoints);

      // Fit camera to route bounds
      await _fitCameraToRoute(routePoints);

      // Ensure location puck stays on top after adding route layers
      _refreshLocationPuckOnTop();

      debugPrint('Professional route layer created successfully');
    } catch (e) {
      debugPrint('Error creating professional route layer: $e');
      // Could implement user notification here
    }
  }

  /// Get traffic-aware color based on route congestion (Waze-style)
  String _getTrafficColor(MapboxRoute route) {
    // For now, use route duration/distance ratio to estimate congestion
    final avgSpeed = route.distance / route.duration * 3.6; // km/h

    if (avgSpeed > 60) {
      return '#00ff00'; // Green: free flow
    } else if (avgSpeed > 40) {
      return '#ffff00'; // Yellow: moderate traffic
    } else if (avgSpeed > 20) {
      return '#ff8800'; // Orange: slow traffic
    } else {
      return '#ff0000'; // Red: heavy traffic
    }
  }

  /// Get congestion level for advanced styling
  double _getCongestionLevel(MapboxRoute route) {
    final avgSpeed = route.distance / route.duration * 3.6; // km/h
    return (60 - avgSpeed).clamp(0.0, 60.0) / 60.0; // 0-1 scale
  }

  /// Remove existing route layers
  Future<void> _removeRouteLayer() async {
    try {
      // Remove layers if they exist
      if (await _mapboxMapController!.style
          .styleLayerExists("route-layer-main")) {
        await _mapboxMapController!.style.removeStyleLayer("route-layer-main");
      }
      if (await _mapboxMapController!.style
          .styleLayerExists("route-layer-border")) {
        await _mapboxMapController!.style
            .removeStyleLayer("route-layer-border");
      }
      // Remove source if it exists
      if (await _mapboxMapController!.style.styleSourceExists("route-source")) {
        await _mapboxMapController!.style.removeStyleSource("route-source");
      }
    } catch (e) {
      debugPrint('Error removing existing route layers: $e');
    }
  }

  /// Fallback method - show error message if LineLayer fails
  Future<void> _fallbackToAnnotationMethod(MapboxRoute route) async {
    debugPrint(
        'LineLayer failed - no fallback available. Route not displayed.');
    // Could show a user-friendly error message here if needed
  }

  /// Smooth polyline points for better curve representation (Waze-style)
  List<PointLatLng> _smoothPolylinePoints(List<PointLatLng> points) {
    if (points.length < 3) return points;

    List<PointLatLng> smoothed = [];
    smoothed.add(points.first); // Keep first point

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final next = points[i + 1];

      // Calculate distances
      final distToPrev = _calculateDistance(prev, current);
      final distToNext = _calculateDistance(current, next);

      // Only smooth if points are close enough (avoid smoothing long straight segments)
      if (distToPrev < 100 && distToNext < 100) {
        // Apply gentle smoothing factor
        const smoothingFactor = 0.15;

        final smoothedLat = current.latitude +
            smoothingFactor *
                ((prev.latitude + next.latitude) / 2 - current.latitude);
        final smoothedLng = current.longitude +
            smoothingFactor *
                ((prev.longitude + next.longitude) / 2 - current.longitude);

        smoothed.add(PointLatLng(smoothedLat, smoothedLng));
      } else {
        smoothed.add(current); // Keep original point for long segments
      }
    }

    smoothed.add(points.last); // Keep last point
    return smoothed;
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(PointLatLng point1, PointLatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  Future<void> _addRouteMarkers(List<PointLatLng> points) async {
    if (pointAnnotationManager == null || points.isEmpty) return;

    // Get adaptive marker size
    final markerSize = await _getAdaptiveMarkerSize();

    // Load and add destination marker image to map style
    await _addDestinationImageToStyle();

    // Add start marker (using default marker)
    await pointAnnotationManager!.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(
            coordinates: mp.Position(
          points.first.longitude,
          points.first.latitude,
        )),
        iconSize: markerSize,
      ),
    );

    // Add destination marker (using custom destination icon)
    await pointAnnotationManager!.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(
            coordinates: mp.Position(
          points.last.longitude,
          points.last.latitude,
        )),
        iconSize: markerSize * 1.2, // Destination marker slightly larger
        iconImage: 'destination-marker', // Reference the added image by ID
      ),
    );
  }

  Future<void> clearRoutePolyline() async {
    // Clear professional LineLayer routes
    await _removeRouteLayer();

    // Clear route markers
    await pointAnnotationManager?.deleteAll();

    // Clear stored polyline data
    // Using LineLayer instead of encoded polylines
    _currentPolylinePoints = null;
  }

  /// Calculates adaptive marker size based on zoom level
  /// Size mapping: 1x=48w, 2x=64w, 3x=96w, 4x=128w
  Future<double> _getAdaptiveMarkerSize() async {
    try {
      final cameraState = await _mapboxMapController?.getCameraState();
      if (cameraState == null) return 1.0;

      final zoom = cameraState.zoom;
      final currentState = navigationBloc.state;
      final isNavigating = currentState is NavigationInProgress;

      // Adaptive marker sizing based on actual icon dimensions
      if (zoom >= 19) {
        // Very close zoom - 4x size (128w)
        return isNavigating ? 4.0 : 3.5;
      } else if (zoom >= 18) {
        // Close zoom - 3x size (96w)
        return isNavigating ? 3.0 : 2.5;
      } else if (zoom >= 16) {
        // Medium-close zoom - 2x size (64w)
        return isNavigating ? 2.0 : 1.8;
      } else if (zoom >= 14) {
        // Medium zoom - 1.5x size (between 48w and 64w)
        return isNavigating ? 1.5 : 1.3;
      } else if (zoom >= 12) {
        // Medium-far zoom - 1x size (48w)
        return isNavigating ? 1.0 : 0.9;
      } else if (zoom >= 10) {
        // Far zoom - smaller than 1x
        return isNavigating ? 0.8 : 0.7;
      } else {
        // Very far zoom - minimal size
        return isNavigating ? 0.6 : 0.5;
      }
    } catch (e) {
      debugPrint('Error getting camera state for adaptive marker size: $e');
      return 1.0;
    }
  }

  /// Calculate adaptive report icon size based on zoom level
  Future<double> _getAdaptiveReportIconSize() async {
    if (_mapboxMapController == null) return 0.7;

    try {
      final cameraState = await _mapboxMapController?.getCameraState();
      if (cameraState == null) return 0.7;

      final zoom = cameraState.zoom;

      // Report icon sizing - smaller than route markers but still responsive
      if (zoom >= 19) {
        return 1.2; // Very close zoom - larger reports
      } else if (zoom >= 18) {
        return 1.0; // Close zoom - standard size
      } else if (zoom >= 16) {
        return 0.8; // Medium-close zoom
      } else if (zoom >= 14) {
        return 0.7; // Medium zoom - default size
      } else if (zoom >= 12) {
        return 0.6; // Medium-far zoom
      } else if (zoom >= 10) {
        return 0.5; // Far zoom - smaller
      } else {
        return 0.4; // Very far zoom - minimal but visible
      }
    } catch (e) {
      debugPrint('Error getting camera state for report icon size: $e');
      return 0.7;
    }
  }

  /// Calculate adaptive line width based on zoom level (Waze-style with limits)
  Future<double> _getAdaptiveLineWidth() async {
    if (_mapboxMapController == null) return 8.0;

    try {
      final cameraState = await _mapboxMapController!.getCameraState();
      final zoom = cameraState.zoom;
      final currentState = navigationBloc.state;
      final isNavigating = currentState is NavigationInProgress;

      // Waze-style adaptive width - thicker and more visible
      double baseWidth;

      if (zoom >= 19) {
        // Maximum detail - very thick like Waze
        baseWidth = isNavigating ? 24.0 : 18.0;
      } else if (zoom >= 18) {
        // Very close zoom - thick navigation line
        baseWidth = isNavigating ? 20.0 : 16.0;
      } else if (zoom >= 17) {
        // Close zoom - prominent visibility
        baseWidth = isNavigating ? 18.0 : 14.0;
      } else if (zoom >= 16) {
        // Medium-close zoom - standard thick navigation
        baseWidth = isNavigating ? 16.0 : 12.0;
      } else if (zoom >= 15) {
        // Medium zoom - still thick
        baseWidth = isNavigating ? 14.0 : 10.0;
      } else if (zoom >= 14) {
        // Medium-far zoom - visible thickness
        baseWidth = isNavigating ? 12.0 : 8.0;
      } else if (zoom >= 12) {
        // Far zoom - thinner but still visible
        baseWidth = isNavigating ? 10.0 : 6.0;
      } else if (zoom >= 10) {
        // Very far zoom - moderate thickness
        baseWidth = isNavigating ? 8.0 : 4.0;
      } else if (zoom >= 8) {
        // Overview level - thin but visible
        baseWidth = isNavigating ? 6.0 : 3.0;
      } else {
        // Maximum zoom out - minimal but visible
        baseWidth = isNavigating ? 4.0 : 2.0;
      }

      // Apply maximum width limit to prevent overly thick lines
      const double maxWidth = 28.0; // Allows thicker Waze-style lines
      const double minWidth = 1.0; // Allows very thin lines when zoomed out

      return baseWidth.clamp(minWidth, maxWidth);
    } catch (e) {
      debugPrint('Error getting camera state for adaptive width: $e');
      return 8.0; // Better default fallback
    }
  }

  Future<void> _fitCameraToRoute(List<PointLatLng> points) async {
    if (_mapboxMapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = mp.CoordinateBounds(
      southwest: mp.Point(coordinates: mp.Position(minLng, minLat)),
      northeast: mp.Point(coordinates: mp.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    final cameraOptions = await _mapboxMapController!.cameraForCoordinateBounds(
      bounds,
      mp.MbxEdgeInsets(top: 150.0, left: 80.0, bottom: 200.0, right: 80.0),
      null,
      null,
      null,
      null,
    );

    await _mapboxMapController!.flyTo(
      cameraOptions,
      mp.MapAnimationOptions(duration: 1500),
    );
  }

  Future<void> setupPositionTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Reduced frequency to stabilize ETA calculations
    );

    _userPositionStream?.cancel();

    // Get current position immediately and move camera to user location
    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
          // locationSettings: locationSettings,
          );

      // Move camera to user location immediately with Waze-like zoom
      _mapboxMapController?.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
                currentPosition.longitude, currentPosition.latitude),
          ),
          zoom: 16.0, // Waze-style zoom level
          bearing: 0.0,
          pitch: 0.0,
        ),
        mp.MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
    }

    _userPositionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        // Apply snap-to-road during navigation
        final currentState = navigationBloc.state;
        Position processedPosition = position;

        if (currentState is NavigationInProgress) {
          try {
            final snapResult = await _snapToRoadService.snapToRoad(position);

            // Create new position with snapped coordinates and route bearing
            processedPosition = Position(
              latitude: snapResult.snappedPosition.latitude,
              longitude: snapResult.snappedPosition.longitude,
              timestamp: position.timestamp,
              accuracy: position.accuracy,
              altitude: position.altitude,
              altitudeAccuracy: position.altitudeAccuracy,
              heading: snapResult.bearing, // Use calculated route bearing
              headingAccuracy: position.headingAccuracy,
              speed: position.speed,
              speedAccuracy: position.speedAccuracy,
            );

            // Log route status for debugging
            if (snapResult.needsReroute) {
              debugPrint(
                  '🔄 REROUTE NEEDED: ${snapResult.distanceFromRoute.toStringAsFixed(1)}m from route');
              // Trigger rerouting in navigation bloc
              // navigationBloc.add(TriggerReroute(
              //   currentPosition: position,
              //   reason: 'User deviated ${snapResult.distanceFromRoute.toStringAsFixed(1)}m from route',
              // ));
            } else if (snapResult.isOffRoute) {
              debugPrint(
                  '⚠️ USER OFF ROUTE: ${snapResult.distanceFromRoute.toStringAsFixed(1)}m away');
            } else if (snapResult.isOnRoute) {
              debugPrint(
                  '✅ ON ROUTE: Progress ${(snapResult.routeProgress * 100).toStringAsFixed(1)}%');
            }
          } catch (e) {
            debugPrint('Snap-to-road error: $e');
            // Use original position if snapping fails
            processedPosition = position;
          }
        }

        // Send processed position to navigation bloc
        navigationBloc
            .add(NavigationPositionUpdated(position: processedPosition));

        // Notify implementing class of position update
        onPositionUpdate(processedPosition);

        // Update map camera if following user
        if (_mapboxMapController != null && _isFollowingUser) {
          updateMapCamera(processedPosition);
        }
      },
      onError: (Object error) {
        debugPrint('Position stream error: $error');
      },
    );
  }

  void updateMapCamera(Position position) {
    if (_mapboxMapController == null) return;

    // Check if user has moved significantly to avoid unnecessary updates
    if (_lastCameraPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastCameraPosition!.latitude,
        _lastCameraPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < 3.0) return; // Reduced threshold for more frequent updates
    }

    // Debounce camera updates to prevent excessive calls
    _cameraUpdateTimer?.cancel();
    _cameraUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      _actuallyUpdateCamera(position);
    });
  }

  void _actuallyUpdateCamera(Position position) {
    if (_mapboxMapController == null) return;

    _lastCameraPosition = position;
    final currentState = navigationBloc.state;

    if (currentState is NavigationInProgress &&
        !currentState.isOverviewVisible) {
      // Navigation mode: Waze-style flat view following user direction
      _mapboxMapController
          ?.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
          zoom: 17.0, // Reduced from 18.0 to prevent super zoom
          bearing: position.heading, // Follow user's heading direction
          pitch: 0.0, // Flat view like Waze, no 3D tilt
        ),
        mp.MapAnimationOptions(duration: 1500),
      )
          .then((_) {
        // Update polyline width after camera change (debounced)
        _debouncedUpdatePolylineWidth();
        
        // Update report icon sizes after camera/zoom change (debounced)
        _debouncedUpdateReportIconSizes();
      });
    } else if (currentState is NavigationInProgress &&
        currentState.isOverviewVisible) {
      // Overview mode during navigation: flat top-down for route overview
      _mapboxMapController
          ?.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
          zoom: 14.0,
          bearing: 0.0,
          pitch: 0.0,
        ),
        mp.MapAnimationOptions(duration: 1500),
      )
          .then((_) {
        // Update polyline width after camera change (debounced)
        _debouncedUpdatePolylineWidth();
        
        // Update report icon sizes after camera/zoom change (debounced)
        _debouncedUpdateReportIconSizes();
      });
    } else {
      // Normal browsing mode: update position and bearing but preserve zoom
      _mapboxMapController?.getCameraState().then((currentCamera) {
        _mapboxMapController
            ?.easeTo(
          mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(position.longitude, position.latitude),
            ),
            zoom: currentCamera?.zoom, // Preserve current zoom level
            bearing: position.heading, // Update bearing for map rotation
            pitch: 0.0, // Keep flat view
          ),
          mp.MapAnimationOptions(duration: 1500),
        )
            .then((_) {
          // Update polyline width after camera change
          _updatePolylineWidth();
        });
      });
    }
  }

  /// Setup map event listeners for adaptive polyline and marker updates
  void _setupMapListeners() {
    // Note: Mapbox Flutter SDK might not have direct camera change listeners
    // The polyline width and marker sizes will update automatically during our camera animations
    // and can be manually triggered when needed via debounced functions
  }

  /// Debounced polyline width update to prevent excessive recreations
  void _debouncedUpdatePolylineWidth() {
    _polylineUpdateTimer?.cancel();
    _polylineUpdateTimer = Timer(const Duration(milliseconds: 50), () {
      _updatePolylineWidth();
    });
  }

  /// Debounced report icon size update to prevent excessive recreations
  void _debouncedUpdateReportIconSizes() {
    _reportIconUpdateTimer?.cancel();
    _reportIconUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      _updateReportIconSizes();
    });
  }

  /// Update all report marker sizes based on current zoom level
  Future<void> _updateReportIconSizes() async {
    if (_currentReports.isEmpty) return;
    
    try {
      // Clear existing report markers
      await reportAnnotationManager?.deleteAll();
      
      // Re-add all reports with updated sizes
      for (final report in _currentReports) {
        await _addReportMarker(report);
      }
      
      debugPrint('🔄 Updated ${_currentReports.length} report icon sizes');
    } catch (e) {
      debugPrint('❌ Error updating report icon sizes: $e');
    }
  }

  /// Update polyline width based on current zoom level
  void _updatePolylineWidth() async {
    // LineLayer automatically handles width updates via expressions
    // No manual width updates needed - zoom-based styling is built into the layer
    debugPrint('LineLayer handles width automatically via zoom expressions');
  }

  /// Update markers with adaptive sizing for current zoom level
  Future<void> _updateMarkersForZoom() async {
    if (pointAnnotationManager == null ||
        _currentPolylinePoints == null ||
        _currentPolylinePoints!.isEmpty) return;

    try {
      final markerSize = await _getAdaptiveMarkerSize();

      // Clear existing markers
      await pointAnnotationManager!.deleteAll();

      // Recreate markers with adaptive sizing
      await _addRouteMarkers(_currentPolylinePoints!);
    } catch (e) {
      debugPrint('Error updating markers for zoom: $e');
    }
  }

  // Removed: LineLayer handles zoom-based width automatically

  /// Force immediate navigation zoom without delays
  void forceNavigationZoom() async {
    if (_mapboxMapController == null) return;

    try {
      // Get current position immediately
      final currentPosition = await Geolocator.getCurrentPosition();

      // Immediately zoom to navigation level
      await _mapboxMapController?.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(
                currentPosition.longitude, currentPosition.latitude),
          ),
          zoom: 17.0, // Reduced navigation zoom level to prevent super zoom
          bearing: currentPosition.heading,
          pitch: 0.0,
        ),
        mp.MapAnimationOptions(duration: 500), // Faster animation
      );

      // Immediately update polyline width without debouncing
      _updatePolylineWidth();
    } catch (e) {
      debugPrint('Error forcing navigation zoom: $e');
    }
  }

  /// Initialize snap-to-road service with route data
  void initializeSnapToRoad(MapboxRoute route, {PlacesService? placesService}) {
    debugPrint('Initializing snap-to-road with Mapbox route');
    _snapToRoadService.setMapboxRoute(route);
    
    // Set PlacesService for Map Matching functionality
    if (placesService != null) {
      _snapToRoadService.setPlacesService(placesService);
      debugPrint('🗺️ Map Matching enabled for edge cases');
    }
  }

  /// Clear snap-to-road service
  void clearSnapToRoad() {
    debugPrint('Clearing snap-to-road service');
    _snapToRoadService.clearRoute();
  }

  /// Load location puck image from assets with proper resolution handling
  Future<Uint8List> _loadLocationPuckImage() async {
    // Force load the 4.0x resolution for maximum sharpness
    final ByteData byteData =
        await rootBundle.load('assets/icons/4.0x/CurrentPosition.png');
    return byteData.buffer.asUint8List();
  }

  // /// Load destination marker image from assets with proper resolution handling
  // Future<Uint8List> _loadDestinationImage() async {
  //   // Force load the 4.0x resolution for maximum sharpness (same as CurrentPosition)
  //   final ByteData byteData =
  //       await rootBundle.load('assets/icons/destination.png');
  //   return byteData.buffer.asUint8List();
  // }

  // /// Add destination marker image to map style
  // Future<void> _addDestinationImageToStyle() async {
  //   if (_mapboxMapController == null) return;

  //   try {
  //     // Load the destination image
  //     final destinationImageBytes = await _loadDestinationImage();

  //     // Create MbxImage from the bytes (adjusted to match LocationPuck size)
  //     final mbxImage = mp.MbxImage(
  //       width: 48,
  //       height: 48,
  //       data: destinationImageBytes,
  //     );

  //     // Add image to map style with a unique ID
  //     await _mapboxMapController!.style.addStyleImage(
  //       'destination-marker',
  //       1.0, // Scale factor
  //       mbxImage,
  //       false, // SDF (Signed Distance Field) - false for bitmap images
  //       [], // StretchX - empty for normal images
  //       [], // StretchY - empty for normal images
  //       null, // Content - null for normal images
  //     );
  //   } catch (e) {
  //     debugPrint('Error adding destination image to style: $e');
  //   }
  // }

  Future<void> _addDestinationImageToStyle() async {
    if (_mapboxMapController == null) return;

    // Get the device's pixel ratio
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    try {
      // 1. Load the raw byte data from the asset
      // Flutter's asset bundle will automatically handle selecting the correct
      // resolution (e.g., from /2.0x or /3.0x folders)
      final ByteData byteData =
          await rootBundle.load('assets/icons/2.0x/destination.png');
      final Uint8List imageBytes = byteData.buffer.asUint8List();

      // 2. Decode the image to get its actual width and height
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // 3. Create MbxImage with the *correct* dimensions
      final mbxImage = mp.MbxImage(
        width: image.width,
        height: image.height,
        data: imageBytes,
      );

      // 4. Add the correctly sized image to the map style
      await _mapboxMapController!.style.addStyleImage(
        'destination-marker',
        devicePixelRatio, // Use device pixel ratio for perfect scaling
        mbxImage,
        false,
        [], // StretchX - empty for normal images
        [], // StretchY - empty for normal images
        null, // Content - null for normal images
      );
    } catch (e) {
      debugPrint('Error adding destination image to style: $e');
    }
  }

  /// Refresh location puck to ensure it stays on top of route layers
  void _refreshLocationPuckOnTop() {
    try {
      // Re-enable the location component which brings it to the top layer
      _mapboxMapController?.location.updateSettings(
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

  /// Setup location puck with custom image
  Future<void> _setupLocationPuck() async {
    try {
      final locationPuckBytes = await _loadLocationPuckImage();

      await _mapboxMapController?.location.updateSettings(
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
                20.0,
                1.0
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
      await _mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: true,
          puckBearingEnabled: true,
          puckBearing: mp.PuckBearing.COURSE,
        ),
      );
    }
  }

  @override
  void dispose() {
    _userPositionStream?.cancel();
    _cameraResetTimer?.cancel();
    _cameraUpdateTimer?.cancel();
    _polylineUpdateTimer?.cancel();
    _reportIconUpdateTimer?.cancel();
    reportAnnotationManager?.deleteAll(); // Clean up report markers
    _mapboxMapController?.dispose();
    super.dispose();
  }
}
