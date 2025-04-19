import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

extension WidgetExtension on Widget {
  Widget clickable(void Function()? action, {bool opaque = true}) {
    return GestureDetector(
      behavior: opaque ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      onTap: () {
        //AppHaptics.buttonPress();
        action?.call();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        opaque: opaque,
        child: this,
      ),
    );
  }

  Widget rippleClick(
    void Function()? onTap, {
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? clickBorderRadius,
    Color? rippleColor,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Padding(
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: this,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: rippleColor,
              shape: RoundedRectangleBorder(
                borderRadius: clickBorderRadius ??
                    BorderRadius.circular(styles.corners.md),
              ),
              padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
            ),
            onPressed: onTap,
            child: Container(),
          ),
        ),
      ],
    );
  }
}
