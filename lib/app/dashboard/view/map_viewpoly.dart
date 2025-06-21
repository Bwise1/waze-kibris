// import 'dart:convert';
// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:latlong2/latlong.dart' as latlong;
// import 'package:maplibre_gl/maplibre_gl.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:sheet/sheet.dart';
// import 'package:turf/turf.dart' as turf;
// import 'package:waze_kibris/app/dashboard/modals/report_modal.dart';
// import 'package:waze_kibris/app/dashboard/view/maneuver_banner.dart';
// import 'package:waze_kibris/app/dashboard/view/route_summary.dart';
// import 'package:waze_kibris/common.dart';
// import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
// import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
// import 'package:waze_kibris/core/bloc/reports/report_state.dart';
// import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
// import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
// import 'package:waze_kibris/core/models/reports/report_response.dart';

// enum RouteFetchState {
//   none,
//   foundDestination,
//   searchingOutDestination,
//   nowInDestination
// }

// class MapPolyScreen extends StatefulWidget {
//   const MapPolyScreen({
//     required this.controller,
//     this.onRouteSelected,
//     required this.mapPolyKey,
//     super.key,
//   });
//   static const String routeName = '/map';
//   // final ValueChanged<RouteFetchState> onRouteStateChanged;
//   final SheetController controller;
//   final void Function(int index)? onRouteSelected;
//   final GlobalKey<MapPolyScreenState> mapPolyKey;

//   @override
//   State<MapPolyScreen> createState() => MapPolyScreenState();
// }

// List<Map<String, dynamic>> availableRoutes = [];

// class MapPolyScreenState extends State<MapPolyScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<Offset> _offsetAnimation;
//   bool _isVisible = false;
//   MapLibreMapController? mapController;
//   LatLng? _currentLocation;
//   bool _isLoading = false;
//   bool _tripIsStarted = false;
//   bool _mapReady = false;
//   bool _showRouteDetails = false;
//   bool _markersLoaded = false;
//   double? _userHeading;

//   // bool _showRouteOptionPanel = false;
//   // bool _showStartEndDisplayPanel = false;
//   LatLng? foundLocation;
//   List<Map<String, dynamic>> suggestions = [];

//   RouteFetchState _mRouteState = RouteFetchState.none;

//   late LatLng? _destinationEndPoint;
//   String foundLocationName = 'Destination';
//   String stadiaApiKey = '8a83c0b9-fbe3-4caa-98d5-d8b60efc67c5';
//   static const backendUrl = 'https://waze-api.benjys.me/route';
//   static const backendBaseUrl = 'https://waze-api.benjys.me';

//   Map<String, dynamic>? routeData;
//   Line? _routeLine;
//   Symbol? _startSymbol;
//   Symbol? _endSymbol;
//   Circle? _startCircle;
//   Circle? _endCircle;

//   @override
//   void initState() {
//     super.initState();
//     _requestLocationPermission();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 600),
//       vsync: this,
//     );
//     _offsetAnimation = Tween<Offset>(
//       begin: const Offset(0, -1), // Start off-screen (above)
//       end: const Offset(0, 0.06), // End at 60px from top (visible)
//     ).animate(
//       CurvedAnimation(
//         parent: _controller,
//         curve: Curves.easeInOut,
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   void _toggleNotification() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       setState(() {
//         _isVisible = !_isVisible;
//         if (_isVisible) {
//           _controller.forward();
//         } else {
//           _controller.reverse();
//         }
//       });
//     });
//   }

//   Future<void> _requestLocationPermission() async {
//     final status = await Permission.locationWhenInUse.request();
//     if (status.isGranted) {
//       await _getCurrentLocation();
//     } else {
//       _showPermissionDialog();
//     }
//   }

//   Future<void> _getCurrentLocation() async {
//     setState(() => _isLoading = true);
//     try {
//       final pos = await Geolocator.getCurrentPosition();
//       _currentLocation = LatLng(pos.latitude, pos.longitude);
//       if (context.mounted) {
//         context.read<ReportsBloc>().add(
//               ReportsEvent.getNearByReports(
//                 radius: 5,
//                 lat: _currentLocation!.latitude.toString(),
//                 long: _currentLocation!.longitude.toString(),
//               ),
//             );
//       }
//       if (_mapReady) {
//         _moveCamera(_currentLocation!, zoom: 17);
//         //
//         // await _fetchRoute();
//       }
//     } catch (e) {
//       _showSnackBar('Failed to get location');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _moveCamera(LatLng target, {double zoom = 12}) {
//     mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: target, zoom: zoom),
//       ),
//     );
//   }

//   Future<void> _loadMarkerImages() async {
//     if (_markersLoaded) return;

//     try {
//       // // Load start marker PNG
//       // final startMarkerData =
//       //     await rootBundle.load('assets/icons/currentPosition.png');
//       // await mapController?.addImage(
//       //     'start-marker', startMarkerData.buffer.asUint8List());

//       // Load my location marker PNG
//       final myLocationMarkerData =
//           await rootBundle.load('assets/icons/mylpin.png');
//       await mapController?.addImage(
//         'end-marker',
//         myLocationMarkerData.buffer.asUint8List(),
//       );

//       // Load circle marker PNG
//       final circle = await rootBundle.load('assets/icons/circle_one.png');
//       await mapController?.addImage(
//         'circle-marker',
//         circle.buffer.asUint8List(),
//       );

//       // Load circle marker PNG
//       final userMarkerData =
//           await rootBundle.load('assets/icons/CurrentPosition.png');
//       await mapController?.addImage(
//         'userPin-marker',
//         userMarkerData.buffer.asUint8List(),
//       );

//       // Load start trip marker PNG
//       final startTripMarkerData =
//           await rootBundle.load('assets/icons/start_trip.png');
//       await mapController?.addImage(
//         'startTrip-marker',
//         startTripMarkerData.buffer.asUint8List(),
//       );

//       // Load police marker PNG
//       final policeMarkerData = await rootBundle.load(Assets.icons.police.path);
//       await mapController?.addImage(
//         'police-marker',
//         policeMarkerData.buffer.asUint8List(),
//       );

//       // Load police car marker PNG
//       final policeCarMarkerData = await rootBundle.load(
//         Assets.icons.policeCar.path,
//       );
//       await mapController?.addImage(
//         'policeCar-marker',
//         policeCarMarkerData.buffer.asUint8List(),
//       );

//       // Load accident marker PNG
//       final accidentMarkerData =
//           await rootBundle.load(Assets.icons.accident.path);
//       await mapController?.addImage(
//         'accident-marker',
//         accidentMarkerData.buffer.asUint8List(),
//       );

//       // Load accident marker PNG
//       final pointMarkerData =
//           await rootBundle.load(Assets.icons.pointMarker.path);
//       await mapController?.addImage(
//         'point-marker',
//         pointMarkerData.buffer.asUint8List(),
//       );
//       _markersLoaded = true;
//     } catch (e) {
//       _showSnackBar('Error loading marker images: $e');
//       debugPrint('Error loading marker images: $e');
//     }
//   }

//   Future<void> _fetchRoute() async {
//     if (_currentLocation == null) return;
//     setState(() => _isLoading = true);
//     String payload = jsonEncode({
//       'locations': [
//         {
//           'lat': _currentLocation?.latitude,
//           'lon': _currentLocation?.longitude,
//         },
//         {
//           'lat': _destinationEndPoint?.latitude,
//           'lon': _destinationEndPoint?.longitude,
//         },
//         // {"lat": 35.221906, "lon": 33.417018},
//       ],
//       // 'costing': 'auto',
//       // 'units': 'kilometers',
//       // 'directions_options': {'narrative': true},
//     });

//     print('+++++++++++++++++++++Payload: $payload');
//     try {
//       final response = await http.post(
//         Uri.parse(backendUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'X-Request-Source': 'postman',
//         },
//         body: jsonEncode({
//           'locations': [
//             {
//               'lat': _currentLocation?.latitude,
//               'lon': _currentLocation?.longitude,
//             },
//             {
//               'lat': _destinationEndPoint?.latitude,
//               'lon': _destinationEndPoint?.longitude,
//             },
//             // {"lat": 35.221906, "lon": 33.417018},
//           ],
//           // 'costing': 'auto',
//           // 'units': 'kilometers',
//           // 'directions_options': {'narrative': true},
//         }),
//       );

//       if (response.statusCode == 200) {
//         routeData = jsonDecode(response.body) as Map<String, dynamic>;

// // After: routeData = jsonDecode(response.body) as Map<String, dynamic>;
//         final data = routeData!['data'];
//         final mainRoute = data['trip'] as Map<String, dynamic>;
//         final alternatesRaw = data['alternates'];
//         final alternates = (alternatesRaw is List)
//             ? alternatesRaw
//                 .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
//                 .toList()
//             : <Map<String, dynamic>>[];
//         availableRoutes = [mainRoute, ...alternates];

//         print(
//           '++++++++++++++++Route data fetched successfully: ${availableRoutes.length}',
//         );
//       } else {
//         throw Exception('Failed with status: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint(':::::::::::Error fetching route: $e');
//       _showSnackBar('Error fetching route ');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   List<LatLng> polylineCoords = [];
//   // Replace your _drawRoute() method with this implementation
//   Future<void> _drawRoute() async {
//     if (mapController == null || routeData == null) return;
//     await _loadMarkerImages();
//     // Clear previous route
//     if (_routeLine != null) {
//       await mapController?.removeLine(_routeLine!);
//     }
//     if (_startSymbol != null) {
//       await mapController?.removeSymbol(_startSymbol!);
//     }
//     if (_endSymbol != null) {
//       await mapController?.removeSymbol(_endSymbol!);
//     }
//     if (_startCircle != null) {
//       await mapController?.removeCircle(_startCircle!);
//     }
//     if (_endCircle != null) {
//       await mapController?.removeCircle(_endCircle!);
//     }

//     final coords =
//         (routeData!['data']['trip']['legs'][0]['coordinates'] as List)
//             .map<LatLng>((c) => LatLng(c[1] as double, c[0] as double))
//             .toList();

//     polylineCoords = coords;
//     // Draw the route line first
//     _routeLine = await mapController?.addLine(
//       LineOptions(
//         geometry: coords,
//         lineColor: '#3b82f6',
//         lineWidth: 6,
//         lineOpacity: 0.9,
//       ),
//     );

//     // // Add start point as a circle (will always be visible)
//     _startCircle = await mapController?.addCircle(
//       CircleOptions(
//         geometry: coords.first,
//         circleRadius: 8,
//         circleColor: '#4CAF50', // Green for start
//         circleStrokeColor: '#FFFFFF',
//         circleStrokeWidth: 2,
//         circleOpacity: 0.9,
//       ),
//     );

//     // Try to add symbols as well (as a backup)
//     try {
//       // Add end marker using PNG
//       _endSymbol = await mapController?.addSymbol(
//         SymbolOptions(
//           geometry: coords.last,
//           iconImage: 'end-marker',
//           iconSize: 0.2, // Adjust this value based on your PNG size
//           iconAnchor: 'bottom', // Position the marker correctly
//         ),
//       );
//     } catch (e) {
//       debugPrint('Error adding symbols: $e');
//       // If symbols fail, we still have circles as markers
//     }
//     _zoomOnPointA(_currentLocation!);
//     // _fitBounds(coords);
//   }

//   //this removes all line   and marker added
//   Future<void> _removeLineAndClearMarkers() async {
//     _moveCamera(_currentLocation!, zoom: 10);
//     // Clear previous route
//     if (_routeLine != null) {
//       await mapController?.removeLine(_routeLine!);
//     }
//     if (_startSymbol != null) {
//       await mapController?.removeSymbol(_startSymbol!);
//     }
//     if (_endSymbol != null) {
//       await mapController?.removeSymbol(_endSymbol!);
//     }
//     if (_startCircle != null) {
//       await mapController?.removeCircle(_startCircle!);
//     }
//     if (_endCircle != null) {
//       await mapController?.removeCircle(_endCircle!);
//     }
//     routeData = null;
//   }

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

//   void _showSnackBar(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }

//   Future<void> _onMapCreated(MapLibreMapController controller) async {
//     mapController = controller;
//     setState(() => _mapReady = true);

//     await _loadMarkerImages();
//     _startUserLocationUpdates();

//     if (_currentLocation != null) {
//       _moveCamera(_currentLocation!, zoom: 16);
//     }
//     if (routeData != null) {
//       _drawRoute();
//     }

//     mapController?.onSymbolTapped.add(tapSymbols);
//   }

//   void _toggleDetails() {
//     setState(() => _showRouteDetails = !_showRouteDetails);
//   }

//   void _toggleRouteOptionStates(RouteFetchState state) {
//     // widget.onRouteStateChanged(state);
//     setState(() {
//       _mRouteState = state;
//       if (_mRouteState == RouteFetchState.searchingOutDestination ||
//           _mRouteState == RouteFetchState.nowInDestination) {
//       } else if (_mRouteState == RouteFetchState.none) {}
//     });
//   }

//   String getIconOnMapByReportType(String reportType) {
//     ///

//     if (reportType == ReportType.police.name) {
//       return 'police-marker';
//       // return Assets.icons.police.path;
//     }
//     if (reportType == ReportType.traffic.name) {
//       return 'policeCar-marker';
//       // return Assets.icons.policeCar.path;
//     }
//     if (reportType == ReportType.accident.name) {
//       return 'accident-marker';
//       // return Assets.icons.accident.path;
//     } else {
//       return 'point-marker';
//       // return Assets.icons.pointMarker.path;
//     }
//   }

//   void _populateMapWithReportsPoints(
//       List<ReportData> reports, BuildContext context) {
//     final symbols = reports.map((ReportData? report) {
//       if (report != null) {
//         return SymbolOptions(
//           geometry: LatLng(report.latitude, report.longitude),
//           iconImage: getIconOnMapByReportType(
//             report.type.toLowerCase().trim(),
//           ),
//           iconSize: 0.2,
//           textOffset: const Offset(0, 2),
//           textField: report.type,
//           textSize: 12,
//         );
//       }
//       return SymbolOptions.defaultOptions;
//     }).toList();

//     mapController!.addSymbols(symbols);
//     setState(() {});
//   }

//   void tapSymbols(Symbol symbol) {
//     _toggleRouteOptionStates(RouteFetchState.foundDestination);
//     if (_mRouteState == RouteFetchState.foundDestination) {
//       _destinationEndPoint = symbol.options.geometry!;
//       getNameOfSelectedCoordinate(_destinationEndPoint);
//       _toggleNotification(); //open panel

//       ///move the camera to selected position
//       ///
//       ///
//       _moveCamera(_destinationEndPoint!);
//     } else {
//       _destinationEndPoint = null;
//     }

//     //wait after widget builds before call setState
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       setState(() {});
//     });
//   }

//   Future<void> getNameOfSelectedCoordinate(LatLng? latLng) async {
//     if (latLng != null) {
//       await placemarkFromCoordinates(latLng.latitude, latLng.longitude)
//           .then((placeMarks) {
//         if (placeMarks.isNotEmpty) {
//           foundLocationName =
//               '${placeMarks.reversed.last.country} ${placeMarks.reversed.last.locality} ${placeMarks.reversed.last.street}';
//           // output = placeMarks[0].toString();
//           // debugPrint(placeMarks.toString());
//           setState(() {});
//         }
//       });
//     }
//   }

//   int _currentManeuverIndex = 0;

//   void _advanceManeuverIfNeeded(LatLng userPosition) {
//     final maneuvers = routeData?['data']?['trip']?['legs']?[0]?['maneuvers']
//         as List<dynamic>?;
//     if (maneuvers == null || maneuvers.isEmpty) return;
//     if (_currentManeuverIndex >= maneuvers.length) return;

//     final next = maneuvers[_currentManeuverIndex];
//     if (next['position'] is List && next['position'].length == 2) {
//       final maneuverLat = next['position'][0] as double;
//       final maneuverLng = next['position'][1] as double;
//       final distance = const latlong.Distance().as(
//         latlong.LengthUnit.Meter,
//         latlong.LatLng(userPosition.latitude, userPosition.longitude),
//         latlong.LatLng(maneuverLat, maneuverLng),
//       );
//       if (distance < 25) {
//         // 25 meters threshold
//         setState(() {
//           _currentManeuverIndex =
//               (_currentManeuverIndex + 1).clamp(0, maneuvers.length - 1);
//         });
//       }
//     }
//   }

//   void _startUserLocationUpdates({bool animateCameraLongLocation = false}) {
//     Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 3,
//       ),
//     ).listen((Position position) {
//       final userLatLng = LatLng(position.latitude, position.longitude);

//       _advanceManeuverIfNeeded(userLatLng);
//       // Only update if moved >2 meters
//       if (_currentLocation == null ||
//           const latlong.Distance().as(
//                 latlong.LengthUnit.Meter,
//                 latlong.LatLng(
//                     _currentLocation!.latitude, _currentLocation!.longitude),
//                 latlong.LatLng(userLatLng.latitude, userLatLng.longitude),
//               ) >
//               2) {
//         if (_tripIsStarted) {
//           _updateMarkerAndCamera(userLatLng);
//         } else {
//           _updateCustomUserMaker(userLatLng);
//         }
//       }
//     });
//   }

//   LatLng? _previousPosition;

//   bool _isAnimatingMarker = false;

//   Future<void> _updateMarkerAndCamera(LatLng currentPosition) async {
//     if (_isAnimatingMarker) return;
//     _isAnimatingMarker = true;

//     final snappedPosition = _snapToPolyline(currentPosition, polylineCoords);
//     if (userMaker != null) {
//       if (_previousPosition != null) {
//         const steps = 20;
//         final deltaLat =
//             (snappedPosition.latitude - _previousPosition!.latitude) / steps;
//         final deltaLng =
//             (snappedPosition.longitude - _previousPosition!.longitude) / steps;
//         for (int i = 1; i <= steps; i++) {
//           final interpolatedPosition = LatLng(
//             _previousPosition!.latitude + deltaLat * i,
//             _previousPosition!.longitude + deltaLng * i,
//           );
//           await mapController?.updateSymbol(
//             userMaker!,
//             SymbolOptions(geometry: interpolatedPosition),
//           );
//           await Future.delayed(const Duration(milliseconds: 50 ~/ steps));
//         }
//       } else {
//         await mapController?.updateSymbol(
//           userMaker!,
//           SymbolOptions(geometry: snappedPosition),
//         );
//       }
//     }
//     await mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(
//           target: snappedPosition,
//           zoom: 18,
//           bearing: bearing != null
//               ? bearing!
//               : _previousPosition != null
//                   ? _calculateBearingTwo(_previousPosition!, snappedPosition)
//                   : 0,
//           tilt: 45,
//         ),
//       ),
//       duration: const Duration(seconds: 2),
//     );
//     _previousPosition = snappedPosition;
//     _isAnimatingMarker = false;
//   }

//   LatLng _snapToPolyline(LatLng position, List<LatLng> polylineCoords) {
//     final point = turf.Point(
//         coordinates: turf.Position(position.longitude, position.latitude));
//     final line = turf.LineString(
//       coordinates: polylineCoords
//           .map((p) => turf.Position(p.longitude, p.latitude))
//           .toList(),
//     );
//     final snapped = turf.nearestPointOnLine(line, point);
//     return LatLng(snapped.geometry!.coordinates.lat.toDouble(),
//         snapped.geometry!.coordinates.lng.toDouble());
//   }

//   double _calculateBearingTwo(LatLng point1, LatLng point2) {
//     final lon1 = point1.longitude * pi / 180;
//     final lat1 = point1.latitude * pi / 180;
//     final lon2 = point2.longitude * pi / 180;
//     final lat2 = point2.latitude * pi / 180;

//     final dLon = lon2 - lon1;
//     final y = sin(dLon) * cos(lat2);
//     final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
//     var bearing = atan2(y, x) * 180 / pi;
//     bearing = (bearing + 360) % 360;
//     return bearing;
//   }

//   Symbol? userMaker;
//   Future<void> _updateCustomUserMaker(LatLng location) async {
//     _currentLocation = location; //constantly update user location

//     if (_tripIsStarted) {
//       // If trip is started, _updateMarkerAndCamera will handle the userMaker.
//       // _currentLocation is updated, but the visual update is deferred.
//       return;
//     }

//     // Logic for when trip is NOT started
//     if (mapController == null) return; // Ensure mapController is ready

//     if (userMaker == null) {
//       userMaker = await mapController!.addSymbol(
//         SymbolOptions(
//           geometry: location,
//           iconImage: 'userPin-marker', // Default icon when not navigating
//           iconSize: 0.6,
//         ),
//       );
//     } else {
//       // Update existing marker's position and ensure correct icon if not navigating
//       await mapController!.updateSymbol(
//         userMaker!,
//         SymbolOptions(
//           geometry: location,
//           iconImage: 'userPin-marker', // Ensure it's the non-navigation icon
//           iconSize: 0.6, // Keep consistent size
//         ),
//       );
//     }
//   }

//   void _toggleStartTrip(bool startTrip) {
//     debugPrint(
//         '[MapPolyScreenState] _toggleStartTrip: Called with startTrip = $startTrip');
//     debugPrint(
//         '[MapPolyScreenState] _toggleStartTrip: _tripIsStarted BEFORE = $_tripIsStarted');
//     _tripIsStarted = startTrip;
//     debugPrint(
//         '[MapPolyScreenState] _toggleStartTrip: _tripIsStarted AFTER = $_tripIsStarted');

//     // WidgetsBinding.instance.addPostFrameCallback((_) {
//     if (_tripIsStarted) {
//       debugPrint(
//           '[MapPolyScreenState] _toggleStartTrip: Condition _tripIsStarted is TRUE');
//       if (userMaker != null && _currentLocation != null) {
//         // Added null checks
//         mapController!.updateSymbol(
//           userMaker!,
//           SymbolOptions(
//             geometry: _currentLocation, // Ensure _currentLocation is not null
//             iconImage: 'startTrip-marker',
//             iconSize: 0.8,
//           ),
//         );
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: Updated userMaker to startTrip-marker');
//       } else {
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: userMaker or _currentLocation is null, cannot update symbol for trip start');
//       }

//       if (_startCircle != null) {
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: _startCircle is not null');

//         _updateMarkerAndCamera(_startCircle!.options.geometry!);
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: Called _updateMarkerAndCamera');
//         _startUserLocationUpdates(animateCameraLongLocation: true);
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: Called _startUserLocationUpdates(animateCameraLongLocation: true)');
//       } else {
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: _startCircle IS NULL');
//       }
//     } else {
//       debugPrint(
//           '[MapPolyScreenState] _toggleStartTrip: Condition _tripIsStarted is FALSE');
//       if (userMaker != null && _currentLocation != null) {
//         // Added null checks
//         mapController!.updateSymbol(
//           userMaker!,
//           SymbolOptions(
//             geometry: _currentLocation, // Ensure _currentLocation is not null
//             iconImage: 'userPin-marker',
//             // iconSize: 2,
//           ),
//         );
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: Updated userMaker to userPin-marker');
//       } else {
//         debugPrint(
//             '[MapPolyScreenState] _toggleStartTrip: userMaker or _currentLocation is null, cannot update symbol for trip end');
//       }

//       _removeLineAndClearMarkers();
//       debugPrint(
//           '[MapPolyScreenState] _toggleStartTrip: Called _removeLineAndClearMarkers');
//     }
//     // });
//   }

//   void startTrip() => _toggleStartTrip(true);

//   ///
//   ///
//   double? bearing; // Store the bearing from A to B
// // Calculate bearing from point A to point B
//   void _calculateBearing() {
//     final a = latlong.LatLng(_startCircle!.options.geometry!.latitude,
//         _startCircle!.options.geometry!.longitude);
//     final b = polylineCoords.length > 3
//         ? latlong.LatLng(
//             polylineCoords[1].latitude,
//             polylineCoords[1].longitude,
//           )
//         : latlong.LatLng(
//             _destinationEndPoint!.latitude,
//             _destinationEndPoint!.longitude,
//           );
//     bearing = const latlong.Distance().bearing(a, b); // Bearing in degrees
//   }

//   ///
//   ///
//   // Zoom in on point A with the calculated bearing
//   void _zoomOnPointA(LatLng pointA, {bool startTripZoom = false}) {
//     _calculateBearing();
//     if (bearing == null) return;

//     if (startTripZoom) {
//       mapController!.animateCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: pointA,
//             zoom: 18, // Zoom level for point A
//             bearing: bearing!,
//             tilt: 56, // Orient the map toward point B
//           ),
//         ),
//         duration: const Duration(seconds: 2), // Smooth zoom animation
//       );
//     } else {
//       mapController!.animateCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: pointA,
//             zoom: 13, // Zoom level for point A
//             // bearing: 0,
//           ),
//         ),
//         duration: const Duration(seconds: 2), // Smooth zoom animation
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final List? maneuvers = routeData?['data']?['trip']?['legs']?[0]
//         ?['maneuvers'] as List<dynamic>?;
//     final isNavigating =
//         _tripIsStarted && maneuvers != null && maneuvers.isNotEmpty;
//     final nextManeuver =
//         (isNavigating && _currentManeuverIndex < maneuvers.length)
//             ? maneuvers[_currentManeuverIndex]
//             : null;

//     debugPrint('[MapPolyScreen] build: isNavigating = $isNavigating');
//     debugPrint('[MapPolyScreen] build: nextManeuver = $nextManeuver');
//     return Scaffold(
//       body: Stack(
//         children: [
//           BlocConsumer<ReportsBloc, ReportState>(
//             listener: (context, state) {
//               if (state is GetReportSuccess) {
//                 _populateMapWithReportsPoints(state.data, context);
//               }
//             },
//             builder: (context, state) {
//               return MapLibreMap(
//                 onMapCreated: _onMapCreated,
//                 compassEnabled: true,

//                 compassViewMargins: const Point(0, 700),
//                 initialCameraPosition: CameraPosition(
//                   target: _currentLocation ?? const LatLng(37.7749, -122.4194),
//                   zoom: 17,
//                 ),
//                 styleString:
//                     'https://tiles-eu.stadiamaps.com/styles/outdoors.json?api_key=$stadiaApiKey',
//                 // myLocationEnabled: false,
//                 // myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
//                 //myLocationRenderMode: MyLocationRenderMode.compass,
//                 onStyleLoadedCallback: _loadMarkerImages,
//               );
//             },
//           ),
//           if (_isLoading) const Center(child: CircularProgressIndicator()),
//           if (_showRouteDetails && routeData != null)
//             RouteDetailsPanel(
//               summary:
//                   routeData!['data']['trip']['summary'] as Map<String, dynamic>,
//               maneuvers:
//                   routeData!['data']['trip']['legs'][0]['maneuvers'] as List,
//               onClose: _toggleDetails,
//             ),

//           //show the route option panel to navigate
//           if (_mRouteState == RouteFetchState.foundDestination &&
//               _destinationEndPoint != null)
//             RouteOptionPanel(
//               key: UniqueKey(),
//               title: foundLocationName,
//               mRouteState: _mRouteState,
//               onClose: () {
//                 _toggleRouteOptionStates(RouteFetchState.none);
//               },
//               onClickGetDirection: (_mRouteState ==
//                           RouteFetchState.foundDestination &&
//                       _destinationEndPoint != null)
//                   ? () async {
//                       await getNameOfSelectedCoordinate(_destinationEndPoint);
//                       await _fetchRoute();
//                       // _toggleRouteOptionStates(
//                       //     RouteFetchState.searchingOutDestination);
//                     }
//                   : () {},
//               onClickStartTrip: () {
//                 debugPrint('[RouteOptionPanel] onClickStartTrip: Tapped');
//                 startTrip();
//                 debugPrint(
//                     '[RouteOptionPanel] onClickStartTrip: Called startTrip()');
//                 _toggleRouteOptionStates(RouteFetchState
//                     .nowInDestination); // Add this to hide the panel
//                 debugPrint(
//                     '[RouteOptionPanel] onClickStartTrip: Called _toggleRouteOptionStates(nowInDestination)');
//               },
//             ),

//           if (isNavigating && nextManeuver != null)
//             Positioned(
//               top: MediaQuery.of(context).padding.top + 16,
//               left: 0,
//               right: 0,
//               child: ManeuverBanner(
//                 distance: '${nextManeuver['distanceMeters']} m',
//                 instruction: nextManeuver['instruction'].toString() ?? '',
//                 roadName: nextManeuver['streetName'].toString() ?? '',
//                 icon: Icons.turn_left, // You can map maneuver type to icon
//                 onVoiceTap: () {
//                   // Optionally trigger TTS or voice instructions
//                 },
//               ),
//             ),

//           ///top most panel
//           ///
//           SlideTransition(
//             position: _offsetAnimation,
//             child: Column(
//               children: [
//                 CustomContainer(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

//                   // height: 200,
//                   // width: 400,
//                   color: styles.theme.white,
//                   borderRadius: BorderRadius.circular(styles.corners.md),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Expanded(
//                         child: Row(
//                           children: [
//                             Container(
//                               height: 15,
//                               width: 15,
//                               padding: const EdgeInsets.all(4),
//                               decoration: BoxDecoration(
//                                   shape: BoxShape.circle,
//                                   color: styles.theme.green
//                                       .withValues(alpha: 0.1)),
//                               child: CircleAvatar(
//                                 radius: 3,
//                                 backgroundColor: styles.theme.green,
//                               ),
//                             ),
//                             const Gap(8),
//                             Flexible(
//                               child: Text(
//                                 foundLocationName,
//                                 maxLines: 2,
//                                 style: styles.typography.h3,
//                                 // '${_destinationEndPoint?.latitude ?? ""}, ${_destinationEndPoint?.longitude ?? ""} ',
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const Gap(18),
//                       Column(
//                         children: [
//                           const Icon(Icons.close_rounded).clickable(() {
//                             _toggleNotification(); //close the top panel
//                             _toggleRouteOptionStates(
//                               RouteFetchState.none,
//                             );
//                             _toggleStartTrip(false);
//                           }),
//                           const Gap(18),
//                           Assets.icons.startTrip.image(scale: 3).clickable(() {
//                             _toggleStartTrip(true);
//                           }),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           ///..........
//           ///

//           ///Mapsheet
//           if (_mRouteState == RouteFetchState.none)
//             Positioned.fill(
//               top: kToolbarHeight + MediaQuery.of(context).padding.top - 18,
//               child: MapSheet(
//                 controller: widget.controller,
//                 onSearchedDestination: (latLng) {
//                   _destinationEndPoint = latLng;
//                   getNameOfSelectedCoordinate(_destinationEndPoint);
//                   _fetchRoute();
//                   _toggleRouteOptionStates(
//                       RouteFetchState.searchingOutDestination);
//                   _toggleNotification(); //open the top panel
//                   ///move the camera to selected position
//                   _moveCamera(_destinationEndPoint!);

//                   // searched
//                 },
//                 mapPolyKey: widget.mapPolyKey,
//               ),
//             ),
//         ],
//       ),
//       floatingActionButton: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           FloatingActionButton(
//             onPressed: () {
//               _toggleRouteOptionStates(RouteFetchState.nowInDestination);
//               _toggleDetails();
//             },
//             heroTag: 'add-report',
//             backgroundColor: styles.theme.yellow,
//             child: IconBtn(
//               icon: Assets.icons.alertTriangle,
//               onPressed: () => CustomDialogRoutes.showBottomSheet<bool>(
//                 context,
//                 const ReportEventModal(),
//               ),
//               semanticLabel: '',
//               bgColor: styles.theme.yellow,
//               color: styles.theme.black,
//             ),
//           ),
//           const SizedBox(height: 10),
//           if (routeData != null && routeData!.isNotEmpty)
//             FloatingActionButton(
//               onPressed: () {
//                 // _toggleRouteOptionPanel(); //close the ;
//                 ///
//                 _toggleRouteOptionStates(RouteFetchState.nowInDestination);
//                 _toggleDetails();
//               },
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

//   Future<void> drawRouteForSelected(int index) async {
//     debugPrint('drawRouteForSelected called with index: $index');

//     final selectedRoute = availableRoutes[index];
//     // Use the selected route directly, not the whole response structure
//     final coords = (selectedRoute['legs'][0]['coordinates'] as List)
//         .map<LatLng>((c) => LatLng(c[1] as double, c[0] as double))
//         .toList();

//     // Remove previous lines/markers as in _drawRoute
//     if (_routeLine != null) await mapController?.removeLine(_routeLine!);
//     if (_startSymbol != null) await mapController?.removeSymbol(_startSymbol!);
//     if (_endSymbol != null) await mapController?.removeSymbol(_endSymbol!);
//     if (_startCircle != null) await mapController?.removeCircle(_startCircle!);
//     if (_endCircle != null) await mapController?.removeCircle(_endCircle!);

//     polylineCoords = coords;
//     _routeLine = await mapController?.addLine(
//       LineOptions(
//         geometry: coords,
//         lineColor: '#3b82f6',
//         lineWidth: 6,
//         lineOpacity: 0.9,
//       ),
//     );
//     _startCircle = await mapController?.addCircle(
//       CircleOptions(
//         geometry: coords.first,
//         circleRadius: 8,
//         circleColor: '#4CAF50',
//         circleStrokeColor: '#FFFFFF',
//         circleStrokeWidth: 2,
//         circleOpacity: 0.9,
//       ),
//     );
//     try {
//       _endSymbol = await mapController?.addSymbol(
//         SymbolOptions(
//           geometry: coords.last,
//           iconImage: 'end-marker',
//           iconSize: 0.2,
//           iconAnchor: 'bottom',
//         ),
//       );
//     } catch (_) {}

//     // Rotate the map to face the user's heading (if available)
//     if (_currentLocation != null &&
//         _userHeading != null &&
//         mapController != null) {
//       final currentZoom = mapController!.cameraPosition?.zoom ?? 15.0;
//       await mapController!.animateCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: _currentLocation!,
//             zoom: currentZoom,
//             bearing: _userHeading!,
//             tilt: mapController!.cameraPosition?.tilt ?? 0,
//           ),
//         ),
//         duration: const Duration(milliseconds: 800),
//       );
//     } else {
//       // fallback: fit the camera to show the route
//       await _fitCameraToBounds(coords);
//     }
//   }

//   Future<void> _fitCameraToBounds(List<LatLng> coords) async {
//     if (coords.isEmpty || mapController == null) return;

//     final southwest = LatLng(
//       coords.map((c) => c.latitude).reduce((a, b) => a < b ? a : b),
//       coords.map((c) => c.longitude).reduce((a, b) => a < b ? a : b),
//     );
//     final northeast = LatLng(
//       coords.map((c) => c.latitude).reduce((a, b) => a > b ? a : b),
//       coords.map((c) => c.longitude).reduce((a, b) => a > b ? a : b),
//     );

//     // Calculate bottom padding based on screen height and bottom sheet height
//     final screenHeight = MediaQuery.of(context).size.height;
//     final bottomSheetHeight = screenHeight * 0.45; // 45% as in your sheet
//     final padding = EdgeInsets.fromLTRB(
//       32, // left
//       80, // top
//       32, // right
//       bottomSheetHeight + 32, // bottom
//     );

//     await mapController!.animateCamera(
//       CameraUpdate.newLatLngBounds(
//         LatLngBounds(southwest: southwest, northeast: northeast),
//         left: padding.left,
//         top: padding.top,
//         right: padding.right,
//         bottom: padding.bottom,
//       ),
//     );
//   }
// }

// class RouteOptionPanel extends StatelessWidget {
//   const RouteOptionPanel(
//       {required this.onClose,
//       required this.onClickGetDirection,
//       required this.title,
//       required this.onClickStartTrip,
//       super.key,
//       required this.mRouteState});
//   final VoidCallback onClose;
//   final VoidCallback onClickGetDirection;
//   final VoidCallback onClickStartTrip;
//   final String title;
//   final RouteFetchState mRouteState;

//   @override
//   Widget build(BuildContext context) {
//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: BlocConsumer<AuthBloc, AuthState>(
//         listener: (context, state) {},
//         builder: (context, state) {
//           return Container(
//             height: MediaQuery.of(context).size.height * 0.3,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//             ),
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     if (state is UserCoordinate)
//                       Expanded(
//                         child: Text(
//                           '$title ',
//                           // '${state.latitude} ${state.longitude} ',
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                               fontSize: 18, fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                     const Spacer(),
//                     const Icon(
//                       Icons.close_rounded,
//                       size: 24,
//                     ).clickable(onClose),
//                   ],
//                 ),
//                 const Divider(),
//                 Row(
//                   children: [
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(styles.corners.lg),
//                       child: ColoredBox(
//                         color: styles.theme.primary,
//                         child: Padding(
//                           padding: const EdgeInsets.all(8),
//                           child: Row(
//                             children: [
//                               const Icon(
//                                 Icons.directions,
//                                 size: 22,
//                                 color: Colors.white,
//                               ),
//                               const Gap(3),
//                               Text(
//                                 'Get Directions',
//                                 style: styles.typography.body.copyWith(
//                                   fontWeight: FontWeight.w700,
//                                   color: styles.theme.white,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ).clickable(onClickGetDirection),
//                     const Gap(10),
//                     if (mRouteState == RouteFetchState.foundDestination)
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(styles.corners.lg),
//                         child: ColoredBox(
//                           color: styles.theme.primary,
//                           child: Padding(
//                             padding: const EdgeInsets.all(8),
//                             child: Row(
//                               children: [
//                                 const Icon(
//                                   Icons.play_arrow,
//                                   size: 22,
//                                   color: Colors.white,
//                                 ),
//                                 const Gap(3),
//                                 Text(
//                                   'Start trip',
//                                   style: styles.typography.body.copyWith(
//                                     fontWeight: FontWeight.w700,
//                                     color: styles.theme.white,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ).clickable(onClickStartTrip),
//                   ],
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// class RouteDetailsPanel extends StatelessWidget {
//   const RouteDetailsPanel({
//     required this.summary,
//     required this.maneuvers,
//     required this.onClose,
//     super.key,
//   });
//   final Map<String, dynamic> summary;
//   final List<dynamic> maneuvers;
//   final VoidCallback onClose;

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
//                 const Text(
//                   'Route Details',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
//               ],
//             ),
//             const Divider(),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildInfo(
//                   Icons.timer,
//                   'Duration',
//                   summary['formattedTime'] as String,
//                 ),
//                 _buildInfo(
//                   Icons.map,
//                   'Distance',
//                   summary['formattedDistance'] as String,
//                 ),
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
//                     title: Text(m['instruction'] as String),
//                     subtitle: Text(
//                       '${(m['distanceMeters'] / 1000).toStringAsFixed(1)} km, ${_formatSeconds(m['timeSeconds'] as num)}',
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

//   Widget _buildInfo(IconData icon, String label, String value) {
//     return Column(
//       children: [
//         Icon(icon),
//         Text(label, style: const TextStyle(fontSize: 12)),
//         Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
//       ],
//     );
//   }

//   String _formatSeconds(num seconds) {
//     final minutes = (seconds / 60).floor();
//     final secs = (seconds % 60).floor();
//     return '${minutes}m ${secs}s';
//   }
// }
