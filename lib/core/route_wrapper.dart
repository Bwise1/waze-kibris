import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouteWrapper extends GoRoute {
  RouteWrapper(
    String path,
    Widget Function(GoRouterState s) builder, {
    String name = '',
    List<GoRoute> routes = const [],
    this.useFade = true,
  }) : super(
          path: path,
          routes: routes,
          name: name,
          pageBuilder: (context, state) {
            final pageContent = Scaffold(
              body: builder(state),
              resizeToAvoidBottomInset: true,
            );
            if (useFade) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: pageContent,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              );
            }
            return CupertinoPage(child: pageContent);
          },
        );
  final bool useFade;
}
