import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

// --- Configuration ---
const String yourBackendBaseUrl = "http://valhalla.benjys.me";
const LatLng startPoint = LatLng(35.2049704, 33.317932);
const LatLng endPoint = LatLng(35.221906, 33.417018);
const double assumedAverageSpeed = 50.0; // km/h for ETA calculation

// void main() => runApp(MyApp());
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Navigation Demo',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: MapScreen(),
//     );
//   }
// }

class PolyLineMapScreen extends StatefulWidget {
  static const String routeName = '/map';
  @override
  _PolyLineMapScreenState createState() => _PolyLineMapScreenState();
}

class _PolyLineMapScreenState extends State<PolyLineMapScreen> {
  final MapController _mapController = MapController();
  final Location _locationService = Location();
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _maneuvers = [];
  LatLng? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  String _eta = '';

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    final serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled && !await _locationService.requestService()) return;

    PermissionStatus permission = await _locationService.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _locationService.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    _locationService.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        setState(() {
          _currentPosition = LatLng(
            currentLocation.latitude!,
            currentLocation.longitude!,
          );
        });
      }
    });
  }

  Future<void> _fetchAndDisplayRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _routePoints = [];
      _maneuvers = [];
    });

    try {
      final response = await http.post(
        Uri.parse('$yourBackendBaseUrl/route'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'locations': [
            {'lat': startPoint.latitude, 'lon': startPoint.longitude},
            {'lat': endPoint.latitude, 'lon': endPoint.longitude},
          ],
          'costing': 'auto',
          'units': 'kilometers',
          'directions_options': {'narrative': true},
        }),
      );

      if (response.statusCode == 200) {
        _parseValhallaResponse(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _eta = _calculateETA(assumedAverageSpeed);
      } else {
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _parseValhallaResponse(Map<String, dynamic> responseData) {
    final trip = responseData['trip'];
    final legs = trip['legs'] as List<dynamic>;

    legs.forEach((leg) {
      final encodedPolyline = leg['shape'];
      _routePoints.addAll(decodeValhallaPolyline("$encodedPolyline"));

      (leg['maneuvers'] as List<dynamic>).forEach((maneuver) {
        int beginIndex = maneuver['begin_shape_index'] as int;
        _maneuvers.add({
          'instruction': maneuver['instruction'],
          'distance': (maneuver['length'] * 1000).round(),
          'location': beginIndex < _routePoints.length
              ? _routePoints[beginIndex]
              : _routePoints.last,
          'type': maneuver['type'],
        });
      });
    });

    setState(() {
      _isLoading = false;
      if (_routePoints.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePoints),
            padding: const EdgeInsets.all(50.0),
          ),
        );
      }
    });
  }

  String _calculateETA(double speed) {
    double totalDistance = 0;
    for (var i = 0; i < _routePoints.length - 1; i++) {
      totalDistance += const Distance().distance(
        _routePoints[i],
        _routePoints[i + 1],
      );
    }
    final hours = totalDistance / (speed * 1000);
    return 'ETA: ${hours.toStringAsFixed(1)} hours';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Demo')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(35.1264, 33.4299),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.benjys.me',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: startPoint,
                    width: 40,
                    height: 40,
                    child:
                        const Icon(Icons.flag, color: Colors.green, size: 40),
                  ),
                  Marker(
                    point: endPoint,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag, color: Colors.red, size: 40),
                  ),
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ..._maneuvers
                      .map(
                        (maneuver) => Marker(
                          point: maneuver['location'] as LatLng,
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _mapController.move(
                              maneuver['location'] as LatLng,
                              _mapController.camera.zoom,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _getManeuverIcon(maneuver['type'] as int).icon,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            ],
          ),
          if (_isLoading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_errorMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.redAccent,
                padding: const EdgeInsets.all(8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            right: 16,
            top: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: NavigationInstructionsPanel(
              maneuvers: _maneuvers,
              eta: _eta,
              onManeuverTap: (index) {
                if (index < _maneuvers.length) {
                  final maneuverLocation =
                      _maneuvers[index]['location'] as LatLng;
                  _mapController.move(
                    maneuverLocation,
                    _mapController.camera.zoom,
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'route_fab',
        onPressed: _isLoading ? null : _fetchAndDisplayRoute,
        child: const Icon(Icons.route),
      ),
    );
  }

  // Add the _getManeuverIcon method here
  Icon _getManeuverIcon(int type) {
    switch (type) {
      case 1:
        return const Icon(Icons.flag, color: Colors.green);
      case 2:
        return const Icon(Icons.turn_right, color: Colors.blue);
      case 3:
        return const Icon(Icons.turn_left, color: Colors.blue);
      case 4:
        return const Icon(Icons.turn_sharp_right, color: Colors.red);
      case 5:
        return const Icon(Icons.turn_sharp_left, color: Colors.red);
      default:
        return const Icon(Icons.directions, color: Colors.grey);
    }
  }
}

// Add the NavigationInstructionsPanel widget class
class NavigationInstructionsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> maneuvers;
  final String eta;
  final Function(int) onManeuverTap;

  const NavigationInstructionsPanel({
    required this.maneuvers,
    required this.eta,
    required this.onManeuverTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            if (eta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(eta,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: maneuvers.length,
                itemBuilder: (context, index) => ListTile(
                  leading: _getManeuverIcon(maneuvers[index]['type'] as int),
                  title: Text("${maneuvers[index]['instruction']}"),
                  subtitle: Text('${maneuvers[index]['distance']} meters'),
                  onTap: () => onManeuverTap(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Icon _getManeuverIcon(int type) {
    switch (type) {
      case 1:
        return const Icon(Icons.flag, color: Colors.green);
      case 2:
        return const Icon(Icons.turn_right, color: Colors.blue);
      case 3:
        return const Icon(Icons.turn_left, color: Colors.blue);
      case 4:
        return const Icon(Icons.turn_sharp_right, color: Colors.red);
      case 5:
        return const Icon(Icons.turn_sharp_left, color: Colors.red);
      default:
        return const Icon(Icons.directions, color: Colors.grey);
    }
  }
}

// Keep the existing decodeValhallaPolyline function here...

List<LatLng> decodeValhallaPolyline(String encoded) {
  final coordinates = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var result = 1;
    var shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    result = 1;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63 - 1;
      result += b << shift;
      shift += 5;
    } while (b >= 0x1f);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    coordinates.add(LatLng(lat / 1e6, lng / 1e6));
  }

  return coordinates;
}
