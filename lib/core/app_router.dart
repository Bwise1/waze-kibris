import 'package:flutter/material.dart';
import 'package:waze_kibris/app/auth/auth.dart';
import 'package:waze_kibris/app/dashboard/view/main_dashboard.dart';
import 'package:waze_kibris/common.dart';

import '../app/profile/view/personal_information.dart';
import '../app/profile/view/sound_settings.dart';
import '../app/profile/view/update_username.dart';

class ScreenPaths {
  static String home = '/';
  static String getStarted = '/getStarted';
  static String verifyEmail = '/verifyEmail';
  static String signIn = '/signIn';
  static String dashBoard = '/dashBoard';
  static String personalInformation = '/personalInformation';
  static String updateUserName = '/updateUserName';
  static String soundSettings = '/soundSettings';
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
    ),

    RouteWrapper(
      ScreenPaths.dashBoard,
      (state) => const MainDashboard(),
      name: 'dashBoard',
    ),

    RouteWrapper(
      ScreenPaths.personalInformation,
      (state) => const PersonalInformationScreen(),
      name: 'personalInformation',
    ),

    RouteWrapper(
      ScreenPaths.updateUserName,
      (state) => const UpdateUsernameScreen(),
      name: 'updateUserName',
    ),

    RouteWrapper(
      ScreenPaths.soundSettings,
      (state) => const SoundSettingsScreen(),
      name: 'soundSettings',
    ),
  ],
);
