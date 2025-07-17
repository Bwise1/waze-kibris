import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sheet/sheet.dart';
import 'package:waze_kibris/app/dashboard/view/place_details_screen.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/route_selection_widget.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';
import 'package:waze_kibris/core/models/places/places_response.dart';

class MapSheet extends StatefulWidget {
  const MapSheet({
    required this.controller,
    required this.context,
    this.onSearchedDestination,
    this.onSuggestionSelected,
    this.onDrawPolyline,
    this.onStartNavigation,
    super.key,
  });

  final SheetController controller;
  final ValueChanged<LatLng>? onSearchedDestination;
  final ValueChanged<SearchSuggestion>? onSuggestionSelected;
  final BuildContext context;
  final void Function(String encodedPolyline)? onDrawPolyline;
  final void Function(DirectionsRoute route)? onStartNavigation;

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
  bool getLocationLoading = false;
  @override
  void initState() {
    super.initState();
    getSavedLocation(context);
  }

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

  Future<void> _onSuggestionTap(SearchSuggestion suggestion) async {
    widget.onSuggestionSelected?.call(suggestion);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.relativeAnimateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });

    final details = await _placesService.fetchGooglePlace(suggestion.placeId);

    if (!widget.context.mounted) return;

    await showModalBottomSheet(
      context: widget.context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (contxt) => PlaceDetailsSheet(
        key: UniqueKey(),
        title: details.name,
        address: details.formattedAddress,
        distanceKm: suggestion.distanceMeters / 1000,
        onSave: () async {
          // debugPrint(suggestion.placeId);
          // debugPrint("${details.placeId}...................."); ////
          // print("......................object");
          await showModalBottomSheet(
            context: widget.context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (modalContext) => SelectAndSaveLocation(
              position: LatLng(details.lat, details.lng),
            ),
          );
        }, //
        onShare: () {
          Navigator.of(contxt).pop();
        },
        onMore: () {
          Navigator.of(contxt).pop();
        },
        onSeeAllRoutes: () async {
          final position = await Geolocator.getCurrentPosition();

          final directions = await _placesService.fetchGoogleDirections(
            originLat: position.latitude,
            originLng: position.longitude,
            destinationPlaceId: details.placeId,
          );

          Navigator.of(contxt).pop();
          debugPrint('Directions fetched: ${directions.routes.length} routes');
          if (directions.routes.isNotEmpty) {
            final String encodedPolyline =
                directions.routes.first.overviewPolyline.points;

            widget.onDrawPolyline?.call(encodedPolyline);
          }

          await showModalBottomSheet(
            context: widget.context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (modalContext) => RouteSelectionSheet(
              routes: directions.routes,
              onRouteSelected: (selectedRoute) {
                widget.onDrawPolyline?.call(
                  selectedRoute.overviewPolyline.points,
                );
              },
              onStartNavigation: (selectedRoute) {
                widget.onStartNavigation?.call(selectedRoute);
              },
            ),
          );
        },
        info: details.website,
      ),
    );
  }

  Future<void> getSavedLocation(BuildContext context) async {
    if (context.mounted) {
      context.read<ReportsBloc>().add(
            ReportsEvent.getSavedLocations(),
          );
    }
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
                                  // Current location pill
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: styles.theme.background,
                                      borderRadius: BorderRadius.circular(32),
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
                                              .textColor(styles.theme.text),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Search bar
                                  CustomSearchBar(
                                    controller: destinationController,
                                    onChanged: (v) {
                                      _onSearchChanged(v);
                                      if (widget.controller.animation.value <=
                                          0.3) {
                                        widget.controller.relativeAnimateTo(
                                          0.9,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          curve: Curves.easeOut,
                                        );
                                      }
                                    },
                                    onClear: () {
                                      destinationController.clear();
                                      setState(() {
                                        _suggestions = [];
                                      });
                                    },
                                    onFocus: () {
                                      if (widget.controller.animation.value <=
                                          0.3) {
                                        widget.controller.relativeAnimateTo(
                                          0.9,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          curve: Curves.easeOut,
                                        );
                                      }
                                    },
                                  ),
                                  // If suggestions, show only suggestions
                                  if (_suggestions.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: SearchSuggestionList(
                                        suggestions: _suggestions,
                                        onTap: (suggestion) {
                                          _onSuggestionTap(suggestion);
                                          debugPrint(
                                              'Suggestion tapped: ${suggestion.placeId}');
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Only show the rest if there are NO suggestions
                            if (_suggestions.isEmpty) ...[
                              Gap(styles.insets.sm),
                              CustomHorizontalScroll(
                                child: Row(
                                  children: [
                                    Gap(styles.insets.md),

                                    ///
                                    //         const Gap(4),
                                    //         Text(
                                    //           'Home',
                                    //           style: styles.typography.t3
                                    //               .textColor(
                                    //                   styles.theme.primary)
                                    //               .medium,
                                    //         ),
                                    //       ],
                                    //     ),
                                    //   ),
                                    // ),
                                  ],
                                ),
                              ),
                              Gap(styles.insets.md),
                              // Saved locations section
                              CustomContainer(
                                width: context.widthPx,
                                height: 400,
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

                                    ///.................................
                                    ///
                                    ///
                                    BlocConsumer<ReportsBloc, ReportState>(
                                      listener: (context, state) {
                                        if (state is GetSavedLocationsSuccess &&
                                            state.data.isEmpty) {
                                          RSnackBar.error(
                                            'you have no save location.',
                                          ).show(context);
                                        }
                                      },
                                      builder: (context, state) {
                                        if (state is ReportInitial) {
                                          return SizedBox();

                                          ///if the state of the bloc is in its initial stage ;
                                        } else if (state
                                                is GetSavedLocationsSuccess &&
                                            state.data.isNotEmpty) {
                                          return Expanded(
                                            child: ListView.builder(
                                              itemCount: state.data.length,
                                              itemBuilder: (context, index) {
                                                return Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 20),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      ProfileActionItemButton(
                                                        onPressed: () {},
                                                        isImageFile: true,
                                                        icon: getIconType(
                                                          state
                                                              .data[index].name,
                                                        ),
                                                        title: state
                                                            .data[index].name,
                                                        subTitle: state
                                                            .data[index]
                                                            .address,
                                                        semanticLabel:
                                                            'home-action-btn',
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 8,
                                                        ),
                                                        child: Divider(
                                                          color: styles
                                                              .theme.secondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ).clickable(() {
                                                  ///get some logic done here
                                                });
                                              },
                                            ),
                                          );
                                        } else if (state is ReportLoading) {
                                          return Expanded(
                                            child: Center(
                                              child: SizedBox(
                                                height: 40,
                                                width: 40,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: styles.theme.primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        } else {
                                          return const Expanded(
                                            child: SizedBox(),
                                            // child: Center(
                                            //   child: Column(
                                            //     mainAxisSize: MainAxisSize.min,
                                            //     children: [
                                            //
                                            //
                                            //       Gap(53 * styles.scale),
                                            //       TextButton(
                                            //         onPressed: () async {
                                            //           if (state is GetVotesOnReportSuccess) {
                                            //             // RSnackBar.error('Hey${state.data.length}')
                                            //             //     .show(context);
                                            //           } else {
                                            //             RSnackBar.error('Hey Nothing here').show(context);
                                            //           }
                                            //           final position =
                                            //           await UserCoordinates.getAndSetUserCoordinate(
                                            //             context,
                                            //           );
                                            //           RSnackBar.error(position!.longitude.toString())
                                            //               .show(context);
                                            //
                                            //           if (context.mounted) {
                                            //             // print(
                                            //             //   "${position!.latitude.toString()}"
                                            //             //   "${position.longitude.toString()}",
                                            //             // );
                                            //             // RSnackBar.error(
                                            //             //         "${position!.latitude.toString()} ${position.longitude.toString()}")
                                            //             //     .show(context);
                                            //             context.read<ReportsBloc>().add(
                                            //               ReportsEvent.getNearByReports(
                                            //                 radius: endRangeVal.toInt(),
                                            //                 lat: position!.latitude.toString(),
                                            //                 long: position.longitude.toString(),
                                            //               ),
                                            //             );
                                            //           }
                                            //         },
                                            //         style: TextButton.styleFrom(
                                            //           backgroundColor: styles.theme.divider,
                                            //         ),
                                            //         child: const Icon(
                                            //           size: 35,
                                            //           Icons.search_rounded,
                                            //           // color: styles.theme.grey,
                                            //         ),
                                            //       ),
                                            //     ],
                                            //   ),
                                            // ),
                                          );
                                        }
                                      },
                                    ),

                                    ///
                                    ///.................................

                                    Gap(styles.insets.md),
                                    Row(
                                      children: [
                                        ProfileActionItemButton(
                                          onPressed: () async {
                                            setState(() {
                                              getLocationLoading = true;
                                            });

                                            final position = await Geolocator
                                                .getCurrentPosition();
                                            setState(() {
                                              getLocationLoading = false;
                                            });
                                            await showModalBottomSheet(
                                              context: widget.context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (modalContext) =>
                                                  SelectAndSaveLocation(
                                                position: LatLng(
                                                    position.latitude,
                                                    position.longitude),
                                              ),
                                            );
                                          },
                                          icon: Assets.icons.plus,
                                          title: 'Add new location',
                                          semanticLabel: 'add-action-btn',
                                        ),
                                        if (getLocationLoading) ...[
                                          Gap(10),
                                          SizedBox(
                                              height: 15,
                                              width: 15,
                                              child: CustomLoader())
                                        ],
                                      ],
                                    ),
                                    Gap(styles.insets.md),
                                  ],
                                ),
                              ),
                              Gap(styles.insets.md),
                              // Recent locations section
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
                                      'Recent Locations',
                                      style: styles.typography.h4
                                          .textColor(styles.theme.text),
                                    ),
                                    Gap(styles.insets.md),
                                    ProfileActionItemButton(
                                      onPressed: () {},
                                      icon: Assets.icons.homeSmile,
                                      title: 'Recent Place 1',
                                      subTitle: 'Address',
                                      semanticLabel: 'recent-1-btn',
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
                                      title: 'Recent Place 2',
                                      subTitle: 'Address',
                                      semanticLabel: 'recent-2-btn',
                                    ),
                                    Gap(styles.insets.md),
                                  ],
                                ),
                              ),
                            ],
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

  String getIconType(String type) {
    if (type == 'Home') {
      return Assets.icons.homeBg.path;
    }
    if (type == 'Hospital') {
      return Assets.icons.hospital.path;
    }
    if (type == 'Park') {
      return Assets.icons.park.path;
    }
    if (type == 'Gas') {
      return Assets.icons.gas.path;
    }
    if (type == 'Food') {
      return Assets.icons.food.path;
    } else {
      return Assets.icons.homeBg.path;
    }
  }
}

class SelectAndSaveLocation extends StatefulWidget {
  const SelectAndSaveLocation({super.key, required this.position});
  final LatLng position;
  @override
  State<SelectAndSaveLocation> createState() => _SelectAndSaveLocationState();
}

class _SelectAndSaveLocationState extends State<SelectAndSaveLocation> {
  var locationName = '';
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(15),
          topLeft: Radius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: BlocConsumer<ReportsBloc, ReportState>(
            listener: (blocContext, state) {
              if (state is SaveLocationSuccess) {
                // print(".......................");
                RSnackBar.success(
                  'Location has been saved successfully.',
                ).show(context);
                Navigator.of(context).pop();
              }
            },
            builder: (context, state) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Gap(40),
                    Text(
                      'Select appropriate location Name',
                      style: styles.typography.h3.textColor(styles.theme.text),
                    ),
                    const Gap(20),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          const Gap(30),
                          LocationItem(
                            key: UniqueKey(),
                            onSelect: () {
                              setState(() {
                                locationName = 'Home';
                              });
                              // WidgetsBinding
                              //     .instance
                              //     .addPostFrameCallback(
                              //         (_) {
                              //   Navigator.of(
                              //           context)
                              //       .pop();
                              // });
                            },
                            image: Assets.icons.homeBg
                                .image(width: 35, height: 35),
                            bgImagePath: Assets.icons.homeBg.path,
                            locationName: 'Home',
                            isSelected: locationName == 'Home' ? true : false,
                          ),
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Gas';
                                });
                                // WidgetsBinding
                                //     .instance
                                //     .addPostFrameCallback(
                                //         (_) {
                                //   Navigator.of(context)
                                //       .pop();
                                // });
                              },
                              image:
                                  Assets.icons.gas.image(width: 35, height: 35),
                              bgImagePath: Assets.icons.gasBg.path,
                              locationName: 'Gas',
                              isSelected: locationName == 'Gas' ? true : false),
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Food';
                                });
                              },
                              image: Assets.icons.food
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.foodBg.path,
                              locationName: 'Food',
                              isSelected:
                                  locationName == 'Food' ? true : false),
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Hospital';
                                });
                              },
                              image: Assets.icons.hospital
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.hospitalBg.path,
                              locationName: 'Hospital',
                              isSelected:
                                  locationName == 'Hospital' ? true : false),
                          LocationItem(
                              key: UniqueKey(),
                              onSelect: () {
                                setState(() {
                                  locationName = 'Park';
                                });
                              },
                              image: Assets.icons.park
                                  .image(width: 35, height: 35),
                              bgImagePath: Assets.icons.parkBg.path,
                              locationName: 'Park',
                              isSelected:
                                  locationName == 'Park' ? true : false),
                        ],
                      ),
                    ),
                    const Gap(50),
                    PrimaryButton(
                      textColor: styles.theme.white,
                      isLoading: state is SaveLocationLoading,
                      onPressed: () {
                        if (locationName == '') {
                          RSnackBar.info(
                            'Please select a location name to save this location.',
                          );
                        } else {
                          context.read<ReportsBloc>().add(
                                ReportsEvent.saveLocation(
                                  locationName: locationName,
                                  lat: widget.position.latitude,
                                  lng: widget.position.longitude,
                                ),
                              );
                        }
                        // context.read<AuthBloc>().add(
                        //   AuthEvent.loginRequested(
                        //     email: _emailController.text,
                        //   ),
                        // );
                      },
                      text: 'Save',
                    ),
                  ]);
            },
          ),
        ),
      ),
    );
  }
}

class LocationItem extends StatelessWidget {
  const LocationItem({
    required this.onSelect,
    super.key,
    required this.image,
    required this.bgImagePath,
    required this.locationName,
    required this.isSelected,
  });
  final VoidCallback onSelect;
  final Widget image;
  final String bgImagePath;
  final String locationName;
  final bool isSelected;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        height: 371,
        width: 74,
        margin: EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: styles.theme.white,
          border: Border.all(color: const Color(0xffFFDBDB), width: 1.5),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? styles.theme.primary.withValues(alpha: 0.4)
                  : styles.theme.grey.withValues(alpha: 0.2),
              offset: const Offset(-0.4, 4),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
          image: DecorationImage(
              image: AssetImage(
                bgImagePath,
              ),
              fit: BoxFit.cover),
        ),
        duration: Duration(
          seconds: 8,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 351,
              width: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: image,
                ),
                const Gap(4),
                Text(
                  locationName,
                  style: styles.typography.t3.medium,
                ),
              ], //
            ),
          ],
        ),
      ),
    );
  }
}
