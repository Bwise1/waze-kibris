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
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';
import 'package:waze_kibris/gen/assets.gen.dart';

mixin MapControllerMixin<T extends StatefulWidget> on State<T> {
  mp.MapboxMap? _mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;
  mp.PolylineAnnotationManager? polylineAnnotationManager;
  mp.PointAnnotationManager? pointAnnotationManager;

  // Camera tracking variables
  bool _isFollowingUser = true;
  Timer? _cameraResetTimer;
  Timer? _cameraUpdateTimer;
  Timer? _polylineUpdateTimer;
  Position? _lastCameraPosition;
  double _lastPolylineWidth = 0.0;

  // Track current polyline for adaptive width updates
  String? _currentPolylineEncodedString;
  List<PointLatLng>? _currentPolylinePoints;

  // Snap to road service
  final SnapToRoadService _snapToRoadService = SnapToRoadService();

  // Getters for subclasses
  mp.MapboxMap? get mapboxMapController => _mapboxMapController;
  bool get isFollowingUser => _isFollowingUser;

  // Navigation bloc must be provided by the implementing class
  NavigationBloc get navigationBloc;

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
        .createPolylineAnnotationManager()
        .then((manager) {
      setState(() {
        polylineAnnotationManager = manager;
      });
    });

    _mapboxMapController?.annotations
        .createPointAnnotationManager()
        .then((manager) {
      setState(() {
        pointAnnotationManager = manager;
      });
    });

    // Configure map settings
    _mapboxMapController?.gestures.updateSettings(mp.GesturesSettings(
      pinchToZoomEnabled: true,
      rotateEnabled: true,
      scrollEnabled: true,
    ));

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

  Future<void> drawPolyline(String encodedPolyline) async {
    await clearRoutePolyline();

    if (polylineAnnotationManager == null || _mapboxMapController == null) {
      debugPrint('Polyline manager or map controller not ready.');
      return;
    }

    final polylinePoints = PolylinePoints();
    final List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);

    if (decodedPoints.isEmpty) {
      debugPrint('Decoded polyline has no points.');
      return;
    }

    // Store polyline data for adaptive width updates
    _currentPolylineEncodedString = encodedPolyline;
    _currentPolylinePoints = decodedPoints;

    // Apply Waze-style smoothing to the polyline points
    final smoothedPoints = _smoothPolylinePoints(decodedPoints);

    final List<mp.Position> geometry = smoothedPoints
        .map((p) => mp.Position(p.longitude, p.latitude))
        .toList();

    // Get adaptive line width based on current zoom level
    final adaptiveWidth = await _getAdaptiveLineWidth();

    // Create main route polyline with Waze-style properties
    await polylineAnnotationManager!.create(
      mp.PolylineAnnotationOptions(
        geometry: mp.LineString(coordinates: geometry),
        lineColor: 0xFFFF0000, // Keep original red color
        lineWidth: adaptiveWidth,
        lineOpacity: 0.9, // Higher opacity for better visibility
        lineJoin: mp.LineJoin.ROUND, // Smooth rounded joins at turns
        // lineCap: mp.LineCap.ROUND,   // Rounded end caps
        lineBlur: 0.5, // Subtle blur for smoother appearance
      ),
    );

    // Add route border/outline for better road definition (like Waze)
    await polylineAnnotationManager!.create(
      mp.PolylineAnnotationOptions(
        geometry: mp.LineString(coordinates: geometry),
        lineColor: 0xFFCC0000, // Darker red border
        lineWidth: adaptiveWidth + 2.0, // Slightly wider for border effect
        lineOpacity: 0.6,
        lineJoin: mp.LineJoin.ROUND,
        //  lineCap: mp.LineCap.ROUND,
      ),
    );

    // Add route markers
    await _addRouteMarkers(decodedPoints);

    // Fit camera to route bounds
    await _fitCameraToRoute(decodedPoints);
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
    await polylineAnnotationManager?.deleteAll();
    await pointAnnotationManager?.deleteAll();

    // Clear stored polyline data
    _currentPolylineEncodedString = null;
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
      distanceFilter: 3, // More frequent updates for real-time banner updates
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
      (Position position) {
        // Apply snap-to-road during navigation
        final currentState = navigationBloc.state;
        Position processedPosition = position;

        if (currentState is NavigationInProgress) {
          final snapResult = _snapToRoadService.snapToRoad(position);

          // Create new position with snapped coordinates and route bearing
          processedPosition = Position(
            latitude: snapResult.snappedPosition.latitude,
            longitude: snapResult.snappedPosition.longitude,
            timestamp: position.timestamp,
            accuracy: position.accuracy,
            altitude: position.altitude,
            altitudeAccuracy: position.altitudeAccuracy,
            heading:
                snapResult.bearing, // Use route bearing instead of GPS heading
            headingAccuracy: position.headingAccuracy,
            speed: position.speed,
            speedAccuracy: position.speedAccuracy,
          );

          // Check if user is off route
          if (snapResult.isOffRoute) {
            debugPrint(
                'User is off route - distance: ${snapResult.distanceFromRoute}m');
            // You can trigger rerouting here
          }
        }

        // Send processed position to navigation bloc
        navigationBloc
            .add(NavigationPositionUpdated(position: processedPosition));

        // Update map camera if following user
        if (_mapboxMapController != null && _isFollowingUser) {
          updateMapCamera(processedPosition);
        }
      },
      onError: (error) {
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
          zoom: 18.0,
          bearing: position.heading, // Follow user's heading direction
          pitch: 0.0, // Flat view like Waze, no 3D tilt
        ),
        mp.MapAnimationOptions(duration: 1500),
      )
          .then((_) {
        // Update polyline width after camera change (debounced)
        _debouncedUpdatePolylineWidth();
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

  /// Setup map event listeners for adaptive polyline updates
  void _setupMapListeners() {
    // Note: Mapbox Flutter SDK might not have direct camera change listeners
    // The polyline width will update automatically during our camera animations
    // and can be manually triggered when needed
  }

  /// Debounced polyline width update to prevent excessive recreations
  void _debouncedUpdatePolylineWidth() {
    _polylineUpdateTimer?.cancel();
    _polylineUpdateTimer = Timer(const Duration(milliseconds: 50), () {
      _updatePolylineWidth();
    });
  }

  /// Update polyline width based on current zoom level
  void _updatePolylineWidth() async {
    if (polylineAnnotationManager == null || _currentPolylinePoints == null)
      return;

    try {
      // Calculate new width
      final newWidth = await _getAdaptiveLineWidth();

      // Only update if width actually changed significantly
      if ((newWidth - _lastPolylineWidth).abs() < 1.0) {
        return; // Skip update if width change is minimal
      }

      // Only update if we have polyline data stored
      if (_currentPolylinePoints != null &&
          _currentPolylinePoints!.isNotEmpty) {
        // Clear existing polylines quickly
        await polylineAnnotationManager!.deleteAll();

        // Apply smoothing to stored points
        final smoothedPoints = _smoothPolylinePoints(_currentPolylinePoints!);
        final List<mp.Position> geometry = smoothedPoints
            .map((p) => mp.Position(p.longitude, p.latitude))
            .toList();

        // Recreate main polyline with new width
        await polylineAnnotationManager!.create(
          mp.PolylineAnnotationOptions(
            geometry: mp.LineString(coordinates: geometry),
            lineColor: 0xFFFF0000, // Keep original red color
            lineWidth: newWidth,
            lineOpacity: 0.9,
            lineJoin: mp.LineJoin.ROUND,
            // lineCap: mp.LineCap.ROUND,
            lineBlur: 0.5,
          ),
        );

        // Recreate border polyline with new width
        await polylineAnnotationManager!.create(
          mp.PolylineAnnotationOptions(
            geometry: mp.LineString(coordinates: geometry),
            lineColor: 0xFFCC0000, // Darker red border
            lineWidth: newWidth + 2.0,
            lineOpacity: 0.6,
            lineJoin: mp.LineJoin.ROUND,
            // lineCap: mp.LineCap.ROUND,
          ),
        );

        // Update markers with adaptive sizing
        await _updateMarkersForZoom();

        // Update last width to prevent unnecessary future updates
        _lastPolylineWidth = newWidth;
      }
    } catch (e) {
      debugPrint('Error updating polyline width: $e');
    }
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

  /// Manually trigger polyline width update (can be called when user manually zooms)
  void updatePolylineWidthForZoom() {
    _updatePolylineWidth();
  }

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
          zoom: 18.0, // Navigation zoom level
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
  void initializeSnapToRoad(DirectionsRoute route) {
    debugPrint('Initializing snap-to-road with route');
    _snapToRoadService.setRoute(route);
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

  /// Setup location puck with custom image
  Future<void> _setupLocationPuck() async {
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
        pulsingColor: 0xFFFF0000,
        pulsingEnabled: true,
        showAccuracyRing: false,
      ),
    );
  }

  @override
  void dispose() {
    _userPositionStream?.cancel();
    _cameraResetTimer?.cancel();
    _cameraUpdateTimer?.cancel();
    _polylineUpdateTimer?.cancel();
    _mapboxMapController?.dispose();
    super.dispose();
  }
}
