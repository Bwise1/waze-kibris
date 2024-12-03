import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:waze_kibris/common.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({required this.child, super.key});
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
