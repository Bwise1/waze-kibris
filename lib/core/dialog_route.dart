import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:waze_kibris/common.dart';

class CustomDialogRoutes {
  static const Duration kDefaultDuration = Duration(milliseconds: 500);

  static Route<T> _show<T>(
    Widget child, {
    Duration duration = kDefaultDuration,
    bool opaque = false,
    bool fullscreenDialog = false,
  }) {
    final content = fullscreenDialog ? child : Dialog(child: child);

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

  static Future<T?> showDialog<T>(
    BuildContext context,
    Widget child, {
    bool transparent = false,
    bool full = false,
  }) async {
    return Navigator.of(context).push<T>(
      _show<T>(child, duration: styles.times.fast, fullscreenDialog: full),
    );
  }

  static Future<T?> showDialogModal<T>(
    BuildContext context, {
    required Widget child,
    bool dismissible = true,
    EdgeInsets? padding,
  }) async {
    return showCupertinoModalPopup(
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
          styles.insets.sm,
          0,
          styles.insets.sm,
          styles.insets.lg,
        ),
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
    return showMaterialModalBottomSheet(
      context: context,
      builder: (context) {
        return child;
      },
    );
  }

  static Future<void> openBottomSheet(
    BuildContext context,
    Widget child, {
    double sizeFraction = 0.38,
    String title = '',
    bool addCloseIcon = false,
    bool showDragTopICon = false,
    bool centerAlignTitle = true,
    bool isDismissible = true,
    bool enableDrag = true,
    double edgeRadius = 24,
    Color? titleColor,
    double closeIconHeightFromTop = 32,
    EdgeInsets? padding,
  }) {
    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent.withValues(alpha: 0.15),
      builder: (
        BuildContext context,
      ) =>
          CustomContainer(
        height: context.heightPx * sizeFraction,
        color: Theme.of(context).scaffoldBackgroundColor,
        // shadows: styles.,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(edgeRadius),
          topRight: Radius.circular(edgeRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDragTopICon) ...[
              CustomContainer(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(top: 1),
                borderRadius: BorderRadius.circular(styles.corners.md),
                color: Colors.black.withValues(alpha: 0.2),
              ),
            ],
            Gap(closeIconHeightFromTop),
            if (title.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (centerAlignTitle) ...[const SizedBox()],

                    Text(
                      title,
                      style: styles.typography.h1.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    // const Spacer(),
                    Visibility(
                      visible: addCloseIcon,
                      child: Icon(
                        Icons.cancel,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Gap(10),
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
