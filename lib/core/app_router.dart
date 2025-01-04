import 'package:flutter/material.dart';
import 'package:waze_kibris/app/auth/auth.dart';
import 'package:waze_kibris/app/dashboard/view/main_dashboard.dart';
import 'package:waze_kibris/common.dart';

class ScreenPaths {
  static String home = '/';
  static String getStarted = '/get-started';
  static String verifyEmail = '/verify-email';
  static String signIn = '/sign-in';
  static String dashBoard = '/dashboard';
}

final navigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation: ScreenPaths.home,
  routes: <RouteBase>[
    RouteWrapper(
      ScreenPaths.home,
      (state) => const OnboardScreen(),
      name: 'home',
    )
    ,RouteWrapper(
      ScreenPaths.getStarted,
      (state) => const GettingStarted(),
      name: 'getStarted',
    ),

    RouteWrapper(
      ScreenPaths.verifyEmail,
      (state) => const EmailVerification(),
      name: 'verifyEmail',
    ),

    RouteWrapper(
      ScreenPaths.signIn,
      (state) => const SignInScreen(),
      name: 'signIn',
    ), RouteWrapper(
      ScreenPaths.dashBoard,
      (state) => const MainDashboard(),
      name: 'dashBoard',
    ),
  ],
);
