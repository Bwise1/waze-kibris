import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:waze_kibris/common.dart';

part 'app_theme.dart';
part 'style/_corner.dart';
part 'style/_insets.dart';
part 'style/_sizes.dart';
part 'style/_times.dart';
part 'style/_typography.dart';
part 'style/_shadow.dart';

@immutable
class AppStyle {
  AppStyle({Size? screenSize}) {
    if (screenSize == null) {
      scale = 1;
      return;
    }
    final shortestSide = screenSize.shortestSide;
    const tabletXl = 1000;
    const tabletLg = 800;
    const tabletSm = 600;
    const phoneLg = 400;
    if (shortestSide > tabletXl) {
      scale = 1.25;
    } else if (shortestSide > tabletLg) {
      scale = 1.15;
    } else if (shortestSide > tabletSm) {
      scale = 1;
    } else if (shortestSide > phoneLg) {
      scale = .9; // phone
    } else {
      scale = .85; // small phone
    }
    debugPrint('screenSize=$screenSize, scale=$scale');
  }

  late final double scale;

  final AppTheme theme = AppTheme();

  late final Corners corners = Corners();

  late final Insets insets = Insets(scale);

  late final Typography typography = Typography(scale);

  final Times times = Times();

  final Sizes sizes = Sizes();

  final Shadows shadows = Shadows();
}
