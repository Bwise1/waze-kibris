import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:sheet/sheet.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/places/places_response.dart';

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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey[200],
      appBar: MapAppBar(
        controller: controller,
      ),
      body: Stack(
        children: [
          mp.MapWidget(
            key: const ValueKey('mapWidget'),
            onMapCreated: _onMapCreated,
          ),
          Positioned.fill(
            top: kToolbarHeight + MediaQuery.of(context).padding.top - 18,
            child: MapSheet(
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }
}

class MapSheet extends StatefulWidget {
  const MapSheet(
      {required this.controller,
      // required this.mapPolyKey,
      this.onSearchedDestination,
      super.key});
  final SheetController controller;
  final ValueChanged<LatLng>? onSearchedDestination;
  // final GlobalKey<MapPolyScreenState> mapPolyKey;

  @override
  State<MapSheet> createState() => _MapSheetState();
}

class _MapSheetState extends State<MapSheet> {
  final TextEditingController destinationController = TextEditingController();

  LatLng? foundLocation;
  String foundLocationName = '';
  List<Map<String, dynamic>> suggestions = [];
  bool isSearching = false;
  static const String backendBaseUrl = 'https://waze-api.benjys.me';
  final Dio _dio = Dio();
  Timer? _debounceTimer;
  List<AutocompleteSuggestion> stadiaSuggestions = [];
  final PlacesService _placesService = PlacesService();

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        stadiaSuggestions = [];
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    // Set new timer with 300ms delay
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _placesService.fetchSuggestions(query);
        setState(() {
          stadiaSuggestions = results ?? []; // Handle potential null
          isSearching = false;
          print('Suggestions fetched: ${stadiaSuggestions.length} items');
        });
      } catch (e) {
        debugPrint('Error fetching suggestions: $e');
        setState(() {
          stadiaSuggestions = [];
          isSearching = false;
        });
      }
    });
  }

  // void getCoordinateFromTextAddress() {
  //   // locationFromAddress("1600 Amphitheatre Parkway, Mountain View")
  //   locationFromAddress(destinationController.text).then((locations) {
  //     var output = 'No results found.';
  //     if (locations.isNotEmpty) {
  //       foundLocation = LatLng(locations.reversed.last.latitude,
  //           locations.reversed.last.longitude);
  //       output = locations[0].toString();

  //       /// get the name of found location
  //       getNameOfSelectedCoordinate(foundLocation);

  //       debugPrint(output);
  //       setState(() {
  //         // _output = output;
  //       });
  //     }
  //   });
  // }

  // void _handleStartTrip() {
  //   widget.mapPolyKey.currentState?.startTrip();
  // }

  // void getNameOfSelectedCoordinate(LatLng? latLng) {
  //   // late String outPut;

  //   if (latLng != null) {
  //     placemarkFromCoordinates(latLng.latitude, latLng.longitude)
  //         .then((placeMarks) {
  //       if (placeMarks.isNotEmpty) {
  //         foundLocationName =
  //             '${placeMarks.reversed.last.country} ${placeMarks.reversed.last.locality}';
  //         // output = placeMarks[0].toString();
  //         // debugPrint("......$outPut");
  //       }
  //     });
  //   }
  //   setState(() {});
  //   // return outPut;
  // }

  // Future<void> _onSuggestionSelected(AutocompleteSuggestion suggestion) async {
  //   setState(() {
  //     isSearching = true;
  //     stadiaSuggestions = []; // Clear suggestions immediately
  //   });

  //   try {
  //     // Fetch detailed place information using the gid
  //     final placeDetails =
  //         await _placesService.fetchPlaceDetails(suggestion.id);

  //     if (placeDetails != null && placeDetails['coordinates'] != null) {
  //       setState(() {
  //         foundLocation = placeDetails['coordinates'] as LatLng;
  //         foundLocationName = placeDetails['name'] as String? ??
  //             suggestion.name ??
  //             suggestion.description;
  //         isSearching = false;
  //       });
  //       // LatLng coordinates = placeDetails['coordinates'] as LatLng;
  //       // await mapPolyKey.currentState?.fetchRoutesForLocation(coordinates);

  //       // Show location details bottom sheet (like Waze)
  //       await showModalBottomSheet(
  //         context: context,
  //         isScrollControlled: true,
  //         backgroundColor: Colors.transparent,
  //         builder: (context) => LocationDetailsBottomSheet(
  //           suggestion: suggestion,
  //           placeDetails: placeDetails,
  //           onGetRoute: _showRouteSelection,
  //           onSave: () {
  //             _saveLocation(suggestion, placeDetails);
  //           },
  //           onRouteSelected: (routeIndex) {
  //             debugPrint('Route selected: $routeIndex');
  //             debugPrint(
  //                 'mapPolyKey.currentState: ${widget.mapPolyKey.currentState}');
  //             widget.mapPolyKey.currentState?.drawRouteForSelected(routeIndex);
  //           },
  //           onStartTrip: _handleStartTrip,
  //         ),
  //       );

  //       // After the LocationDetailsBottomSheet is dismissed,
  //       // collapse the MapSheet to its initial extent.
  //       await widget.controller.animateTo(
  //         120.0, // Use the actual initialExtent value
  //         duration: const Duration(milliseconds: 300),
  //         curve: Curves.easeOut,
  //       );
  //     } else {
  //       // Fallback if place details fail or no coordinates
  //       setState(() {
  //         foundLocationName = suggestion.name ?? suggestion.description;
  //         isSearching = false;
  //       });

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Could not get location coordinates')),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('Error fetching place details: $e');

  //     // Fallback on error
  //     setState(() {
  //       foundLocationName = suggestion.name ?? suggestion.description;
  //       isSearching = false;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Could not get place details: $e')),
  //     );
  //   }
  // }

  // Future<void> _showRouteSelection() async {
  //   // For now, just call the existing callback
  //   if (widget.onSearchedDestination != null && foundLocation != null) {
  //     widget.onSearchedDestination!(foundLocation!);
  //   }

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text('Getting route to $foundLocationName...'),
  //       action: SnackBarAction(
  //         label: 'Navigate',
  //         onPressed: () {
  //           // This is where you'd navigate to the map with route
  //         },
  //       ),
  //     ),
  //   );
  // }

  void _saveLocation(
      AutocompleteSuggestion suggestion, Map<String, dynamic>? placeDetails) {
    // Handle saving location to favorites/saved locations
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${placeDetails?['name'] ?? suggestion.name} saved to favorites!'),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sheet(
      backgroundColor: Colors.transparent,
      initialExtent: 120,
      controller: widget.controller,
      physics: const SnapSheetPhysics(
        stops: <double>[0.3, 1],
      ),
      child: AnimatedBuilder(
        animation: widget.controller.animation,
        builder: (BuildContext context, Widget? child) {
          final sheetBar = widget.controller.animation.value > 0.95;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: sheetBar ? 1 : 0),
            duration: const Duration(milliseconds: 200),
            builder: (BuildContext context, double t, Widget? child) {
              final radius = Tween<double>(begin: 16, end: 0).transform(t);

              final shadow = ColorTween(
                begin: Colors.black26,
                end: Colors.black26.withValues(alpha: 0),
              ).transform(t);
              final barColor = ColorTween(
                begin: Colors.grey[200],
                end: Colors.grey[200]?.withValues(alpha: 0),
              ).transform(t);
              return MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(radius),
                      topRight: Radius.circular(radius),
                    ),
                    color: Colors.white,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: shadow!, blurRadius: 12),
                    ],
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        width: 36,
                        height: 4,
                        color: barColor,
                        alignment: Alignment.center,
                      ),
                      Expanded(
                        child: ListView(
                          shrinkWrap: true,
                          primary: true,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: styles.insets.md,
                                vertical: styles.insets.sm,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    // height: 100,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: styles.insets.sm,
                                    ),
                                    // decoration: BoxDecoration(
                                    //   color: styles.theme.background,
                                    //   borderRadius: BorderRadius.circular(8),
                                    // ),

                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CustomTextField(
                                          hintText: 'Going somewhere?',
                                          controller: destinationController,
                                          onChanged: (v) {
                                            // getCoordinateFromTextAddress();

                                            _onSearchChanged(v);
                                            if (widget.controller.animation
                                                    .value <=
                                                0.3) {
                                              widget.controller
                                                  .relativeAnimateTo(
                                                0.9,
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                curve: Curves.easeOut,
                                              );
                                            }
                                          },
                                          prefix: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                height: 45,
                                                width: 45,
                                                child: isSearching
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2),
                                                      )
                                                    : AppIcon(
                                                        Assets
                                                            .icons.searchGlass,
                                                        color:
                                                            styles.theme.grey,
                                                        size: 18,
                                                      ),
                                              ),
                                              Text(
                                                '|',
                                                style: styles.typography.h4
                                                    .textColor(
                                                        styles.theme.ash),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // if (stadiaSuggestions.isNotEmpty) ...[
                                        //   Gap(styles.insets.md),
                                        //   ...stadiaSuggestions.map(
                                        //       (suggestion) => LocationItem(
                                        //             appIcon:
                                        //                 Assets.icons.location,
                                        //             title: suggestion.name ??
                                        //                 suggestion.description,
                                        //             sub: suggestion.location !=
                                        //                     null
                                        //                 ? '${suggestion.location}'
                                        //                 : '',
                                        //           ).clickable(() =>
                                        //               _onSuggestionSelected(
                                        //                   suggestion))),
                                        //   Divider(
                                        //     thickness: 0.8,
                                        //     color: styles.theme.divider,
                                        //   ),
                                        // ],
                                        if (foundLocation != null &&
                                            foundLocationName.isNotEmpty)
                                          Gap(styles.insets.md),
                                        if (foundLocation != null &&
                                            foundLocationName.isNotEmpty)
                                          LocationItem(
                                            appIcon: Assets.icons.location,
                                            title: foundLocationName,
                                            sub:
                                                '${foundLocation?.latitude.toString()} , ${foundLocation?.longitude.toString()}',
                                          ).clickable(() {
                                            if (widget.onSearchedDestination !=
                                                    null &&
                                                foundLocation != null) {
                                              widget.onSearchedDestination!(
                                                  foundLocation!);
                                            }
                                          }),
                                        if (foundLocation != null &&
                                            foundLocationName.isNotEmpty)
                                          Divider(
                                            thickness: 0.8,
                                            color: styles.theme.divider,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Gap(24),
                                  const LocationItem(
                                    title: 'Home',
                                    sub: 'No 123, Main Street, Lagos',
                                  ),
                                  const LocationItem(
                                    title: 'Home',
                                    sub: 'No 1  Gura topp rayfield Jos Nigeria',
                                  ),
                                  CustomTextField(
                                    hintText: 'Email address',
                                    prefix: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 45,
                                          width: 45,
                                          child: AppIcon(
                                            Assets.icons.coordinate,
                                            color: styles.theme.grey,
                                            size: 18,
                                          ),
                                        ),
                                        Text(
                                          '|',
                                          style: styles.typography.h4
                                              .textColor(styles.theme.ash),
                                        ),
                                      ],
                                    ),
                                  ),
                                  CustomTextField(
                                    hintText: 'Email new destination',
                                    prefix: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 45,
                                          width: 45,
                                          child: AppIcon(
                                            Assets.icons.searchGlass,
                                            color: styles.theme.grey,
                                            size: 18,
                                          ),
                                        ),
                                        Text(
                                          '|',
                                          style: styles.typography.h4
                                              .textColor(styles.theme.ash),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Gap(styles.insets.md),
                                ],
                              ),
                            ),
                            CustomHorizontalScroll(
                              child: Row(
                                children: [
                                  Gap(styles.insets.md),
                                  ...List.generate(
                                    10,
                                    (index) => Container(
                                      width: 69,
                                      height: 74,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: styles.theme.background,
                                        borderRadius: BorderRadius.circular(
                                          styles.corners.sm,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AppIcon(
                                            Assets.icons.homeSmile,
                                            color: styles.theme.primary,
                                          ),
                                          const Gap(4),
                                          Text(
                                            'Home',
                                            style: styles.typography.t3
                                                .textColor(styles.theme.primary)
                                                .medium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Gap(styles.insets.md),
                            CustomContainer(
                              width: context.widthPx,
                              padding: EdgeInsets.symmetric(
                                horizontal: styles.insets.lg,
                              ),
                              borderRadius: BorderRadius.circular(
                                styles.corners.lg,
                              ),
                              color: styles.theme.background,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Gap(styles.insets.md),
                                  Text(
                                    'Saved Locations',
                                    style: styles.typography.h4
                                        .textColor(styles.theme.text),
                                  ),
                                  Gap(styles.insets.md),
                                  ProfileActionItemButton(
                                    onPressed: () {},
                                    icon: Assets.icons.homeSmile,
                                    title: 'Home',
                                    subTitle: 'Address',
                                    semanticLabel: 'home-action-btn',
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      color: styles.theme.secondary,
                                    ),
                                  ),
                                  ProfileActionItemButton(
                                    icon: Assets.icons.briefcase,
                                    title: 'Office',
                                    subTitle: 'Address',
                                    semanticLabel: 'office-action-btn',
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Divider(
                                      color: styles.theme.secondary,
                                    ),
                                  ),
                                  ProfileActionItemButton(
                                    onPressed: () {},
                                    icon: Assets.icons.plus,
                                    title: 'Add new location',
                                    semanticLabel: 'add-action-btn',
                                  ),
                                  Gap(styles.insets.md),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MapAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MapAppBar({required this.controller, super.key});
  final SheetController controller;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  State<MapAppBar> createState() => _MapAppBarState();
}

class _MapAppBarState extends State<MapAppBar> {
  bool scrolled = false;
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.animation.addListener(() {
        final animationValue = widget.controller.animation.value;
        if (animationValue > 0.3) {
          setState(() {
            scrolled = true;
          });
        } else {
          setState(() {
            scrolled = false;
          });
        }
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1), // Start outside the top of the screen
            end: Offset.zero, // Slide into position
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: scrolled
          ? AppBar(
              key: const ValueKey('scrolled'),
              elevation: 1,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              automaticallyImplyLeading: false,
              leadingWidth: 50 + styles.insets.sm,
              leading: BackBtn.close(
                onPressed: () async {
                  await widget.controller.relativeAnimateTo(
                    0.3,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                },
              ).padding(left: 16, top: 4),
            )
          : AnimatedBuilder(
              key: const ValueKey('nonScrolled'),
              animation: widget.controller.animation,
              builder: (BuildContext context, Widget? child) {
                final sheetBar = widget.controller.animation.value > 0.98;
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: sheetBar ? 1 : 0),
                  duration: const Duration(milliseconds: 200),
                  builder: (BuildContext context, double t, Widget? child) {
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: 1,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: context.mq.padding.top,
                        ),
                        height: kToolbarHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Assets.icons.spotifyPng.image(),
                            const SizedBox(),
                            // IconBtn(
                            //   icon: Assets.icons.alertTriangle,
                            //   onPressed: () =>
                            //       CustomDialogRoutes.showBottomSheet<bool>(
                            //     context,
                            //     const ReportEventModal(),
                            //   ),
                            //   semanticLabel: '',
                            //   bgColor: styles.theme.yellow,
                            //   color: styles.theme.black,
                            // ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class LocationItem extends StatelessWidget {
  const LocationItem(
      {required this.title, required this.sub, super.key, this.appIcon});
  final String title;
  final String sub;
  final String? appIcon;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: styles.theme.background,
              borderRadius: BorderRadius.circular(styles.corners.sm),
              boxShadow: styles.shadows.md,
            ),
            child: AppIcon(
              appIcon ?? Assets.icons.homeSmile,
              color: styles.theme.grey,
              size: 18,
            ),
          ),
          Gap(styles.insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: styles.insets.xxs,
              children: [
                Text(
                  title,
                  style:
                      styles.typography.t2.textColor(styles.theme.black).medium,
                ),
                Text(
                  sub,
                  style: styles.typography.t3.textColor(styles.theme.caption),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
