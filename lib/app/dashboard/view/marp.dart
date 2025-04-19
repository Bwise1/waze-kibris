import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';

class MapScreen extends StatefulWidget {
  static const String routeName = '/map';
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? mapController;
  bool _isMapReady = false;
  bool _isLocating = false;
  LatLng? _currentLocation;
  final double _initialZoom = 15.0; // Zoom level similar to Waze
  String stadiaApiKey = '8a83c0b9-fbe3-4caa-98d5-d8b60efc67c5';
//
  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    final PermissionStatus status =
        await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      // Handle case when permission is denied
      _showLocationPermissionDialog();
    }
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });

      // Animate to user location if map is already loaded
      if (_isMapReady && mapController != null && _currentLocation != null) {
        _animateToUserLocation();
      }
    } catch (e) {
      setState(() {
        _isLocating = false;
      });
      print('Error getting location: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get your location')),
      );
    }
  }

  // Animate camera to user's location
  void _animateToUserLocation() {
    if (_currentLocation != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: _initialZoom,
          ),
        ),
      );

      // Add a marker at the user's location
      mapController!.addSymbol(
        SymbolOptions(
          geometry: _currentLocation,
          iconImage:
              'assets/user_location_marker.png', // Custom marker image - add this to your assets
          iconSize: 1.5,
        ),
      );
    }
  }

  // Show dialog when location permission is denied
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Required'),
          content: Text(
              'This app needs location permission to show your position on the map. Please grant permission in app settings.'),
          actions: <Widget>[
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
    setState(() {
      _isMapReady = true;
    });

    // If we already have the location by the time map is created, animate to it
    if (_currentLocation != null) {
      _animateToUserLocation();
    }

    // Enable user location tracking on the map
    mapController!
        .updateMyLocationTrackingMode(MyLocationTrackingMode.trackingGps);
  }

  @override
  Widget build(BuildContext context) {
    // Default location (will be replaced with user's location once obtained)
    final LatLng defaultLocation = LatLng(37.7749, -122.4194); // San Francisco

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Location Map'),
      ),
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? defaultLocation,
              zoom: _initialZoom,
            ),
            styleString:
                'https://tiles-eu.stadiamaps.com/styles/outdoors.json?api_key=$stadiaApiKey',
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
            myLocationRenderMode: MyLocationRenderMode.compass,
          ),
          if (_isLocating)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
