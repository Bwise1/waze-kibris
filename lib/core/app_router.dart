import 'package:flutter/material.dart';
import 'package:waze_kibris/app/profile/view/help_screen.dart';
import 'package:waze_kibris/app/profile/view/sound_settings.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

class ScreenPaths {
  static String home = '/';
  static String getStarted = '/get-started';
  static String verifyEmail = '/verify-email';
  static String signIn = '/sign-in';
  static String dashBoard = '/dashboard';

  static String personalInformation = '/personal-information';
  static String updateUserName = '/update-username';
  static String soundSettings = '/sound-settings';
  static String helpAndFeedback = '/help-and-feedback';
  static String addLocation = '/add-location';
  static String aboutUs = '/about-us';
  static String deleteAccount = '/delete-account';
}

final navigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  initialLocation:
      isEmptyOrNull(getIt<ILocalStorage>().get<String>(StoreKeys.wazeToken))
          ? ScreenPaths.home
          : ScreenPaths.dashBoard,
  navigatorKey: navigatorKey,
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, state, child) {
        return AppScaffold(child: child);
      },
      routes: [
        RouteWrapper(
          ScreenPaths.home,
          (state) => const OnboardScreen(),
          name: 'home',
        ),
        RouteWrapper(
          ScreenPaths.getStarted,
          (state) => const GettingStarted(),
          name: 'get-started',
        ),
        RouteWrapper(
          ScreenPaths.verifyEmail,
          (state) => const EmailVerification(),
          name: 'verify-email',
        ),
        RouteWrapper(
          ScreenPaths.signIn,
          (state) => const SignInScreen(),
          name: 'sign-in',
        ),
        RouteWrapper(
          ScreenPaths.dashBoard,
          (state) => const MainScreen(),
          name: 'dashboard',
        ),
        RouteWrapper(
          ScreenPaths.personalInformation,
          (state) => const PersonalInformationScreen(),
          name: 'personal-information',
        ),
        RouteWrapper(
          ScreenPaths.updateUserName,
          (state) => const UpdateUsernameScreen(),
          name: 'update-username',
        ),
        RouteWrapper(
          ScreenPaths.soundSettings,
          (state) => const SoundSettingsScreen(),
          name: 'sound-settings',
        ),
        RouteWrapper(
          ScreenPaths.helpAndFeedback,
          (state) => const HelpAndFeedbackScreen(),
          name: 'help-and-feedback',
        ),
        RouteWrapper(
          ScreenPaths.addLocation,
          (state) => const AddLocationScreen(),
          name: 'add-location',
        ),
        RouteWrapper(
          ScreenPaths.aboutUs,
          (state) => const AboutUsScreen(),
          name: 'about-us',
        ),
        RouteWrapper(
          ScreenPaths.deleteAccount,
          (state) => const DeleteAccountScreen(),
          name: 'delete-account',
        ),
      ],
    ),
  ],
);
