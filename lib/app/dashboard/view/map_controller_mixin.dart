import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;
import 'package:vector_graphics/src/listener.dart' as internal; // For decodeVectorGraphics
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/gen/assets.gen.dart';
import 'package:waze_kibris/app/dashboard/services/snap_to_road_service.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/core/controllers/camera_controller.dart';
import 'package:waze_kibris/core/services/route_visualization_service.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';

mixin MapControllerMixin<T extends StatefulWidget> on State<T> {
  mp.MapboxMap? _mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;
  mp.PointAnnotationManager? pointAnnotationManager;
  // mp.PointAnnotationManager? reportAnnotationManager; // Removed in favor of clustering
  // Navigation puck layer constants
  static const String _puckSourceId = 'navigation-puck-source';
  static const String _puckLayerId = 'navigation-puck-layer';

  // State
  // mp.PointAnnotationManager? navigationPuckManager; // Removed
  // mp.PointAnnotation? _navigationPuckAnnotation; // Removed // The actual puck annotation

  // Camera controller - replaces individual camera variables
  late final CameraController _cameraController;
  // Route visualization service - replaces old polyline drawing
  late final RouteVisualizationService _routeVisualizationService;
  Timer? _reportIconUpdateTimer;

  // Store current reports for zoom updates
  List<ReportData> _currentReports = [];
  List<PointLatLng>? _currentPolylinePoints;

  // Snap to road service
  final SnapToRoadService _snapToRoadService = SnapToRoadService();

  // Clustering Constants
  static const List<String> _reportTypes = ['police', 'traffic', 'accident'];
  
  String _getReportSourceId(String type) => 'report-source-$type';
  String _getClusterLayerId(String type) => 'report-layer-clusters-$type';
  String _getClusterCountLayerId(String type) => 'report-layer-cluster-count-$type';
  String _getUnclusteredLayerId(String type) => 'report-layer-unclustered-$type';

  // Getters for subclasses
  mp.MapboxMap? get mapboxMapController => _mapboxMapController;
  bool get isFollowingUser => _cameraController.isFollowingUser;
  CameraController get cameraController => _cameraController;

  // Navigation bloc must be provided by the implementing class
  NavigationBloc get navigationBloc;

  // Optional method for position updates - can be overridden
  void onPositionUpdate(Position position) {
    // Override in implementing class to handle position updates
  }

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController();
    _routeVisualizationService = RouteVisualizationService();
  }

  // Setters for camera following
  void setIsFollowingUser(bool value) {
    if (value) {
      _cameraController.enableFollowUser();
    } else {
      _cameraController.disableFollowUser();
    }
  }

  void onMapCreated(mp.MapboxMap controller) {
    setState(() {
      _mapboxMapController = controller;
    });

    // Initialize camera controller with map
    _cameraController.initialize(controller);

    // Initialize route visualization service with map (await it)
    _initializeRouteVisualization(controller);

    // Setup annotation managers
    _mapboxMapController?.annotations
        .createPointAnnotationManager()
        .then((manager) {
      setState(() {
        pointAnnotationManager = manager;
      });
    });

    // Setup report annotation manager - REMOVED for clustering
    // _mapboxMapController?.annotations
    //     .createPointAnnotationManager()
    //     .then((manager) {
    //   setState(() {
    //     reportAnnotationManager = manager;
    //   });
    // });

    // Setup navigation puck manager - REMOVED
    // _mapboxMapController?.annotations
    //     .createPointAnnotationManager()
    //     .then((manager) {
    //   setState(() {
    //     navigationPuckManager = manager;
    //   });
    // });

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
    _setupReportIcons().then((_) {
      // Initialize clustering after icons are loaded
      _setupReportClustering();
    });
  }

  /// Setup GeoJSON source and layers for report clustering (Type-Based)
  Future<void> _setupReportClustering() async {
    if (_mapboxMapController == null) return;

    try {
      for (final type in _reportTypes) {
        final sourceId = _getReportSourceId(type);
        final clusterLayerId = _getClusterLayerId(type);
        final clusterCountLayerId = _getClusterCountLayerId(type);
        final unclusteredLayerId = _getUnclusteredLayerId(type);
        final iconId = _getReportIcon(type); // e.g., 'police-icon'

        // Determine offset based on type to prevent overlap
        List<double> offset = [0.0, -5.0]; // Default (Police/Center)
        if (type == 'traffic') {
          offset = [20.0, -5.0]; // Right
        } else if (type == 'accident') {
          offset = [-20.0, -5.0]; // Left
        }

        // 1. Add GeoJSON Source with clustering enabled
        await _mapboxMapController!.style.addSource(
          mp.GeoJsonSource(
            id: sourceId,
            data: jsonEncode({'type': 'FeatureCollection', 'features': []}),
            cluster: true,
            clusterRadius: 50, // Radius of each cluster when clustering points
            clusterMaxZoom: 14, // Max zoom to cluster points on
          ),
        );

        // 2. Add Cluster Layer (Icon with Count)
        // Instead of a circle, we use the report icon itself for the cluster
        await _mapboxMapController!.style.addLayer(
          mp.SymbolLayer(
            id: clusterLayerId,
            sourceId: sourceId,
            filter: ['has', 'point_count'], // Only show when clustered
            iconImage: iconId, // Use the specific report icon
            iconSize: 0.7, // Reduced from 0.9
            iconAllowOverlap: true,
            iconAnchor: mp.IconAnchor.BOTTOM,
            iconOffset: offset, // Apply offset
          ),
        );

        // 3. Add Cluster Count Layer (Text on top of icon)
        await _mapboxMapController!.style.addLayer(
          mp.SymbolLayer(
            id: clusterCountLayerId,
            sourceId: sourceId,
            filter: ['has', 'point_count'],
            textField: jsonEncode(['get', 'point_count_abbreviated']),
            textSize: 10.0, // Reduced from 12.0
            textColor: 0xFFFFFFFF, // White text
            textHaloColor: 0xFF000000, // Black outline for readability
            textHaloWidth: 1.0,
            textAnchor: mp.TextAnchor.CENTER,
            textOffset: [offset[0] / 10.0, -1.5], // Adjust text position to match icon offset (approximate scale)
          ),
        );

        // 4. Add Unclustered Layer (Individual Icons)
        await _mapboxMapController!.style.addLayer(
          mp.SymbolLayer(
            id: unclusteredLayerId,
            sourceId: sourceId,
            filter: ['!', ['has', 'point_count']], // Only show when NOT clustered
            iconImage: iconId, // Use the specific report icon
            iconSize: 0.5, // Reduced from 0.7
            iconAllowOverlap: true,
            iconAnchor: mp.IconAnchor.BOTTOM,
            iconOffset: offset, // Apply offset
          ),
        );
      }

      debugPrint('✅ Type-based report clustering setup completed');
      
      // If we have pending reports that were skipped during setup, display them now
      if (_currentReports.isNotEmpty) {
        displayReportsOnMap(_currentReports);
      }
    } catch (e) {
      debugPrint('❌ Error setting up report clustering: $e');
    }
  }

  /// Initialize route visualization service asynchronously
  Future<void> _initializeRouteVisualization(mp.MapboxMap controller) async {
    try {
      await _routeVisualizationService.initialize(controller);
      debugPrint('✅ RouteVisualizationService initialized in MapControllerMixin');
    } catch (e) {
      debugPrint('❌ Failed to initialize RouteVisualizationService: $e');
    }
  }

  /// Add report icons to map style for different report types (Waze-style)
  Future<void> _setupReportIcons() async {
    if (_mapboxMapController == null) return;

    try {
      // Create Waze-style circular report icons with chat bubbles
      // Using softer colors as requested
      await _createWazeStyleReportIcon(
          'police-icon',
          Assets.icons.reports.police,
          const Color(0xFF5B96F5)); // Softer Blue
      
      await _createWazeStyleReportIcon(
          'traffic-icon',
          Assets.icons.reports.trafic,
          const Color(0xFFFFB74D), // Softer Orange
          manualOffset: const Offset(0, 5)); // Nudge traffic icon down slightly
      
      await _createWazeStyleReportIcon(
          'accident-icon',
          Assets.icons.reports.accident,
          const Color(0xFFE57373)); // Softer Red

      debugPrint('✅ Waze-style report icons created successfully');
    } catch (e) {
      debugPrint('❌ Error creating Waze-style report icons: $e');
    }
  }

  /// Create a Waze-style circular report icon with chat bubble effect
  Future<void> _createWazeStyleReportIcon(
      String iconId, String assetPath, Color backgroundColor,
      {Offset? manualOffset}) async {
    try {
      // Scale factor for high-resolution rendering (3x for crispness)
      const double scaleFactor = 3.0;
      
      // Base dimensions (will be multiplied by scaleFactor)
      const double baseBubbleSize = 64.0;
      const double baseIconSize = 42.0;
      const double baseBubbleRadius = 28.0;
      
      // Scaled dimensions
      const double bubbleSize = baseBubbleSize * scaleFactor;
      const double iconSize = baseIconSize * scaleFactor;
      const double bubbleRadius = baseBubbleRadius * scaleFactor;

      // Load the original icon (SVG or PNG)
      ui.Image image;
      
      if (assetPath.endsWith('.svg')) {
        // Load SVG
        final String svgString = await rootBundle.loadString(assetPath);
        final Uint8List compiledBytes = await encodeSvg(xml: svgString, debugName: assetPath);
        final PictureInfo pictureInfo = await internal.decodeVectorGraphics(
          compiledBytes.buffer.asByteData(), // Positional argument
          loader: MemoryBytesLoader(compiledBytes.buffer.asByteData()),
          textDirection: TextDirection.ltr,
          locale: const Locale('en', 'US'),
          clipViewbox: false,
        );
        
        // Calculate scale to fit target size
        final double scaleX = iconSize / pictureInfo.size.width;
        final double scaleY = iconSize / pictureInfo.size.height;
        final double scale = math.min(scaleX, scaleY);
        
        // Draw scaled picture to image
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        
        // Scale the canvas to make the SVG larger
        canvas.scale(scale);
        canvas.drawPicture(pictureInfo.picture);
        
        final ui.Picture scaledPicture = recorder.endRecording();
        image = await scaledPicture.toImage(iconSize.toInt(), iconSize.toInt());
        
        pictureInfo.picture.dispose();
      } else {
        final ByteData byteData = await rootBundle.load(assetPath);
        final Uint8List imageBytes = byteData.buffer.asUint8List();

        final codec = await ui.instantiateImageCodec(imageBytes);
        final frameInfo = await codec.getNextFrame();
        image = frameInfo.image;
      }

      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List imageBytes = byteData.buffer.asUint8List();

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

  /// Display reports using GeoJSON source for clustering (Type-Based)
  Future<void> displayReportsOnMap(List<ReportData> reports) async {
    if (_mapboxMapController == null) return;

    try {
      _currentReports = reports;

      for (final type in _reportTypes) {
        // Filter reports for this specific type
        // Note: We need to handle case-insensitivity and potential mismatches
        final typeReports = reports.where((r) => 
          r.type.toLowerCase() == type.toLowerCase() || 
          (type == 'police' && r.type.toLowerCase() == 'police') || // Explicit checks if needed
          (type == 'traffic' && r.type.toLowerCase() == 'traffic')
        ).toList();

        // Convert to Features
        final features = typeReports.map((report) {
          return {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [report.longitude, report.latitude],
            },
            'properties': {
              'id': report.id,
              'type': report.type,
            },
          };
        }).toList();

        final geoJson = {
          'type': 'FeatureCollection',
          'features': features,
        };

        // Update the specific source for this type
        final sourceId = _getReportSourceId(type);
        
        // Check if source exists before trying to update it (prevents race condition)
        if (await _mapboxMapController!.style.styleSourceExists(sourceId)) {
          await _mapboxMapController!.style.setStyleSourceProperty(
            sourceId,
            'data',
            jsonEncode(geoJson),
          );
        } else {
          debugPrint('⚠️ Source $sourceId not ready yet, skipping update');
        }
      }

      debugPrint('✅ Updated report sources with ${reports.length} features across types');
    } catch (e) {
      debugPrint('❌ Error displaying reports on map: $e');
    }
  }

  // Removed _addReportMarker as we now use GeoJSON source


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

    // Use camera controller for navigation mode
    if (isNavigating) {
      _cameraController.enableNavigationMode();
    } else {
      _cameraController.disableNavigationMode();
    }

    final locationPuckBytes = await _loadLocationPuckImage();

    if (isNavigating) {
      // Navigation mode: Disable built-in location component and use custom snapped puck
      await _mapboxMapController?.location.updateSettings(
        mp.LocationComponentSettings(
          enabled: false, // Disable built-in to prevent "ghost" puck
          puckBearingEnabled: true,
          puckBearing: mp.PuckBearing.COURSE,
        ),
      );

      // Ensure the puck image is in the style
      await _ensureNavigationPuckImageLoaded();

      // Create the custom puck if it doesn't exist
      // _navigationPuckAnnotation is removed, now we check for layer existence
      if (!await _mapboxMapController!.style.styleLayerExists(_puckLayerId)) {
        await _createNavigationPuck();
      }
    } else {
      // Normal mode: Enable built-in location component
      
      // Remove custom puck if it exists
      if (_mapboxMapController != null) {
        if (await _mapboxMapController!.style.styleLayerExists(_puckLayerId)) {
          await _mapboxMapController!.style.removeStyleLayer(_puckLayerId);
        }
        if (await _mapboxMapController!.style.styleSourceExists(_puckSourceId)) {
          await _mapboxMapController!.style.removeStyleSource(_puckSourceId);
        }
      }

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
                10.0, 1.0,
                14.0, 1.0,
                16.0, 1.0,
                18.0, 1.0,
                20.0, 1.0
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

  /// Ensure navigation puck image is loaded into map style
  Future<void> _ensureNavigationPuckImageLoaded() async {
    if (_mapboxMapController == null) return;

    try {
      // Check if image already exists (optional, but good for performance)
      // For now, we'll just try to add it. If it exists, it might update or throw, 
      // but addStyleImage usually handles updates fine or we can catch.
      
      // Load the image data
      final ByteData byteData = await rootBundle.load('assets/icons/4.0x/CurrentPosition.png');
      final Uint8List imageBytes = byteData.buffer.asUint8List();

      // Get dimensions to create MbxImage
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final mbxImage = mp.MbxImage(
        width: image.width,
        height: image.height,
        data: imageBytes,
      );

      await _mapboxMapController!.style.addStyleImage(
        'navigation-puck',
        4.0, // Scale factor (since we loaded 4.0x asset)
        mbxImage,
        false,
        [],
        [],
        null,
      );
      debugPrint('✅ Navigation puck image added to style');
    } catch (e) {
      debugPrint('⚠️ Error adding navigation puck image: $e');
    }
  }

  // Animation controller for smooth puck movement
  AnimationController? _puckAnimationController;
  Animation<double>? _latAnimation;
  Animation<double>? _lngAnimation;
  Animation<double>? _bearingAnimation;
  
  // Track last known puck state for interpolation
  mp.Position? _lastPuckPosition;
  double? _lastPuckBearing;



  /// Create the custom navigation puck using SymbolLayer for smooth scaling
  Future<void> _createNavigationPuck() async {
    if (_mapboxMapController == null) return;

    try {
      // Get current position to start
      final position = await Geolocator.getCurrentPosition();
      _lastPuckPosition = mp.Position(position.longitude, position.latitude);
      _lastPuckBearing = position.heading;
      
      // Initialize animation controller if needed
      if (_puckAnimationController == null && this is TickerProvider) {
        _puckAnimationController = AnimationController(
          vsync: this as TickerProvider,
          duration: const Duration(milliseconds: 1000), // Smooth 1s transition
        );
        
        _puckAnimationController!.addListener(() {
          if (_latAnimation != null && _lngAnimation != null && _bearingAnimation != null) {
            final currentLat = _latAnimation!.value;
            final currentLng = _lngAnimation!.value;
            final currentBearing = _bearingAnimation!.value;
            
            // Update the GeoJSON source with interpolated position
            _updatePuckSource(mp.Position(currentLng, currentLat), currentBearing);
          }
        });
      }

      // 1. Add GeoJSON Source
      final initialGeoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [position.longitude, position.latitude],
            },
            'properties': {
              'bearing': position.heading,
            },
          }
        ],
      };

      if (!await _mapboxMapController!.style.styleSourceExists(_puckSourceId)) {
        await _mapboxMapController!.style.addSource(
          mp.GeoJsonSource(
            id: _puckSourceId,
            data: jsonEncode(initialGeoJson),
          ),
        );
      }

      // 2. Add Symbol Layer with Smooth Scaling Expression
      if (!await _mapboxMapController!.style.styleLayerExists(_puckLayerId)) {
        await _mapboxMapController!.style.addLayer(
          mp.SymbolLayer(
            id: _puckLayerId,
            sourceId: _puckSourceId,
            iconImage: 'navigation-puck',
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconRotationAlignment: mp.IconRotationAlignment.MAP,
            iconPitchAlignment: mp.IconPitchAlignment.MAP, // Lie flat on the road
            iconRotateExpression: ['get', 'bearing'], // Rotate based on bearing property
            // Fixed size matching non-navigation mode
            iconSizeExpression: [
              'interpolate',
              ['linear'],
              ['zoom'],
              10.0, 1.0,
              22.0, 1.0,
            ],
            symbolSortKey: 1000, // Ensure on top
          ),
        );
      }

      debugPrint('✅ Custom navigation puck created with SymbolLayer (smooth scaling)');
      
      // Ensure puck is on top of route
      await _ensureNavigationPuckOnTop();
    } catch (e) {
      debugPrint('❌ Error creating navigation puck: $e');
    }
  }

  /// Update the puck source data
  Future<void> _updatePuckSource(mp.Position position, double bearing) async {
    if (_mapboxMapController == null) return;

    try {
      final geoJson = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [position.lng, position.lat],
            },
            'properties': {
              'bearing': bearing,
            },
          }
        ],
      };

      await _mapboxMapController!.style.setStyleSourceProperty(
        _puckSourceId,
        'data',
        jsonEncode(geoJson),
      );
    } catch (e) {
      // Ignore updates if source doesn't exist yet
    }
  }

  /// Ensure the navigation puck layer is above the route layer
  Future<void> _ensureNavigationPuckOnTop() async {
    if (_mapboxMapController == null) return;

    try {
      if (await _mapboxMapController!.style.styleLayerExists(_puckLayerId)) {
        await _mapboxMapController!.style.moveStyleLayer(_puckLayerId, null); // Move to very top
        debugPrint('✅ Moved navigation puck layer ($_puckLayerId) to top');
      }
    } catch (e) {
      debugPrint('⚠️ Error moving navigation puck layer: $e');
    }
  }

  /// Update the custom navigation puck position and rotation with smoothing
  void _updateNavigationPuck(Position position) {
    if (_mapboxMapController == null) return;

    try {
      final newLat = position.latitude;
      final newLng = position.longitude;
      final newBearing = position.heading;

      // If we have an animation controller, animate to the new position
      if (_puckAnimationController != null) {
        final startLat = _lastPuckPosition?.lat.toDouble() ?? newLat;
        final startLng = _lastPuckPosition?.lng.toDouble() ?? newLng;
        final startBearing = _lastPuckBearing ?? newBearing;

        // Handle bearing wrap-around (e.g. 350 -> 10 degrees)
        double targetBearing = newBearing;
        if ((targetBearing - startBearing).abs() > 180) {
          if (targetBearing > startBearing) {
            targetBearing -= 360;
          } else {
            targetBearing += 360;
          }
        }

        _latAnimation = Tween<double>(begin: startLat, end: newLat).animate(_puckAnimationController!);
        _lngAnimation = Tween<double>(begin: startLng, end: newLng).animate(_puckAnimationController!);
        _bearingAnimation = Tween<double>(begin: startBearing, end: targetBearing).animate(_puckAnimationController!);

        _puckAnimationController!.forward(from: 0.0);
        
        // Update last known state
        _lastPuckPosition = mp.Position(newLng, newLat);
        _lastPuckBearing = newBearing;
      } else {
        // Fallback to immediate update if no animation controller
        _updatePuckSource(mp.Position(newLng, newLat), newBearing);
      }
    } catch (e) {
      debugPrint('Error updating navigation puck: $e');
    }
  }

  // Removed: Old drawPolyline method - now using professional LineLayer approach

  /// Draw route using advanced RouteVisualizationService
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

      // Use RouteVisualizationService to draw the route
      await _routeVisualizationService.drawRoute(route);

      // Update SnapToRoadService with the new route
      _snapToRoadService.setMapboxRoute(route);

      // Add route markers using existing functionality
      await _addRouteMarkers(routePoints);

      // Fit camera to route bounds
      await _fitCameraToRoute(routePoints);

      debugPrint('Advanced route visualization created successfully');
    } catch (e) {
      debugPrint('Error creating route visualization: $e');
      // Could implement user notification here
    }
  }

  /// Update route progress during navigation
  Future<void> updateRouteProgress(MapboxRoute route, int currentStepIndex, {Position? currentPosition}) async {
    if (_mapboxMapController == null) return;

    try {
      await _routeVisualizationService.updateRouteProgress(
        route,
        currentStepIndex,
        currentPosition: currentPosition,
      );
    } catch (e) {
      debugPrint('Error updating route progress: $e');
    }
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
        iconSize: markerSize * 0.6, // Destination marker reduced size
        iconImage: 'destination-marker', // Reference the added image by ID
      ),
    );

    // Ensure markers are on top of route line
    try {
      final layerId = pointAnnotationManager!.id;
      await _mapboxMapController!.style.moveStyleLayer(layerId, null); // Move to top
      debugPrint('✅ Moved route markers layer ($layerId) to top');
      
      // Ensure navigation puck is even higher if it exists
      await _ensureNavigationPuckOnTop();
    } catch (e) {
      debugPrint('⚠️ Error moving marker layer: $e');
    }
  }

  Future<void> clearRoutePolyline() async {
    // Clear route using RouteVisualizationService
    await _routeVisualizationService.clearRoute();

    // Clear route in SnapToRoadService
    _snapToRoadService.clearRoute();

    // Clear route markers
    await pointAnnotationManager?.deleteAll();

    // Clear stored polyline data
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


  Future<void> _fitCameraToRoute(List<PointLatLng> points) async {
    // Use camera controller for route fitting
    await _cameraController.fitToRoute(points);
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

    // Refresh location puck now that we have permissions (fixes iOS startup issue)
    if (_mapboxMapController != null) {
      await _setupLocationPuck();
    }

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

        // Update map camera if following user using camera controller
        if (_mapboxMapController != null && _cameraController.isFollowingUser) {
          updateMapCamera(processedPosition);
        }

        // Update custom navigation puck if in navigation mode
        if (currentState is NavigationInProgress) {
          _updateNavigationPuck(processedPosition);
        }
      },
      onError: (Object error) {
        debugPrint('Position stream error: $error');
      },
    );
  }

  void updateMapCamera(Position position) {
    if (_mapboxMapController == null) return;

    final currentState = navigationBloc.state;
    final isOverviewMode = currentState is NavigationInProgress && currentState.isOverviewVisible;

    // Use camera controller for all camera updates
    _cameraController.updateCamera(
      userPosition: position,
      userBearing: position.heading >= 0 ? position.heading : null,
      isOverviewMode: isOverviewMode,
    );

    // Update report icons after camera change
    _debouncedUpdateReportIconSizes();
  }

  // Removed: _actuallyUpdateCamera - now handled by CameraController

  /// Setup map event listeners for adaptive polyline and marker updates
  void _setupMapListeners() {
    // Note: Mapbox Flutter SDK might not have direct camera change listeners
    // The polyline width and marker sizes will update automatically during our camera animations
    // and can be manually triggered when needed via debounced functions
  }


  /// Debounced report icon size update to prevent excessive recreations
  void _debouncedUpdateReportIconSizes() {
    _reportIconUpdateTimer?.cancel();
    _reportIconUpdateTimer = Timer(const Duration(milliseconds: 100), () {
      // _updateReportIconSizes(); // No longer needed with clustering layers
      // _updatePuckSize(); // No longer needed with SymbolLayer expressions
    });
  }

  /// Update navigation puck size based on zoom level
  // Future<void> _updatePuckSize() async {
  //   // Removed: Handled by SymbolLayer expression
  // }

  // Removed _updateReportIconSizes as layer handles sizing
  // Future<void> _updateReportIconSizes() async { ... }


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

      // Use camera controller for navigation zoom
      await _cameraController.forceNavigationZoom(currentPosition);

      // No need to update polyline width - RouteVisualizationService handles this automatically
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
    _puckAnimationController?.dispose();
    _userPositionStream?.cancel();
    _reportIconUpdateTimer?.cancel();
    // reportAnnotationManager?.deleteAll(); // Removed
    _cameraController.dispose(); // Clean up camera controller
    _routeVisualizationService.dispose(); // Clean up route visualization service
    _mapboxMapController?.dispose();
    super.dispose();
  }
}

/// Custom BytesLoader for in-memory ByteData
class MemoryBytesLoader extends vg.BytesLoader {
  final ByteData _data;
  const MemoryBytesLoader(this._data);

  @override
  Future<ByteData> loadBytes(BuildContext? context) async => _data;

  @override
  int get hashCode => _data.hashCode;

  @override
  bool operator ==(Object other) => other is MemoryBytesLoader && other._data == _data;
}
