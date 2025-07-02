import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sheet/sheet.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/dashboard/view/place_details_screen.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/route_selection_widget.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
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
        onSave: () {
          Navigator.of(contxt).pop();
        },
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
                                                  .textColor(
                                                      styles.theme.primary)
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
                              // Saved locations section
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
}