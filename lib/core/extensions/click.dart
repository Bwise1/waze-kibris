import 'package:flutter/material.dart';

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
}