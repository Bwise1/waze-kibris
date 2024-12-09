import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class ScreenPaths {
  static String home = '/';
}

final navigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: ScreenPaths.home,
  routes: <RouteBase>[
    RouteWrapper(
      ScreenPaths.home,
      (state) => const CounterPage(),
      name: 'home',
    ),
  ],
);
