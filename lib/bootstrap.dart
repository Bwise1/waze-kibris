import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    // NavigationBloc emits per GPS fix; printing the whole state serialised
    // the entire route (with the ~350-element congestion list) twice per
    // change (current + next), producing multi-megabyte logs on a real
    // drive. Print a compact per-fix summary instead.
    if (bloc is NavigationBloc) {
      final next = change.nextState;
      if (next is NavigationInProgress) {
        log('onChange(NavigationBloc, step=${next.currentStepIndex} '
            'remaining=${next.remainingDistance.toStringAsFixed(0)}m '
            'rerouting=${next.isRerouting})');
      } else {
        log('onChange(NavigationBloc, ${next.runtimeType})');
      }
      return;
    }
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();

  // Add cross-flavor configuration here

  runApp(await builder());
}
