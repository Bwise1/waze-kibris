import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomDialogRoutes {
  static const Duration kDefaultDuration = Duration(milliseconds: 500);

  static Route<T> _show<T>(Widget child,
      {Duration duration = kDefaultDuration,
      bool opaque = false,
      bool fullscreenDialog = false}) {
    Widget content = fullscreenDialog ? child : Dialog(child: child);

    if (opaque) {
      return CupertinoPageRoute(builder: (_) => content);
    }

    return PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      opaque: opaque,
      fullscreenDialog: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeInOut)),
          ),
          child: content,
        );
      },
    );
  }

  static Future<T?> showDialog<T>(BuildContext context, Widget child,
      {bool transparent = false, bool full = false}) async {
    return await Navigator.of(context).push<T>(
      _show<T>(child, duration: styles.times.fast, fullscreenDialog: full),
    );
  }

  static Future<T?> showDialogModal<T>(BuildContext context,
      {required Widget child,
      bool dismissible = true,
      EdgeInsets? padding}) async {
    return await showCupertinoModalPopup(
      context: context,
      filter: ImageFilter.blur(
        sigmaX: 3,
        sigmaY: 4,
        tileMode: TileMode.mirror,
      ),
      barrierDismissible: dismissible,
      builder: (context) => Container(
        width: double.infinity,
        margin: EdgeInsets.fromLTRB(
            styles.insets.sm, 0, styles.insets.sm, styles.insets.lg),
        padding: padding ?? EdgeInsets.all(styles.insets.md),
        decoration: BoxDecoration(
          color: styles.theme.white,
          borderRadius: BorderRadius.circular(styles.corners.md),
          border: Border.all(color: styles.theme.white, width: 1.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Material(
          color: styles.theme.white,
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
      ),
    );
  }

  static Future<T?> showBottomSheet<T>(
    BuildContext context,
    Widget child, {
    bool dismissible = true,
  }) async {
    return await showMaterialModalBottomSheet(
      context: context,
      builder: (context) {
        return child;
      },
    );
  }
}
