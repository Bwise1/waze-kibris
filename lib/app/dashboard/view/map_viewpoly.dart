import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sheet/sheet.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';

enum RouteFetchState {
  none,
  foundDestination,
  searchingOutDestination,
  nowInDestination
}

class MapPolyScreen extends StatefulWidget {
  const MapPolyScreen({required this.controller, super.key});
  static const String routeName = '/map';
  // final ValueChanged<RouteFetchState> onRouteStateChanged;
  final SheetController controller;
  @override
  State<MapPolyScreen> createState() => _MapPolyScreenState();
}

class _MapPolyScreenState extends State<MapPolyScreen> {
  MaplibreMapController? mapController;
  LatLng? _currentLocation;
  bool _isLoading = false;
  bool _mapReady = false;
  bool _showRouteDetails = false;
  bool _markersLoaded = false;

  // bool _showRouteOptionPanel = false;
  // bool _showStartEndDisplayPanel = false;
  RouteFetchState _mRouteState = RouteFetchState.none;

  late LatLng? _destinationEndPoint;
  String foundLocationName = 'Destination';
  String stadiaApiKey = '8a83c0b9-fbe3-4caa-98d5-d8b60efc67c5';
  static const backendUrl = 'https://waze-api.benjys.me/route';

  Map<String, dynamic>? routeData;
  Line? _routeLine;
  Symbol? _startSymbol;
  Symbol? _endSymbol;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      _showPermissionDialog();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      if (context.mounted) {
        context.read<ReportsBloc>().add(
              ReportsEvent.getNearByReports(
                radius: 5,
                lat: _currentLocation!.latitude.toString(),
                long: _currentLocation!.longitude.toString(),
              ),
            );
      }
      if (_mapReady) {
        _moveCamera(_currentLocation!);
        //
        // await _fetchRoute();
      }
    } catch (e) {
      _showSnackBar('Failed to get location');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _moveCamera(LatLng target) {
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 15)),
    );
  }

  Future<void> _loadMarkerImages() async {
    if (_markersLoaded) return;

    try {
      // Load start marker PNG
      final startMarkerData =
          await rootBundle.load('assets/currentPosition.png');
      await mapController?.addImage(
          'start-marker', startMarkerData.buffer.asUint8List());

      // Load end marker PNG
      final endMarkerData = await rootBundle.load('assets/endlocation_pin.png');
      await mapController?.addImage(
          'end-marker', endMarkerData.buffer.asUint8List());

      _markersLoaded = true;
    } catch (e) {
      debugPrint('Error loading marker images: $e');
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Request-Source': 'postman'
        },
        body: jsonEncode({
          'locations': [
            {
              'lat': _currentLocation?.latitude,
              'lon': _currentLocation?.longitude,
            },
            {
              'lat': _destinationEndPoint?.latitude,
              'lon': _destinationEndPoint?.longitude,
            },
            // {"lat": 35.221906, "lon": 33.417018},
          ],
          // 'costing': 'auto',
          // 'units': 'kilometers',
          // 'directions_options': {'narrative': true},
        }),
      );

      if (response.statusCode == 200) {
        routeData = jsonDecode(response.body) as Map<String, dynamic>;
        if (_mapReady) {
          _drawRoute();
        }
      } else {
        throw Exception('Failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(':::::::::::Error fetching route: $e');
      _showSnackBar('Error fetching route ');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Replace your _drawRoute() method with this implementation
  void _drawRoute() async {
    if (mapController == null || routeData == null) return;
    await _loadMarkerImages();
    // Clear previous route
    if (_routeLine != null) {
      mapController?.removeLine(_routeLine!);
    }
    if (_startSymbol != null) {
      mapController?.removeSymbol(_startSymbol!);
    }
    if (_endSymbol != null) {
      mapController?.removeSymbol(_endSymbol!);
    }

    final coords =
        (routeData!['data']['trip']['legs'][0]['coordinates'] as List)
            .map<LatLng>((c) => LatLng(c[1] as double, c[0] as double))
            .toList();

    // Draw the route line first
    _routeLine = await mapController?.addLine(
      LineOptions(
        geometry: coords,
        lineColor: '#3b82f6',
        lineWidth: 5,
        lineOpacity: 0.8,
      ),
    );

    // Add start point as a circle (will always be visible)
    await mapController?.addCircle(CircleOptions(
      geometry: coords.first,
      circleRadius: 8,
      circleColor: '#4CAF50', // Green for start
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2,
      circleOpacity: 0.9,
    ));

    // Add end point as a circle (will always be visible)
    await mapController?.addCircle(CircleOptions(
      geometry: coords.last,
      circleRadius: 8,
      circleColor: '#F44336', // Red for destination
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 2,
      circleOpacity: 0.9,
    ));

    // Try to add symbols as well (as a backup)
    try {
      // Add start marker using PNG
      _startSymbol = await mapController?.addSymbol(SymbolOptions(
        geometry: coords.first,
        iconImage: 'start-marker',
        iconSize: 1, // Adjust this value based on your PNG size
        iconAnchor: 'bottom', // Position the marker correctly
      ));

      // Add end marker using PNG
      _endSymbol = await mapController?.addSymbol(SymbolOptions(
        geometry: coords.last,
        iconImage: 'end-marker',
        iconSize: 1, // Adjust this value based on your PNG size
        iconAnchor: 'bottom', // Position the marker correctly
      ));
    } catch (e) {
      debugPrint('Error adding symbols: $e');
      // If symbols fail, we still have circles as markers
    }

    _fitBounds(coords);
  }

  void _fitBounds(List<LatLng> coords) {
    if (coords.isEmpty) return;

    var minLat = coords.first.latitude, maxLat = coords.first.latitude;
    var minLon = coords.first.longitude, maxLon = coords.first.longitude;

    for (var c in coords) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLon) minLon = c.longitude;
      if (c.longitude > maxLon) maxLon = c.longitude;
    }

    mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        // padding: 80,
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Needed'),
        content: const Text('Location access is needed for routing.'),
        actions: [
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(ctx).pop();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onMapCreated(MapLibreMapController controller) async {
    mapController = controller;
    setState(() => _mapReady = true);

    await _loadMarkerImages();

    if (_currentLocation != null) {
      _moveCamera(_currentLocation!);
    }
    if (routeData != null) {
      _drawRoute();
    }

    mapController?.onSymbolTapped.add(tapSymbols);
  }

  void _toggleDetails() {
    setState(() => _showRouteDetails = !_showRouteDetails);
  }

  void _toggleRouteOptionStates(RouteFetchState state) {
    _mRouteState = state;
    // widget.onRouteStateChanged(state);
    setState(() {});
  }

  String getIconOnMapByReportType(String reportType) {
    ///
    // try {
    //   // Load marker PNG
    //   final ByteData startMarkerData =
    //       await rootBundle.load('assets/currentPosition.png');
    //   await mapController?.addImage(
    // 'start-marker', startMarkerData.buffer.asUint8List());
    ///
    //
    // _markersLoaded = true;

    // } catch (e) {
    // debugPrint('Error loading marker images: $e');
    // }

    if (reportType == ReportType.police.name) {
      return Assets.icons.police.path;
    }
    if (reportType == ReportType.traffic.name) {
      return Assets.icons.policeCar.path;
    }
    if (reportType == ReportType.accident.name) {
      return Assets.icons.accident.path;
    } else {
      return Assets.icons.pointMarker.path;
    }
  }

  void _populateMapWithReportsPoints(
      List<ReportData> reports, BuildContext context) {
    final symbols = reports.map((ReportData? report) {
      if (report != null) {
        return SymbolOptions(
          geometry: LatLng(report.latitude, report.longitude),
          iconImage: getIconOnMapByReportType(
            report.type.toLowerCase().trim(),
          ),
          iconSize: 0.2,
          textOffset: const Offset(0, 2),
          textField: report.type,
          textSize: 12,
        );
      }
      return SymbolOptions.defaultOptions;
    }).toList();

    mapController!.addSymbols(symbols);
    setState(() {});
  }

  void tapSymbols(Symbol symbol) {
    _toggleRouteOptionStates(RouteFetchState.foundDestination);
    if (_mRouteState == RouteFetchState.foundDestination) {
      _destinationEndPoint = symbol.options.geometry!;

      ///move the camera to selected position
      ///
      ///
      _moveCamera(_destinationEndPoint!);
    } else {
      _destinationEndPoint = null;
    }

    //wait after widget builds before call setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  Future<void> getNameOfSelectedCoordinate(LatLng? latLng) async {
    if (latLng != null) {
      await placemarkFromCoordinates(latLng.latitude, latLng.longitude)
          .then((placeMarks) {
        if (placeMarks.isNotEmpty) {
          foundLocationName =
              '${placeMarks.reversed.last.country} ${placeMarks.reversed.last.locality} ${placeMarks.reversed.last.street}';
          // output = placeMarks[0].toString();
          // debugPrint(placeMarks.toString());
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          BlocConsumer<ReportsBloc, ReportState>(
            listener: (context, state) {
              if (state is GetReportSuccess) {
                _populateMapWithReportsPoints(state.data, context);
              }
            },
            builder: (context, state) {
              return MapLibreMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentLocation ?? const LatLng(37.7749, -122.4194),
                  zoom: 10,
                ),
                styleString:
                    'https://tiles-eu.stadiamaps.com/styles/outdoors.json?api_key=$stadiaApiKey',
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
                myLocationRenderMode: MyLocationRenderMode.compass,
                onStyleLoadedCallback: () {
                  //add symbol after style loaded successfully
                  mapController?.addSymbol(
                    SymbolOptions(
                      geometry:
                          _currentLocation ?? const LatLng(37.7749, -122.4194),
                      iconImage: Assets.icons.myLocation.path,
                      iconSize: 1,
                    ),
                  ); //
                },
              );
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_showRouteDetails && routeData != null)
            RouteDetailsPanel(
              summary:
                  routeData!['data']['trip']['summary'] as Map<String, dynamic>,
              maneuvers:
                  routeData!['data']['trip']['legs'][0]['maneuvers'] as List,
              onClose: _toggleDetails,
            ),

          //show the route option panel to navigate
          if (_mRouteState == RouteFetchState.foundDestination &&
              _destinationEndPoint != null)
            RouteOptionPanel(
              key: UniqueKey(),
              title: foundLocationName,
              onClose: () {
                _toggleRouteOptionStates(RouteFetchState.none);
              },
              onClickGetDirection: (_mRouteState ==
                          RouteFetchState.foundDestination &&
                      _destinationEndPoint != null)
                  ? () async {
                      // _destinationEndPoint = ;
                      // _destinationEndPoint = const LatLng(35.221906, 33.417018);
                      await getNameOfSelectedCoordinate(_destinationEndPoint);
                      await _fetchRoute();
                      _toggleRouteOptionStates(
                          RouteFetchState.searchingOutDestination);
                    }
                  : () {},
            ),

          ///top most panel
          if (_mRouteState == RouteFetchState.searchingOutDestination ||
              _mRouteState == RouteFetchState.nowInDestination)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: SafeArea(
                child: CustomContainer(
                  // height: 50,
                  width: context.widthPx,
                  color: styles.theme.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  borderRadius: BorderRadius.circular(styles.corners.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 15,
                                width: 15,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: styles.theme.green
                                        .withValues(alpha: 0.1)),
                                child: CircleAvatar(
                                  radius: 3,
                                  backgroundColor: styles.theme.green,
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top: 17,
                                child: CircleAvatar(
                                  radius: 2,
                                  backgroundColor: styles.theme.green,
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top: 25,
                                child: CircleAvatar(
                                  radius: 2,
                                  backgroundColor: styles.theme.green,
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top: 34,
                                child: CircleAvatar(
                                  radius: 2,
                                  backgroundColor: styles.theme.green,
                                ),
                              ),
                              Positioned(
                                left: 6,
                                top: 42,
                                child: CircleAvatar(
                                  radius: 2,
                                  backgroundColor: styles.theme.green,
                                ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          const Text(
                            'Your current location',
                            // '${_currentLocation?.latitude ?? ""}, ${_currentLocation?.longitude ?? ""}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          const Icon(Icons.close_rounded).clickable(() {
                            _toggleRouteOptionStates(
                              RouteFetchState.none,
                            );
                          }),
                        ],
                      ),
                      const Gap(5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: styles.theme.divider,
                        ),
                      ),
                      const Gap(5),
                      Row(
                        children: [
                          Icon(
                            Icons.pin_drop_rounded,
                            color: styles.theme.red,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              foundLocationName,
                              maxLines: 2,
                              // '${_destinationEndPoint?.latitude ?? ""}, ${_destinationEndPoint?.longitude ?? ""} ',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Gap(8),
                          const Spacer(),
                          const Icon(Icons.map_outlined)
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          ///Mapsheet
          if (_mRouteState == RouteFetchState.none)
            Positioned.fill(
              top: kToolbarHeight + MediaQuery.of(context).padding.top - 18,
              child: MapSheet(
                controller: widget.controller,
                onSearchedDestination: (latLng) {
                  _destinationEndPoint = latLng;
                  getNameOfSelectedCoordinate(_destinationEndPoint);
                  _fetchRoute();
                  _toggleRouteOptionStates(
                      RouteFetchState.searchingOutDestination);

                  ///move the camera to selected position
                  _moveCamera(_destinationEndPoint!);

                  // searched
                },
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (routeData != null)
            FloatingActionButton(
              onPressed: () {
                // _toggleRouteOptionPanel(); //close the ;
                _toggleRouteOptionStates(RouteFetchState.nowInDestination);
                _toggleDetails();
              },
              heroTag: 'route',
              child: const Icon(Icons.directions),
            ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            heroTag: 'location',
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}

class RouteOptionPanel extends StatelessWidget {
  const RouteOptionPanel(
      {required this.onClose,
      required this.onClickGetDirection,
      super.key,
      required this.title});
  final VoidCallback onClose;
  final VoidCallback onClickGetDirection;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {},
        builder: (context, state) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (state is UserCoordinate)
                      Expanded(child:Text(
                        '$title ',
                        // '${state.latitude} ${state.longitude} ',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),),

                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.close,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(styles.corners.lg),
                      child: ColoredBox(
                        color: styles.theme.primary,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.directions,
                                size: 22,
                                color: Colors.white,
                              ),
                              const Gap(8),
                              Text(
                                'Get Directions',
                                style: styles.typography.t3
                                    .textColor(styles.theme.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).clickable(onClickGetDirection),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class RouteDetailsPanel extends StatelessWidget {
  const RouteDetailsPanel({
    required this.summary,
    required this.maneuvers,
    required this.onClose,
    super.key,
  });
  final Map<String, dynamic> summary;
  final List<dynamic> maneuvers;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Route Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfo(
                  Icons.timer,
                  'Duration',
                  summary['formattedTime'] as String,
                ),
                _buildInfo(
                  Icons.map,
                  'Distance',
                  summary['formattedDistance'] as String,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: maneuvers.length,
                itemBuilder: (_, idx) {
                  final m = maneuvers[idx];
                  return ListTile(
                    leading: const Icon(Icons.navigation),
                    title: Text(m['instruction'] as String),
                    subtitle: Text(
                      '${(m['distanceMeters'] / 1000).toStringAsFixed(1)} km, ${_formatSeconds(m['timeSeconds'] as num)}',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatSeconds(num seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${minutes}m ${secs}s';
  }
}
