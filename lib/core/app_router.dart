import 'package:flutter/material.dart';
import 'package:waze_kibris/app/auth/view/blank_loader_page.dart';
import 'package:waze_kibris/app/profile/view/help_screen.dart';
import 'package:waze_kibris/app/profile/view/sound_settings.dart';
import 'package:waze_kibris/app/report/view/report_votes.dart';
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
  static String changeUsername = '/change-username';
  static String soundSettings = '/sound-settings';
  static String drivingPreferences = '/driving-preferences';
  static String helpAndFeedback = '/help-and-feedback';
  static String addLocation = '/add-location';
  static String aboutUs = '/about-us';
  static String deleteAccount = '/delete-account';
  static String loaderPage = '/loader-page';
  static String reportVotes = '/report-votes';
}

final navigatorKey = GlobalKey<NavigatorState>();

// Router factory function - creates router after DI initialization
GoRouter createAppRouter() {
  // Safely get initial location, defaulting to home if GetIt isn't ready
  String getInitialLocation() {
    try {
      if (getIt.isRegistered<ILocalStorage>()) {
        final token = getIt<ILocalStorage>().get<String>(StoreKeys.wazeToken);
        return isEmptyOrNull(token) ? ScreenPaths.home : ScreenPaths.dashBoard;
      }
    } catch (e) {
      // If GetIt isn't initialized yet, default to home
    }
    return ScreenPaths.home;
  }

  return GoRouter(
    initialLocation: getInitialLocation(),
    redirect: (context, state) {
      // Re-evaluate initial location on redirect if needed
      // This ensures we check auth state after DI is initialized
      try {
        if (getIt.isRegistered<ILocalStorage>()) {
          final token = getIt<ILocalStorage>().get<String>(StoreKeys.wazeToken);
          final isAuthenticated = !isEmptyOrNull(token);
          final isOnAuthRoute = state.matchedLocation == ScreenPaths.home ||
              state.matchedLocation == ScreenPaths.getStarted ||
              state.matchedLocation == ScreenPaths.signIn ||
              state.matchedLocation == ScreenPaths.verifyEmail;
          
          // Redirect to dashboard if authenticated and on auth route
          if (isAuthenticated && isOnAuthRoute) {
            return ScreenPaths.dashBoard;
          }
          // Redirect to home if not authenticated and on protected route
          if (!isAuthenticated && !isOnAuthRoute && state.matchedLocation != ScreenPaths.home) {
            return ScreenPaths.home;
          }
        }
      } catch (e) {
        // If GetIt isn't ready, allow navigation to continue
      }
      return null; // No redirect needed
    },
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
          ScreenPaths.changeUsername,
          (state) => const ChangeUsernameScreen(),
          name: 'change-username',
        ),
        RouteWrapper(
          ScreenPaths.soundSettings,
          (state) => const SoundSettingsScreen(),
          name: 'sound-settings',
        ),
        RouteWrapper(
          ScreenPaths.drivingPreferences,
          (state) => const DrivingPreferenceScreen(),
          name: 'driving-preferences',
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
        RouteWrapper(
          ScreenPaths.loaderPage,
          (state) => const BlankLoaderScreen(),
          name: 'loader-page',
        ),
        RouteWrapper(
          ScreenPaths.reportVotes,
          (state) => const ReportVotesScreen(),
          name: 'report-votes',
        ),
      ],
    ),
  ],
  );
}

// Lazy router instance - created after DI initialization
late final GoRouter appRouter = createAppRouter();
