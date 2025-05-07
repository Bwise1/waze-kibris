import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/utils/user_coordinates.dart';

class MapLibriGlPolyLinePropertySource {
  const MapLibriGlPolyLinePropertySource({required this.data, this.type = ''});
  final String type;
  final Map<String, dynamic> data;
}

//
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? mapController;
  bool _isMapReady = false;
  bool _isLocating = false;
  LatLng? _currentLocation;
  final double _initialZoom = 15.0;
  String stadiaApiKey = '8a83c0b9-fbe3-4caa-98d5-d8b60efc67c5';
  ScreenshotController screenshotController = ScreenshotController();

  List<List<double>> _polylinePoints = [
    [5.51778, 6.045185], // New York
    [35.2049704, 33.317932], // New York
    [35.221906, 33.417018], // New York

    // [5.51778, 6.045185], // New York
    // [4.0060, 3.7128], // Lower Manhattan

    // [-73.9857, 40.7484], // New York
    // [-74.0060, 40.7128],
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getNearReport(context);
  }

  Future<void> _getNearReport(BuildContext context) async {
    final position = await UserCoordinates.getAndSetUserCoordinate(
      context,
    );
    if (context.mounted) {
      context.read<ReportsBloc>().add(
            ReportsEvent.getNearByReports(
              radius: 50,
              lat: position!.latitude.toString(),
              long: position.longitude.toString(),
            ),
          );
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      await _getCurrentLocation();
    } else {
      _showLocationPermissionDialog();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLocating = true);

    try {
      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });

      if (_isMapReady) _animateToUserLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  void _animateToUserLocation() {
    if (_currentLocation == null || mapController == null) return;

    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: _initialZoom),
      ),
    );

    // Add user location marker

    mapController!.addSymbol(
      SymbolOptions(
        geometry: _currentLocation,
        iconImage: Assets.images.profilePic.keyName,
        iconSize: 1.5,
      ),
    );
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission'),
        content: const Text('This app needs location permission to function.'),
        actions: [
          const TextButton(
            onPressed: openAppSettings,
            child: Text('Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
    setState(() => _isMapReady = true);

    if (_currentLocation != null) {
      _animateToUserLocation();
    }

    // Configure location tracking
    controller.updateMyLocationTrackingMode(MyLocationTrackingMode.trackingGps);
    mapController?.onSymbolTapped.add(tapSymbols);
    // tapSymbols();
  }

  String getIconOnMapByReportType(String reportType) {
    print(reportType);
    if (reportType == ReportType.police.name) {
      // final imageBytes = await screenshotController.captureFromWidget(
      //   IconImageMakerWidget(
      //     iconObject: Assets.icons.police.image(),
      //   ),
      // );
      ///
      // await mapController?.addImage(
      //   ReportType.police.name.toLowerCase(),
      //   imageBytes,
      // );
      return Assets.icons.police.path;
    }
    if (reportType == ReportType.traffic.name) {
      // final imageBytes = await screenshotController.captureFromWidget(
      //   IconImageMakerWidget(
      //     iconObject: Assets.icons.policeCar.image(),
      //   ),
      // );
      // await mapController?.addImage(
      //   ReportType.traffic.name.toLowerCase(),
      //   imageBytes,
      // );
      return Assets.icons.policeCar.path;
    }
    if (reportType == ReportType.accident.name) {
      // final imageBytes = await screenshotController.captureFromWidget(
      //   IconImageMakerWidget(
      //     iconObject: Assets.icons.policeCar.image(),
      //   ),
      // );
      // await mapController?.addImage(
      //   ReportType.traffic.name.toLowerCase(),
      //   imageBytes,
      // );
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
          textField: report.type,
          geometry: LatLng(report.latitude, report.longitude),
          iconImage: getIconOnMapByReportType(
            report.type.toLowerCase().trim(),
          ),
          iconSize: 0.3,
        );
      }
      return SymbolOptions.defaultOptions;
    }).toList();

    mapController!.addSymbols(symbols);
    setState(() {});
  }

  tapSymbols(Symbol symbol) async {
    // CustomDialogRoutes.showBottomSheet<bool>(
    //   context,
    //   Column(
    //     mainAxisSize: MainAxisSize.min,
    //     crossAxisAlignment: CrossAxisAlignment.start,
    //     children: [
    //       Text(
    //         '{icon.options.textField} '
    //         'Report',
    //         style: styles.typography.body,
    //         // .textColor(styles.theme.text),
    //       ),
    //       Gap(4 * styles.scale),
    //       Wrap(
    //         crossAxisAlignment: WrapCrossAlignment.center,
    //         children: [
    //           Text(
    //             'ID:',
    //             style: styles.typography.t3.textColor(styles.theme.caption),
    //           ),
    //           Text(
    //             ' ...',
    //             style: styles.typography.t1,
    //             // .textColor(styles.theme.divider),
    //           ),
    //         ],
    //       ),
    //     ],
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    const defaultLocation = LatLng(37.7749, -122.4194); // SF as fallback

    return Scaffold(
      body: Stack(
        children: [
          BlocConsumer<ReportsBloc, ReportState>(
            listener: (context, state) {
              if (state is GetReportSuccess) {
                _populateMapWithReportsPoints(state.data, context);
              }
            }, //
            builder: (context, state) {
              return MapLibreMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentLocation ?? defaultLocation,
                  zoom: _initialZoom,
                ),
                styleString:
                    'https://tiles-eu.stadiamaps.com/styles/alidade_smooth.json?api_key=$stadiaApiKey',
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
                myLocationRenderMode: MyLocationRenderMode.compass,
                onStyleLoadedCallback: () {
                  //add symbol after style loaded successfully
                  mapController?.addSymbol(
                    SymbolOptions(
                      geometry: const LatLng(37.7749, -122.4194),
                      iconImage: Assets.icons.location,
                      iconSize: 1,
                    ),
                  );
                },
              );
            },
          ),
          if (_isLocating) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}
