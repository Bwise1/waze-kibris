import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:sheet/sheet.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/modals/report_modal.dart';
import 'package:waze_kibris/app/dashboard/view/map_app_bar.dart';
import 'package:waze_kibris/app/dashboard/view/map_controller_mixin.dart';
import 'package:waze_kibris/app/dashboard/view/map_sheet.dart';
import 'package:waze_kibris/app/dashboard/view/navigation_overlay.dart';
import 'package:waze_kibris/app/dashboard/view/route_bar.dart';
import 'package:waze_kibris/app/dashboard/view/route_overview.dart';
import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/dialog_route.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';
import 'package:waze_kibris/core/models/places/places_response.dart';
import 'package:waze_kibris/core/widgets/buttons/app_button.dart';
import 'package:waze_kibris/app/dashboard/view/map_controller_mixin.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<StatefulWidget> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with TickerProviderStateMixin, MapControllerMixin {
  late SheetController controller;
  late NavigationBloc _navigationBloc;
  SearchSuggestion? _activeRouteSuggestion;

  @override
  NavigationBloc get navigationBloc => _navigationBloc;

  @override
  void initState() {
    super.initState();
    _navigationBloc = NavigationBloc();
    setupPositionTracking();
    controller = SheetController();
  }

  @override
  void dispose() {
    _navigationBloc.close();
    super.dispose();
  }

  void _onSuggestionSelected(SearchSuggestion suggestion) {
    setState(() {
      _activeRouteSuggestion = suggestion;
    });
  }

  void _clearRouteBar() {
    setState(() {
      _activeRouteSuggestion = null;
    });
  }

  void _startNavigation(DirectionsRoute route) {
    _navigationBloc.add(NavigationStarted(route: route));
    setIsFollowingUser(true);

    // Initialize snap-to-road with route data
    initializeSnapToRoad(route);

    // Close the sheet when navigation starts
    controller.relativeAnimateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    // Update map for navigation mode
    updateMapForNavigationMode(true);
  }

  void _endNavigation() {
    _navigationBloc.add(NavigationStopped());
    updateMapForNavigationMode(false);
    clearRoutePolyline();
    clearSnapToRoad();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _navigationBloc,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.grey[200],
        // Fixed AppBar issue - wrap BlocBuilder in PreferredSize
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: BlocBuilder<NavigationBloc, NavigationState>(
            builder: (context, state) {
              // Hide app bar during navigation
              if (state is NavigationInProgress && !state.isOverviewVisible) {
                return AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: 0,
                  automaticallyImplyLeading: false,
                );
              }
              return MapAppBar(controller: controller);
            },
          ),
        ),
        body: BlocListener<NavigationBloc, NavigationState>(
          listener: (context, state) {
            if (state is NavigationInProgress) {
              // Handle navigation state changes
              if (state.isNavigationComplete) {
                _showNavigationCompleteDialog();
              }
            }
          },
          child: BlocBuilder<NavigationBloc, NavigationState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // Map widget
                  mp.MapWidget(
                    key: const ValueKey('mapWidget'),
                    onMapCreated: onMapCreated,
                  ),

                  // Show route bar if there's an active suggestion and not navigating
                  if (_activeRouteSuggestion != null &&
                      state is! NavigationInProgress)
                    Positioned(
                      top: kToolbarHeight +
                          MediaQuery.of(context).padding.top -
                          100,
                      left: 16,
                      right: 16,
                      child: RouteBar(
                        start: "Current Location",
                        end: _activeRouteSuggestion!.mainText,
                        onCancel: _clearRouteBar,
                      ),
                    ),

                  // Show navigation UI when in navigation mode
                  if (state is NavigationInProgress) ...[
                    if (state.isOverviewVisible)
                      RouteOverviewWidget(
                        navigationState: state,
                        onBackToNavigation: () {
                          _navigationBloc.add(NavigationOverviewToggled());
                          setIsFollowingUser(true);
                        },
                      )
                    else
                      NavigationOverlay(
                        navigationState: state,
                        onEndNavigation: _endNavigation,
                        onToggleOverview: () {
                          _navigationBloc.add(NavigationOverviewToggled());
                          if (!state.isOverviewVisible) {
                            // Switching to overview mode
                            setIsFollowingUser(false);
                          } else {
                            // Switching back to navigation mode
                            setIsFollowingUser(true);
                          }
                        },
                      ),
                  ],

                  // Show bottom sheet only when not navigating
                  if (state is! NavigationInProgress)
                    Positioned.fill(
                      top: kToolbarHeight +
                          MediaQuery.of(context).padding.top -
                          8,
                      child: MapSheet(
                        controller: controller,
                        onSuggestionSelected: _onSuggestionSelected,
                        onDrawPolyline: drawPolyline,
                        onStartNavigation: _startNavigation,
                        context: context,
                      ),
                    ),

                  // Re-center button during navigation
                  if (state is NavigationInProgress && !state.isOverviewVisible)
                    Positioned(
                      right: 16,
                      bottom: 120,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          setIsFollowingUser(true);
                        },
                        backgroundColor: isFollowingUser
                            ? styles.theme.primary
                            : Colors.white,
                        child: Icon(
                          Icons.my_location,
                          color: isFollowingUser
                              ? Colors.white
                              : styles.theme.primary,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: BlocBuilder<NavigationBloc, NavigationState>(
          builder: (context, state) {
            // Hide FABs during navigation
            if (state is NavigationInProgress) {
              return const SizedBox.shrink();
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    CustomDialogRoutes.showBottomSheet<bool>(
                      context,
                      const ReportEventModal(),
                    );
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
                FloatingActionButton(
                  onPressed: () {
                    setIsFollowingUser(true);
                  },
                  heroTag: 'location',
                  backgroundColor:
                      isFollowingUser ? styles.theme.primary : Colors.white,
                  child: Icon(
                    Icons.my_location,
                    color:
                        isFollowingUser ? Colors.white : styles.theme.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showNavigationCompleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🎉 Destination Reached!'),
          content:
              const Text('You have successfully reached your destination.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _endNavigation();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
