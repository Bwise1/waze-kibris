import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/services/snap_to_road_service.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';

mixin MapControllerMixin<T extends StatefulWidget> on State<T> {
  mp.MapboxMap? _mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;
  mp.PolylineAnnotationManager? polylineAnnotationManager;
  mp.PointAnnotationManager? pointAnnotationManager;

  // Camera tracking variables
  bool _isFollowingUser = true;
  Timer? _cameraResetTimer;
  Timer? _cameraUpdateTimer;
  Position? _lastCameraPosition;

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

    // Add start marker
    await pointAnnotationManager!.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(
            coordinates: mp.Position(
          points.first.longitude,
          points.first.latitude,
        )),
        iconSize: 1.0, // 32px - optimal visibility for start marker
      ),
    );

    // Add end marker
    await pointAnnotationManager!.create(
      mp.PointAnnotationOptions(
        geometry: mp.Point(
            coordinates: mp.Position(
          points.last.longitude,
          points.last.latitude,
        )),
        iconSize: 1.2, // 36px - slightly larger for destination emphasis
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

  /// Calculate adaptive line width based on zoom level (Waze-style with limits)
  Future<double> _getAdaptiveLineWidth() async {
    if (_mapboxMapController == null) return 8.0;

    try {
      final cameraState = await _mapboxMapController!.getCameraState();
      final zoom = cameraState.zoom;
      final currentState = navigationBloc.state;
      final isNavigating = currentState is NavigationInProgress;

      // Waze-style adaptive width with realistic road width limits
      double baseWidth;

      if (zoom >= 19) {
        // Maximum detail - fill most of road width but not excessive
        baseWidth = isNavigating ? 16.0 : 12.0;
      } else if (zoom >= 18) {
        // Very close zoom - prominent but controlled
        baseWidth = isNavigating ? 14.0 : 10.0;
      } else if (zoom >= 17) {
        // Close zoom - good visibility
        baseWidth = isNavigating ? 12.0 : 8.0;
      } else if (zoom >= 16) {
        // Medium-close zoom - standard navigation width
        baseWidth = isNavigating ? 10.0 : 7.0;
      } else if (zoom >= 15) {
        // Medium zoom - balanced
        baseWidth = isNavigating ? 8.0 : 6.0;
      } else if (zoom >= 14) {
        // Medium-far zoom - visible but not dominant
        baseWidth = isNavigating ? 6.0 : 4.0;
      } else if (zoom >= 12) {
        // Far zoom - much thinner
        baseWidth = isNavigating ? 4.0 : 3.0;
      } else if (zoom >= 10) {
        // Very far zoom - very thin
        baseWidth = isNavigating ? 3.0 : 2.0;
      } else if (zoom >= 8) {
        // Overview level - minimal thickness
        baseWidth = isNavigating ? 2.0 : 1.5;
      } else {
        // Maximum zoom out - extremely thin
        baseWidth = isNavigating ? 1.5 : 1.0;
      }

      // Apply maximum width limit to prevent overly thick lines
      const double maxWidth = 18.0; // Prevents polyline from being too wide
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
        mp.MapAnimationOptions(duration: 800),
      )
          .then((_) {
        // Update polyline width after camera change
        _updatePolylineWidth();
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
        mp.MapAnimationOptions(duration: 800),
      )
          .then((_) {
        // Update polyline width after camera change
        _updatePolylineWidth();
      });
    } else {
      // Normal browsing mode: flat top-down view
      _mapboxMapController
          ?.easeTo(
        mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
          zoom: 16.0,
          bearing: 0.0,
          pitch: 0.0,
        ),
        mp.MapAnimationOptions(duration: 800),
      )
          .then((_) {
        // Update polyline width after camera change
        _updatePolylineWidth();
      });
    }
  }

  /// Setup map event listeners for adaptive polyline updates
  void _setupMapListeners() {
    // Note: Mapbox Flutter SDK might not have direct camera change listeners
    // The polyline width will update automatically during our camera animations
    // and can be manually triggered when needed
  }

  /// Update polyline width based on current zoom level
  void _updatePolylineWidth() async {
    if (polylineAnnotationManager == null || _currentPolylinePoints == null)
      return;

    try {
      // Calculate new width
      final newWidth = await _getAdaptiveLineWidth();

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

        // Note: Skip recreating markers during width updates to reduce flicker
      }
    } catch (e) {
      debugPrint('Error updating polyline width: $e');
    }
  }

  /// Manually trigger polyline width update (can be called when user manually zooms)
  void updatePolylineWidthForZoom() {
    _updatePolylineWidth();
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

  /// Load location puck image from assets
  Future<Uint8List> _loadLocationPuckImage() async {
    final ByteData byteData =
        await rootBundle.load('assets/icons/CurrentPosition.png');
    return byteData.buffer.asUint8List();
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
              0.6,
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
    _mapboxMapController?.dispose();
    super.dispose();
  }
}
