import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/app/dashboard/view/map_sheet.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/location/recent_location.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/di.dart';

/// Full-screen search page.
///
/// All visual design is copied verbatim from the expanded [MapSheet] state.
/// The only difference is the container: a plain [Scaffold] with
/// [resizeToAvoidBottomInset: true], which lets Flutter handle keyboard insets
/// natively so the search bar is never pushed off-screen.
class SearchPage extends StatefulWidget {
  const SearchPage({
    required this.onSuggestionTap,
    required this.onSavedLocationTap,
    required this.onAddLocationTapped,
    super.key,
  });

  final void Function(SearchSuggestion) onSuggestionTap;
  final void Function(SavedLocations) onSavedLocationTap;
  final void Function(String? specificType) onAddLocationTapped;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController destinationController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<SearchSuggestion> _suggestions = [];
  bool isSearching = false;
  Timer? _debounceTimer;
  final PlacesService _placesService = getIt<PlacesService>();

  List<RecentLocation> _recentLocations = [];
  bool _recentLocationsLoading = false;
  int _recentBuildCounter = 0;

  List<SavedLocations> _savedLocations = [];

  @override
  void initState() {
    super.initState();
    // Request keyboard focus after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
    // Trigger data fetch
    _getSavedLocations();
    _getRecentLocations();
  }

  void _getSavedLocations() {
    if (mounted) {
      context.read<ReportsBloc>().add(ReportsEvent.getSavedLocations());
    }
  }

  void _getRecentLocations() {
    if (mounted) {
      context.read<ReportsBloc>().add(ReportsEvent.getRecentLocations());
    }
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

        if (mounted) {
          setState(() {
            _suggestions = results ?? [];
            isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching suggestions: $e');
        if (mounted) {
          setState(() {
            _suggestions = [];
            isSearching = false;
          });
        }
      }
    });
  }

  void _handleSuggestionTap(SearchSuggestion suggestion) {
    Navigator.of(context).pop();
    widget.onSuggestionTap(suggestion);
  }

  void _handleSavedLocationTap(SavedLocations location) {
    Navigator.of(context).pop();
    widget.onSavedLocationTap(location);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    destinationController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReportsBloc, ReportState>(
      listener: (context, state) {
        if (state is GetRecentLocationsSuccess) {
          setState(() {
            _recentLocations = state.data;
            _recentLocationsLoading = false;
            _recentBuildCounter++;
          });
        } else if (state is RecentLocationsLoading) {
          setState(() {
            _recentLocationsLoading = true;
            _recentBuildCounter++;
          });
        } else if (state is GetSavedLocationsSuccess) {
          setState(() {
            _savedLocations = state.data;
          });
        }
      },
      child: Scaffold(
        // KEY: resizeToAvoidBottomInset: true means Flutter natively shrinks
        // the body when the keyboard appears, keeping the search bar visible.
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // ── Close / back row ───────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                  left: styles.insets.sm,
                  top: styles.insets.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BackBtn.close(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

              // ── Fixed header: location pill + search bar ───────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: styles.insets.md,
                  vertical: styles.insets.sm,
                ),
                child: Column(
                  children: [
                    // Search bar — auto-focused via FocusNode
                    CustomSearchBar(
                      controller: destinationController,
                      focusNode: _searchFocusNode,
                      onChanged: (v) => _onSearchChanged(v),
                      onClear: () {
                        destinationController.clear();
                        setState(() {
                          _suggestions = [];
                        });
                      },
                      onFocus: () {},
                    ),
                  ],
                ),
              ),

              // ── Scrollable content area ────────────────────────────────
              Expanded(
                child: ListView(
                  primary: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // While typing → show suggestions
                    if (_suggestions.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: styles.insets.md,
                        ),
                        child: SearchSuggestionList(
                          suggestions: _suggestions,
                          onTap: _handleSuggestionTap,
                        ),
                      ),

                    // While searching (loading indicator)
                    if (isSearching && _suggestions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    // Default state → saved + recent locations
                    if (_suggestions.isEmpty && !isSearching) ...[
                      Gap(styles.insets.sm),
                      CustomHorizontalScroll(
                        child: Row(
                          children: [Gap(styles.insets.md)],
                        ),
                      ),
                      Container(
                        width: context.widthPx,
                        padding: EdgeInsets.symmetric(
                          horizontal: styles.insets.lg,
                        ),
                        decoration: BoxDecoration(
                          color: styles.theme.background,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(styles.corners.lg),
                            topRight: Radius.circular(styles.corners.lg),
                          ),
                        ),
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

                            // Saved locations horizontal row
                            BlocConsumer<ReportsBloc, ReportState>(
                              listener: (context, state) {
                                if (state is SaveLocationSuccess) {
                                  RSnackBar.success(
                                    'Location has been successfully saved.',
                                  ).show(context);
                                  context.read<ReportsBloc>().add(
                                        ReportsEvent.getSavedLocations(),
                                      );
                                }
                              },
                              builder: (context, state) {
                                if (state is ReportLoading) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final savedLocations = _savedLocations;

                                final homeLocation = savedLocations
                                    .firstWhereOrNull((e) =>
                                        e.name.toLowerCase() == 'home');
                                final workLocation = savedLocations
                                    .firstWhereOrNull((e) =>
                                        e.name.toLowerCase() == 'work');
                                final otherLocations =
                                    _filterAddedLocation(savedLocations);

                                return SizedBox(
                                  height: 80,
                                  width: context.widthPx,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    children: [
                                      SavedLocationCard(
                                        title: 'Home',
                                        icon: Assets.icons.homeSmile,
                                        subtitle: (homeLocation != null)
                                            ? (homeLocation.address != null &&
                                                    homeLocation
                                                        .address!.isNotEmpty)
                                                ? homeLocation.address!
                                                : 'Tap to navigate'
                                            : 'Add Home',
                                        isSaved: homeLocation != null,
                                        placeId: homeLocation?.placeId,
                                        onTap: () {
                                          if (homeLocation != null) {
                                            _handleSavedLocationTap(
                                                homeLocation);
                                          } else {
                                            _handleAddLocationTapped('Home');
                                          }
                                        },
                                      ),
                                      const Gap(12),
                                      SavedLocationCard(
                                        title: 'Work',
                                        icon: Assets.icons.briefcaseSvg,
                                        subtitle: (workLocation != null)
                                            ? (workLocation.address != null &&
                                                    workLocation
                                                        .address!.isNotEmpty)
                                                ? workLocation.address!
                                                : 'Tap to navigate'
                                            : 'Add Work',
                                        isSaved: workLocation != null,
                                        placeId: workLocation?.placeId,
                                        onTap: () {
                                          if (workLocation != null) {
                                            _handleSavedLocationTap(
                                                workLocation);
                                          } else {
                                            _handleAddLocationTapped('Work');
                                          }
                                        },
                                      ),
                                      const Gap(12),
                                      ...otherLocations.map(
                                        (location) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 12),
                                          child: SavedLocationCard(
                                            title: location.name,
                                            icon: _getIconType(location.name),
                                            subtitle: location.address ?? '',
                                            isSaved: true,
                                            isImageFile: true,
                                            placeId: location.placeId,
                                            onTap: () =>
                                                _handleSavedLocationTap(
                                                    location),
                                          ),
                                        ),
                                      ),
                                      SavedLocationCard(
                                        title: 'Add',
                                        icon: Assets.icons.plusSvg,
                                        subtitle: 'New',
                                        isSaved: false,
                                        onTap: () =>
                                            _handleAddLocationTapped(null),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            Gap(styles.insets.md),
                            Text(
                              'Recent Locations',
                              style: styles.typography.h4
                                  .textColor(styles.theme.text),
                            ),
                            Gap(styles.insets.md),

                            // Recent locations list
                            SizedBox(
                              height: 300,
                              child: _SearchRecentLocationsWidget(
                                locations: _recentLocations,
                                isLoading: _recentLocationsLoading,
                                buildCounter: _recentBuildCounter,
                              ),
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
      ),
    );
  }

  // ── Helpers (mirrors _MapSheetState helpers) ─────────────────────────────

  List<SavedLocations> _filterAddedLocation(List<SavedLocations> locations) {
    final savedLocations = <SavedLocations>[];
    final nameTypeChecker = <String>[];
    for (final e in locations) {
      if (e.name.toLowerCase() == 'home' || e.name.toLowerCase() == 'work') {
        continue;
      }
      if (!nameTypeChecker.contains(e.name) && e.placeId != null) {
        savedLocations.add(e);
        nameTypeChecker.add(e.name);
      }
    }
    return savedLocations;
  }

  String _getIconType(String type) {
    if (type == 'Home') return Assets.icons.homeBg.path;
    if (type == 'Hospital') return Assets.icons.hospital.path;
    if (type == 'Park') return Assets.icons.park.path;
    if (type == 'Gas') return Assets.icons.gas.path;
    if (type == 'Food') return Assets.icons.food.path;
    if (type == 'Work') return Assets.icons.briefcasePng.path;
    return Assets.icons.globePng.path;
  }

  /// Shows the "add location" modal directly from this page's context
  /// (the modal sits on top of this search page, which is fine — it's just
  /// a save-data UI and doesn't need to be on the map).
  void _handleAddLocationTapped(String? specificType) {
    widget.onAddLocationTapped(specificType);
  }
}

// ── Private helper widgets (mirrors map_sheet.dart private widgets) ─────────

class _SearchRecentLocationsWidget extends StatelessWidget {
  const _SearchRecentLocationsWidget({
    required this.locations,
    required this.isLoading,
    required this.buildCounter,
  });

  final List<RecentLocation> locations;
  final bool isLoading;
  final int buildCounter;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (locations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No recent locations yet',
            style: styles.typography.t3
                .textColor(styles.theme.text.withOpacity(0.6)),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemCount: locations.length,
      itemExtent: 54,
      itemBuilder: (context, index) {
        final location = locations[index];
        return _SearchRecentLocationItem(
          key: ValueKey(location.placeId),
          location: location,
          showDivider: index < locations.length - 1,
        );
      },
    );
  }
}

class _SearchRecentLocationItem extends StatelessWidget {
  const _SearchRecentLocationItem({
    required this.location,
    required this.showDivider,
    super.key,
  });

  final RecentLocation location;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (location.iconType != null &&
                      location.iconType!.endsWith('.svg'))
                    AppIcon(location.iconType!, size: 20)
                  else if (location.iconType != null &&
                      location.iconType!.endsWith('.png'))
                    Image.asset(
                      location.iconType!,
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) =>
                          AppIcon(Assets.icons.recentPlaces, size: 20),
                    )
                  else
                    _buildCategoryIcon(location.category ?? 'location'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: styles.typography.t2.medium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (location.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            location.address,
                            style: styles.typography.t3.textColor(
                              styles.theme.text.withOpacity(0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Divider(
                color: styles.theme.secondary,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(String type) {
    final path = _getIconPath(type);
    if (path.endsWith('.svg')) {
      return AppIcon(path, size: 20);
    }
    return Image.asset(
      path,
      width: 20,
      height: 20,
      errorBuilder: (context, error, stackTrace) =>
          AppIcon(Assets.icons.recentPlaces, size: 20),
    );
  }

  String _getIconPath(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Assets.icons.homeBg.path;
      case 'hospital':
      case 'medical':
        return Assets.icons.hospital.path;
      case 'park':
        return Assets.icons.park.path;
      case 'gas':
      case 'fuel':
        return Assets.icons.gas.path;
      case 'food':
      case 'restaurant':
        return Assets.icons.food.path;
      case 'location':
      default:
        return Assets.icons.recentPlaces;
    }
  }
}
