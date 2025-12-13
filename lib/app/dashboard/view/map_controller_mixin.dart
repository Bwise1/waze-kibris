import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/gen/assets.gen.dart';
import 'package:waze_kibris/app/dashboard/services/snap_to_road_service.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/core/controllers/camera_controller.dart';
import 'package:waze_kibris/core/services/route_visualization_service.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/app/dashboard/modals/report_details_modal.dart';

mixin MapControllerMixin<T extends StatefulWidget> on State<T> {
  mp.MapboxMap? _mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;
  mp.PointAnnotationManager? pointAnnotationManager;
  mp.PointAnnotationManager? reportAnnotationManager;
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

  // Map to track annotation ID to report ID mapping
  final Map<String, int> _annotationToReportMap = {};

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

  void onMapCreated(mp.MapboxMap controller) async {
    setState(() {
      _mapboxMapController = controller;
    });

    // Initialize camera controller with map
    _cameraController.initialize(controller);

    // Initialize route visualization service with map (await it)
    await _initializeRouteVisualization(controller);
    
    // Add report icons to style
    await _addReportIconsToStyle();

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

      // Add tap listener for report annotations
      manager.tapEvents(onTap: _onReportAnnotationTap);
    });

    // Setup navigation puck manager - REMOVED
    // _mapboxMapController?.annotations
    //     .createPointAnnotationManager()
    //     .then((manager) {
    //   setState(() {
    //     navigationPuckManager = manager;
    //   });
    // });

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
    // Setup report icons - moved to onMapCreated via _addReportIconsToStyle

    // Initialize clustering
    _setupReportClustering();
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

  /// Display reports using PointAnnotations with click handling and smart positioning
  Future<void> displayReportsOnMap(List<ReportData> reports) async {
    if (reportAnnotationManager == null || !mounted) return;

    try {
      _currentReports = reports;

      // Clear existing report annotations and mapping
      await reportAnnotationManager!.deleteAll();
      _annotationToReportMap.clear();

      // Get current zoom level for smart clustering
      final cameraState = await _mapboxMapController?.getCameraState();
      final zoom = cameraState?.zoom ?? 14.0;

      // Group reports by proximity (Waze-style clustering)
      final clusters = _clusterReports(reports, zoom);

      // Create annotations for each cluster
      for (final cluster in clusters) {
        final iconId = _getReportIcon(cluster.reports.first.type);

        // Calculate offset for overlapping reports
        final offset = cluster.offset;

        final annotation = await reportAnnotationManager!.create(
          mp.PointAnnotationOptions(
            geometry: mp.Point(
              coordinates: mp.Position(
                cluster.longitude,
                cluster.latitude,
              ),
            ),
            iconImage: iconId,
            iconSize: 0.7,
            iconAnchor: mp.IconAnchor.BOTTOM,
            iconOffset: offset,
          ),
        );

        // Map annotation ID to the first (or most important) report in cluster
        _annotationToReportMap[annotation.id] = cluster.reports.first.id;
      }

      debugPrint('✅ Displayed ${clusters.length} report annotations (${reports.length} reports total)');
    } catch (e) {
      debugPrint('❌ Error displaying reports on map: $e');
    }
  }

  /// Cluster nearby reports to prevent overlap (Waze-style)
  List<_ReportCluster> _clusterReports(List<ReportData> reports, double zoom) {
    final clusters = <_ReportCluster>[];
    final processed = <int>{};

    // Distance threshold based on zoom level (in degrees, ~meters)
    // At zoom 14: ~50m, zoom 16: ~20m, zoom 18: ~5m
    final threshold = 0.0005 / math.pow(2, zoom - 14);

    for (var i = 0; i < reports.length; i++) {
      if (processed.contains(i)) continue;

      final report = reports[i];
      final nearbyReports = <ReportData>[report];
      processed.add(i);

      // Find nearby reports
      for (var j = i + 1; j < reports.length; j++) {
        if (processed.contains(j)) continue;

        final other = reports[j];
        final distance = _calculateReportDistance(report, other);

        if (distance < threshold) {
          nearbyReports.add(other);
          processed.add(j);
        }
      }

      // Create cluster with offset for overlapping reports
      if (nearbyReports.length == 1) {
        // Single report - no offset
        clusters.add(_ReportCluster(
          reports: nearbyReports,
          latitude: report.latitude,
          longitude: report.longitude,
          offset: [0, 0],
        ));
      } else {
        // Multiple reports at same location - create fan pattern
        for (var k = 0; k < nearbyReports.length; k++) {
          final angle = (k * 360 / nearbyReports.length) * (math.pi / 180);
          final radius = zoom > 15 ? 25.0 : 20.0; // Wider offset for better separation

          clusters.add(_ReportCluster(
            reports: [nearbyReports[k]],
            latitude: nearbyReports[k].latitude,
            longitude: nearbyReports[k].longitude,
            offset: [
              radius * math.cos(angle),
              -radius * math.sin(angle),
            ],
          ));
        }
      }
    }

    return clusters;
  }

  /// Calculate distance between two reports in degrees
  double _calculateReportDistance(ReportData a, ReportData b) {
    final dx = a.longitude - b.longitude;
    final dy = a.latitude - b.latitude;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Handle tap on report annotation
  void _onReportAnnotationTap(mp.PointAnnotation annotation) {
    try {
      // Get report ID from mapping
      final reportId = _annotationToReportMap[annotation.id];
      if (reportId == null) {
        debugPrint('⚠️ No report found for annotation ${annotation.id}');
        return;
      }

      debugPrint('👆 Tapped on report: $reportId');

      // Find the full report data
      final report = _currentReports.firstWhere(
        (r) => r.id == reportId,
        orElse: () {
          debugPrint('⚠️ Report $reportId not found in current reports');
          return _currentReports.first;
        },
      );

      // Show details modal from TOP (Waze-style)
      if (mounted) {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black.withOpacity(0.3),
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) {
            return Align(
              alignment: Alignment.topCenter,
              child: ReportDetailsModal(report: report),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -1), // Start from above the screen
                end: Offset.zero, // Slide down to position
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              )),
              child: child,
            );
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling report tap: $e');
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

  /// Handle map tap events - delegates to layer-specific tap interactions
  void onMapTap(mp.MapContentGestureContext context) async {
    // This is now handled by TapInteraction added in _setupReportClustering
    // Keep this method for potential future use or non-report taps
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
    if (_mapboxMapController == null || !mounted) return;

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
      
      if (!mounted || _mapboxMapController == null) return;

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

  /// Load and add report icons to map style
  Future<void> _addReportIconsToStyle() async {
    if (_mapboxMapController == null || !mounted) return;

    try {
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      
      // Map of icon IDs to IconData and Color
      final icons = {
        'police-icon': (Icons.local_police, Colors.blue),
        'traffic-icon': (Icons.traffic, Colors.red),
        'accident-icon': (Icons.car_crash, Colors.orange),
      };

      for (final entry in icons.entries) {
        final iconId = entry.key;
        final iconData = entry.value.$1;
        final color = entry.value.$2;

        try {
          // Generate icon image
          final image = await _generateReportIcon(iconData, color);
          
          if (image == null) continue;

          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) continue;
          
          final imageBytes = byteData.buffer.asUint8List();

          final mbxImage = mp.MbxImage(
            width: image.width,
            height: image.height,
            data: imageBytes,
          );

          if (!mounted || _mapboxMapController == null) return;

          await _mapboxMapController!.style.addStyleImage(
            iconId,
            devicePixelRatio,
            mbxImage,
            false,
            [],
            [],
            null,
          );
          debugPrint('✅ Added $iconId to map style');
        } catch (e) {
          debugPrint('❌ Error adding $iconId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error adding report icons to style: $e');
    }
  }

  /// Helper to generate report icon using Canvas
  Future<ui.Image?> _generateReportIcon(IconData icon, Color color, {Size size = const Size(64, 64)}) async {
    try {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      
      final int width = (size.width * devicePixelRatio).toInt();
      final int height = (size.height * devicePixelRatio).toInt();
      
      // Scale canvas
      canvas.scale(devicePixelRatio);
      
      final double centerX = size.width / 2;
      final double centerY = size.height / 2;
      final double radius = size.width / 2;

      // Draw background circle
      final ui.Paint paint = ui.Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      // Draw shadow
      canvas.drawCircle(
        Offset(centerX, centerY + 2), 
        radius - 2, 
        ui.Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Draw white circle
      canvas.drawCircle(Offset(centerX, centerY), radius - 4, paint);
      
      // Draw colored circle
      paint.color = color.withOpacity(0.1);
      canvas.drawCircle(Offset(centerX, centerY), radius - 4, paint);

      // Draw Icon
      final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      textPainter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size.width * 0.6,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, centerY - textPainter.height / 2),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(width, height);
      
      return image;
    } catch (e) {
      debugPrint('Error generating report icon: $e');
      return null;
    }
  }

  /// Refresh location puck to ensure it stays on top of route layers
  void _refreshLocationPuckOnTop() {
    if (_mapboxMapController == null || !mounted) return;
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
    if (_mapboxMapController == null || !mounted) return;
    try {
      final locationPuckBytes = await _loadLocationPuckImage();
      
      if (!mounted || _mapboxMapController == null) return;

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
      if (mounted && _mapboxMapController != null) {
        await _mapboxMapController?.location.updateSettings(
          mp.LocationComponentSettings(
            enabled: true,
            puckBearingEnabled: true,
            puckBearing: mp.PuckBearing.COURSE,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _puckAnimationController?.dispose();
    _userPositionStream?.cancel();
    _reportIconUpdateTimer?.cancel();
    reportAnnotationManager?.deleteAll();
    _cameraController.dispose(); // Clean up camera controller
    _routeVisualizationService.dispose(); // Clean up route visualization service
    // _mapboxMapController?.dispose(); // REMOVED: Managed by MapWidget
    super.dispose();
  }
}

/// Helper class for report clustering
class _ReportCluster {
  final List<ReportData> reports;
  final double latitude;
  final double longitude;
  final List<double> offset;

  _ReportCluster({
    required this.reports,
    required this.latitude,
    required this.longitude,
    required this.offset,
  });
}


