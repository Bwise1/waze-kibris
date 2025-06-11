// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:maplibre_gl/maplibre_gl.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       title: 'MapLibre Routing Example',
//       home: MapScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }
//
// class MapScreen extends StatefulWidget {
//   static const String routeName = '/map';
//   const MapScreen({super.key});
//
//   @override
//   State<MapScreen> createState() => _MapScreenState();
// }
//
// class _MapScreenState extends State<MapScreen> {
//   MaplibreMapController? mapController;
//   LatLng? _currentLocation;
//   bool _isLoading = false;
//   bool _mapReady = false;
//   bool _showRouteDetails = false;
//   bool _markersLoaded = false;
//
//   String stadiaApiKey = "8a83c0b9-fbe3-4caa-98d5-d8b60efc67c5";
//   static const backendUrl = "https://waze-api.benjys.me/route";
//
//   Map<String, dynamic>? routeData;
//   Line? _routeLine;
//   Symbol? _startSymbol;
//   Symbol? _endSymbol;
//
//   @override
//   void initState() {
//     super.initState();
//     _requestLocationPermission();
//   }
//
//   Future<void> _requestLocationPermission() async {
//     final status = await Permission.locationWhenInUse.request();
//     if (status.isGranted) {
//       _getCurrentLocation();
//     } else {
//       _showPermissionDialog();
//     }
//   }
//
//   Future<void> _getCurrentLocation() async {
//     setState(() => _isLoading = true);
//     try {
//       Position pos = await Geolocator.getCurrentPosition();
//       _currentLocation = LatLng(pos.latitude, pos.longitude);
//       if (_mapReady) {
//         _moveCamera(_currentLocation!);
//         await _fetchRoute();
//       }
//     } catch (e) {
//       _showSnackBar('Failed to get location');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _moveCamera(LatLng target) {
//     mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)),
//     );
//   }
//
//   Future<void> _loadMarkerImages() async {
//     if (_markersLoaded) return;
//
//     try {
//       // Load start marker PNG
//       final ByteData startMarkerData =
//           await rootBundle.load('assets/CurrentPosition.png');
//       await mapController?.addImage(
//           'start-marker', startMarkerData.buffer.asUint8List());
//
//       // Load end marker PNG
//       final ByteData endMarkerData =
//           await rootBundle.load('assets/marker-pin-02.png');
//       await mapController?.addImage(
//           'end-marker', endMarkerData.buffer.asUint8List());
//
//       _markersLoaded = true;
//     } catch (e) {
//       debugPrint('Error loading marker images: $e');
//     }
//   }
//
//   Future<void> _fetchRoute() async {
//     if (_currentLocation == null) return;
//     setState(() => _isLoading = true);
//     try {
//       final endPoint = LatLng(35.221906, 33.417018); // Example destination
//
//       final response = await http.post(
//         Uri.parse(backendUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'X-Request-Source': 'postman'
//         },
//         body: jsonEncode({
//           "locations": [
//             {"lat": 35.204970, "lon": 33.317932},
//             {"lat": 35.221906, "lon": 33.417018},
//           ],
//         }),
//       );
//
//       if (response.statusCode == 200) {
//         routeData = jsonDecode(response.body);
//         if (_mapReady) {
//           _drawRoute();
//         }
//       } else {
//         throw Exception('Failed with status: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint(':::::::::::Error fetching route: $e');
//       _showSnackBar('Error fetching route');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   // Replace your _drawRoute() method with this implementation
//   void _drawRoute() async {
//     if (mapController == null || routeData == null) return;
//     await _loadMarkerImages();
//     // Clear previous route
//     if (_routeLine != null) {
//       mapController?.removeLine(_routeLine!);
//     }
//     if (_startSymbol != null) {
//       mapController?.removeSymbol(_startSymbol!);
//     }
//     if (_endSymbol != null) {
//       mapController?.removeSymbol(_endSymbol!);
//     }
//
//     final coords =
//         (routeData!['data']['trip']['legs'][0]['coordinates'] as List)
//             .map<LatLng>((c) => LatLng(c[1], c[0]))
//             .toList();
//
//     // Draw the route line first
//     _routeLine = await mapController?.addLine(LineOptions(
//       geometry: coords,
//       lineColor: '#3b82f6',
//       lineWidth: 5,
//       lineOpacity: 0.8,
//     ));
//
//     // Add start point as a circle (will always be visible)
//     await mapController?.addCircle(CircleOptions(
//       geometry: coords.first,
//       circleRadius: 8,
//       circleColor: '#4CAF50', // Green for start
//       circleStrokeColor: '#FFFFFF',
//       circleStrokeWidth: 2,
//       circleOpacity: 0.9,
//     ));
//
//     // Add end point as a circle (will always be visible)
//     await mapController?.addCircle(CircleOptions(
//       geometry: coords.last,
//       circleRadius: 8,
//       circleColor: '#F44336', // Red for destination
//       circleStrokeColor: '#FFFFFF',
//       circleStrokeWidth: 2,
//       circleOpacity: 0.9,
//     ));
//
//     // Try to add symbols as well (as a backup)
//     try {
//       // Add start marker using PNG
//       _startSymbol = await mapController?.addSymbol(SymbolOptions(
//         geometry: coords.first,
//         iconImage: 'start-marker',
//         iconSize: 1.0, // Adjust this value based on your PNG size
//         iconAnchor: 'bottom', // Position the marker correctly
//       ));
//
//       // Add end marker using PNG
//       _endSymbol = await mapController?.addSymbol(SymbolOptions(
//         geometry: coords.last,
//         iconImage: 'end-marker',
//         iconSize: 1.0, // Adjust this value based on your PNG size
//         iconAnchor: 'bottom', // Position the marker correctly
//       ));
//     } catch (e) {
//       debugPrint('Error adding symbols: $e');
//       // If symbols fail, we still have circles as markers
//     }
//
//     _fitBounds(coords);
//   }
//
//   void _fitBounds(List<LatLng> coords) {
//     if (coords.isEmpty) return;
//
//     double minLat = coords.first.latitude, maxLat = coords.first.latitude;
//     double minLon = coords.first.longitude, maxLon = coords.first.longitude;
//
//     for (var c in coords) {
//       if (c.latitude < minLat) minLat = c.latitude;
//       if (c.latitude > maxLat) maxLat = c.latitude;
//       if (c.longitude < minLon) minLon = c.longitude;
//       if (c.longitude > maxLon) maxLon = c.longitude;
//     }
//
//     mapController?.animateCamera(CameraUpdate.newLatLngBounds(
//       LatLngBounds(
//         southwest: LatLng(minLat, minLon),
//         northeast: LatLng(maxLat, maxLon),
//       ),
//       // padding: 80,
//     ));
//   }
//
//   void _showPermissionDialog() {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Permission Needed'),
//         content: const Text('Location access is needed for routing.'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               openAppSettings();
//               Navigator.of(ctx).pop();
//             },
//             child: const Text('Open Settings'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(),
//             child: const Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showSnackBar(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }
//
//   void _onMapCreated(MapLibreMapController controller) async {
//     mapController = controller;
//     setState(() => _mapReady = true);
//
//     await _loadMarkerImages();
//
//     if (_currentLocation != null) {
//       _moveCamera(_currentLocation!);
//     }
//     if (routeData != null) {
//       _drawRoute();
//     }
//   }
//
//   void _toggleDetails() {
//     setState(() => _showRouteDetails = !_showRouteDetails);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('MapLibre Routing'),
//         actions: [
//           if (routeData != null)
//             IconButton(
//               onPressed: _toggleDetails,
//               icon: const Icon(Icons.info_outline),
//             ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           MapLibreMap(
//             onMapCreated: _onMapCreated,
//             initialCameraPosition: CameraPosition(
//               target: _currentLocation ?? const LatLng(37.7749, -122.4194),
//               zoom: 10,
//             ),
//             styleString:
//                 'https://tiles-eu.stadiamaps.com/styles/outdoors.json?api_key=$stadiaApiKey',
//             myLocationEnabled: true,
//             myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
//             myLocationRenderMode: MyLocationRenderMode.compass,
//           ),
//           if (_isLoading) const Center(child: CircularProgressIndicator()),
//           if (_showRouteDetails && routeData != null)
//             RouteDetailsPanel(
//               summary: routeData!['data']['trip']['summary'],
//               maneuvers: routeData!['data']['trip']['legs'][0]['maneuvers'],
//               onClose: _toggleDetails,
//             ),
//         ],
//       ),
//       floatingActionButton: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (_currentLocation != null && routeData == null)
//             FloatingActionButton(
//               onPressed: _fetchRoute,
//               heroTag: 'route',
//               child: const Icon(Icons.directions),
//             ),
//           const SizedBox(height: 10),
//           FloatingActionButton(
//             onPressed: _getCurrentLocation,
//             heroTag: 'location',
//             child: const Icon(Icons.my_location),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class RouteDetailsPanel extends StatelessWidget {
//   final Map<String, dynamic> summary;
//   final List<dynamic> maneuvers;
//   final VoidCallback onClose;
//
//   const RouteDetailsPanel({
//     required this.summary,
//     required this.maneuvers,
//     required this.onClose,
//     super.key,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         height: MediaQuery.of(context).size.height * 0.5,
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//         ),
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text('Route Details',
//                     style:
//                         TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//                 IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
//               ],
//             ),
//             const Divider(),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildInfo(Icons.timer, 'Duration', summary['formattedTime']),
//                 _buildInfo(Icons.map, 'Distance', summary['formattedDistance']),
//               ],
//             ),
//             const SizedBox(height: 10),
//             const Divider(),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: maneuvers.length,
//                 itemBuilder: (_, idx) {
//                   final m = maneuvers[idx];
//                   return ListTile(
//                     leading: const Icon(Icons.navigation),
//                     title: Text(m['instruction']),
//                     subtitle: Text(
//                       '${(m['distanceMeters'] / 1000).toStringAsFixed(1)} km, ${_formatSeconds(m['timeSeconds'])}',
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildInfo(IconData icon, String label, String value) {
//     return Column(
//       children: [
//         Icon(icon),
//         Text(label, style: const TextStyle(fontSize: 12)),
//         Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
//       ],
//     );
//   }
//
//   String _formatSeconds(num seconds) {
//     final minutes = (seconds / 60).floor();
//     final secs = (seconds % 60).floor();
//     return '${minutes}m ${secs}s';
//   }
// }
