import 'package:flutter/material.dart';
import 'package:waze_kibris/app/auth/views/getting_started.dart';
import 'package:waze_kibris/common.dart';

class ScreenPaths {
  static String home = '/';
  static String getStarted = '/getStarted';
}

final navigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: ScreenPaths.home,
  routes: <RouteBase>[
    RouteWrapper(
      ScreenPaths.home,
      (state) => const OnboardScreen(),
      name: 'home',
    ),RouteWrapper(
      ScreenPaths.getStarted,
      (state) => const GettingStarted(),
      name: 'getStarted',
    ),
  ],
);
