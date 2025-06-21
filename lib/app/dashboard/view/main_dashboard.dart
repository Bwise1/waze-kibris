import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:sheet/sheet.dart';
import 'package:waze_kibris/common.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<StatefulWidget> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with TickerProviderStateMixin {
  late SheetController controller;
  mp.MapboxMap? _mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
    controller = SheetController();
  }

  @override
  void dispose() {
    _userPositionStream?.cancel();
    _mapboxMapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(mp.MapboxMap controller) {
    setState(() {
      _mapboxMapController = controller;
    });

    // Enable gestures and location component
    _mapboxMapController?.gestures
        .updateSettings(mp.GesturesSettings(pinchToZoomEnabled: true));
    _mapboxMapController?.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        puckBearingEnabled: true,

        // puckBearingSource: mp.PuckBearingSource.HEADING, // Or COURSE
        pulsingEnabled: true,
      ),
    );
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Consider showing a dialog to the user to enable location services
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Handle the case where the user denies permission
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Handle the case where permissions are permanently denied
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Settings for the position stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    // Cancel any existing stream
    _userPositionStream?.cancel();

    // Listen to the user's position stream
    _userPositionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null && _mapboxMapController != null) {
          // Center the map on the user's location and update the bearing
          _mapboxMapController?.setCamera(
            mp.CameraOptions(
              center: mp.Point(
                coordinates: mp.Position(
                  position.longitude,
                  position.latitude,
                ),
              ),
              zoom: 16.0, // A closer zoom level
              bearing: position
                  .heading, // Set the map's bearing to the user's heading
            ),
          );
        }
      },
      onError: (error) {
        // Handle stream errors, e.g., location services are turned off
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          mp.MapWidget(
            key: const ValueKey('mapWidget'),
            onMapCreated: _onMapCreated,
          ),
          FloatingButtons(controller: controller)
        ],
      ),
    );
  }
}

class FloatingButtons extends StatelessWidget {
  const FloatingButtons({required this.controller, super.key});
  final SheetController controller;
  @override
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height =
        mediaQuery.size.height - mediaQuery.padding.top - kToolbarHeight;
    return AnimatedBuilder(
      animation: controller.animation,
      builder: (BuildContext context, Widget? child) {
        return Positioned(
          right: 0,
          left: 0,
          bottom: height * min(0.3, controller.animation.value),
          child: Container(
            margin: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  height: 65,
                  width: 45,
                  decoration: BoxDecoration(
                    color: styles.theme.grey,
                    borderRadius: BorderRadius.circular(styles.corners.sm),
                    boxShadow: styles.shadows.md,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '0',
                        style: styles.typography.h2
                            .textColor(styles.theme.white)
                            .semi,
                      ),
                      Text(
                        'km/h',
                        style: styles.typography.t3
                            .textColor(styles.theme.white)
                            .semi,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IconBtn(
                  icon: Assets.icons.coordinate,
                  semanticLabel: 'My location',
                  color: styles.theme.white,
                  onPressed: () {
                    controller.relativeAnimateTo(
                      0.1,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeIn,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
