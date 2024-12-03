import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;
  static AppStyle get style => _style;
  static AppStyle _style = AppStyle();

  @override
  Widget build(BuildContext context) {
    MediaQuery.of(context);
    _style = AppStyle(screenSize: context.sizePx);
    Animate.defaultDuration = _style.times.fast;
    return KeyedSubtree(
      key: ValueKey(styles.scale),
      child: DefaultTextStyle(
        style: styles.typography.body,
        child: child,
      ),
    );
  }
}
