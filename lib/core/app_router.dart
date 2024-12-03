import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class ScreenPaths {
  static String splash = '/splash';
  static String intro = '/intro';
  static String welcome = '/welcome';
  static String home = '/';
}

final navigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  navigatorKey: navigatorKey,
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, router, navigator) {
        return AppScaffold(child: navigator);
      },
      routes: const <RouteBase>[],
    ),
  ],
);
