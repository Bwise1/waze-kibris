import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:sheet/sheet.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/dashboard/view/map_viewpoly.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with TickerProviderStateMixin {
  late SheetController controller;
  RouteFetchState routeFetchState = RouteFetchState.none;
  @override
  void initState() {
    context.read<AuthBloc>().add(
          AuthEvent.getUserCoordinateRequested(
            context: context,
            onCallBack: (latLng) {
              //on call back successful call the get nearby reports
              context.read<ReportsBloc>().add(
                    ReportsEvent.getNearByReports(
                      radius: 5,
                      lat: latLng.latitude.toString(),
                      long: latLng.longitude.toString(),
                    ),
                  );
            },
          ),
        );

    print("latLng");

    //call to get user coordinate

    controller = SheetController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey[200],
      appBar: MapAppBar(controller: controller),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            // child: Test(),
            child: MapPolyScreen(
              // onRouteStateChanged: (state) {
              //   routeFetchState = state;
              //   setState(() {});
              // },
              controller: controller,
            ),
          ),

          ///
          // FloatingButtons(controller: controller),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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

class FloatingButtons extends StatelessWidget {
  const FloatingButtons({required this.controller, super.key});
  final SheetController controller;
  @override
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height =
        mediaQuery.size.height - mediaQuery.padding.top - kToolbarHeight;
    return AnimatedBuilder(
      animation: controller.animation,
      builder: (BuildContext context, Widget? child) {
        return Positioned(
          right: 0,
          left: 0,
          bottom: height * min(0.3, controller.animation.value),
          child: Container(
            margin: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  height: 65,
                  width: 45,
                  decoration: BoxDecoration(
                    color: styles.theme.grey,
                    borderRadius: BorderRadius.circular(styles.corners.sm),
                    boxShadow: styles.shadows.md,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '0',
                        style: styles.typography.h2
                            .textColor(styles.theme.white)
                            .semi,
                      ),
                      Text(
                        'km/h',
                        style: styles.typography.t3
                            .textColor(styles.theme.white)
                            .semi,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IconBtn(
                  icon: Assets.icons.coordinate,
                  semanticLabel: 'My location',
                  color: styles.theme.white,
                  onPressed: () {
                    controller.relativeAnimateTo(
                      0.1,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeIn,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MapSheet extends StatefulWidget {
  MapSheet({required this.controller, this.onSearchedDestination, super.key});
  final SheetController controller;
  final ValueChanged<LatLng>? onSearchedDestination;

  @override
  State<MapSheet> createState() => _MapSheetState();
}

class _MapSheetState extends State<MapSheet> {
  final TextEditingController destinationController = TextEditingController();

  LatLng? foundLocation;
  String foundLocationName = '';

  void getCoordinateFromTextAddress() {
    // locationFromAddress("1600 Amphitheatre Parkway, Mountain View")
    locationFromAddress(destinationController.text).then((locations) {
      var output = 'No results found.';
      if (locations.isNotEmpty) {
        foundLocation = LatLng(locations.reversed.last.latitude,
            locations.reversed.last.longitude);
        output = locations[0].toString();

        /// get the name of found location
        getNameOfSelectedCoordinate(foundLocation);

        debugPrint(output);
        setState(() {
          // _output = output;
        });
      }
    });
  }

  void getNameOfSelectedCoordinate(LatLng? latLng) {
    // late String outPut;

    if (latLng != null) {
      placemarkFromCoordinates(latLng.latitude, latLng.longitude)
          .then((placeMarks) {
        if (placeMarks.isNotEmpty) {
          foundLocationName =
              '${placeMarks.reversed.last.country} ${placeMarks.reversed.last.locality}';
          // output = placeMarks[0].toString();
          // debugPrint("......$outPut");
        }
      });
    }
    setState(() {});
    // return outPut;
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
                                            getCoordinateFromTextAddress();
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
                                                child: AppIcon(
                                                  Assets.icons.searchGlass,
                                                  color: styles.theme.grey,
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

                                    // child: Row(
                                    //   spacing: styles.insets.sm,
                                    //   children: [
                                    //     AppIcon(
                                    //       Assets.icons.globe,
                                    //       color: styles.theme.grey,
                                    //     ),
                                    //     Text(
                                    //       'Going somewhere?',
                                    //       style: styles.typography.t2
                                    //           .textColor(styles.theme.grey)
                                    //           .medium,
                                    //     ),
                                    //     Expanded(
                                    //       child: Container(),
                                    //     ),
                                    //     AppIcon(
                                    //       Assets.icons.arrowForward,
                                    //       color: styles.theme.grey,
                                    //     ),
                                    //   ],
                                    // ),
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
