import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:sheet/sheet.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/dashboard/modals/report_modal.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
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
            top: kToolbarHeight + MediaQuery.of(context).padding.top - 8,
            child: MapSheet(
              controller: controller,
            ),
          ),
        ],
      ),
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton(
          onPressed: () {
            // _toggleRouteOptionStates(RouteFetchState.nowInDestination);
            // _toggleDetails();
          },
          heroTag: 'add-report',
          backgroundColor: styles.theme.yellow,
          child: IconBtn(
            icon: Assets.icons.alertTriangle,
            onPressed: () => CustomDialogRoutes.showBottomSheet<bool>(
              context,
              const ReportEventModal(),
            ),
            semanticLabel: '',
            bgColor: styles.theme.yellow,
            color: styles.theme.black,
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 10),
        FloatingActionButton(
          // onPressed: _getCurrentLocation,
          onPressed: () {},
          heroTag: 'location',
          child: const Icon(Icons.my_location),
        ),
      ]),
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
  Timer? _debounceTimer;
  List<AutocompleteSuggestion> stadiaSuggestions = [];
  final PlacesService _placesService = PlacesService();

  List<SearchSuggestion> _suggestions = [];

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        isSearching = false;
      });
      return;
    }

    setState(() => isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        // Get user's current location (replace with your actual values)
        final position = await Geolocator.getCurrentPosition();
        final results = await _placesService.fetchGoogleAutocomplete(
          query,
          lat: position.latitude,
          lon: position.longitude,
          radius: 5000,
        );

        setState(() {
          _suggestions = results ?? [];

          isSearching = false;
        });
      } catch (e) {
        debugPrint('Error fetching suggestions: $e');
        setState(() {
          _suggestions = [];
          isSearching = false;
        });
      }
    });
  }

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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: styles.insets.sm,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: styles.theme.background,
                                            borderRadius:
                                                BorderRadius.circular(32),
                                          ),
                                          child: Row(
                                            children: [
                                              AppIcon(
                                                Assets.icons.location,
                                                color: styles.theme.red,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Current location',
                                                style: styles.typography.t2
                                                    .textColor(
                                                        styles.theme.text),
                                              ),
                                            ],
                                          ),
                                        ),
                                        CustomSearchBar(
                                          controller: destinationController,
                                          onChanged: (v) {
                                            _onSearchChanged(v);
                                            if (widget.controller.animation
                                                    .value <=
                                                0.3) {
                                              widget.controller
                                                  .relativeAnimateTo(
                                                0.9,
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                curve: Curves.easeOut,
                                              );
                                            }
                                          },
                                          onClear: () {
                                            destinationController.clear();
                                            setState(() {
                                              stadiaSuggestions = [];
                                            });
                                          },
                                          onFocus: () {
                                            if (widget.controller.animation
                                                    .value <=
                                                0.3) {
                                              widget.controller
                                                  .relativeAnimateTo(
                                                0.9,
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                curve: Curves.easeOut,
                                              );
                                            }
                                          },
                                        ),
                                        if (_suggestions.isNotEmpty)
                                          SearchSuggestionList(
                                            suggestions: _suggestions,
                                            onTap: (suggestion) {
                                              // Handle suggestion tap here
                                              debugPrint(
                                                  'Suggestion tapped: ${suggestion.mainText}');
                                              // You can call your _onSuggestionSelected(suggestion) if you want
                                            },
                                          ),
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
                                  Gap(styles.insets.sm),
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
                                    'recent Locations',
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
