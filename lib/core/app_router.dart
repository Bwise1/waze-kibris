import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/routes/intro/onboard_screen.dart';
import 'package:waze_kibris/core/routes/intro/splash_screen.dart';

class ScreenPaths {
  static String home = '/';
}

final navigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: ScreenPaths.home,
  routes: <RouteBase>[
    RouteWrapper(
      ScreenPaths.home,
      (state) => const OnboardScreen(),
      name: 'home',
    ),
  ],
);
