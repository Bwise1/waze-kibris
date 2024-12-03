import 'dart:math';

import 'package:flutter/material.dart';

extension SizedContext on BuildContext {
  MediaQueryData get mq => MediaQuery.of(this);

  bool get isLandscape => mq.orientation == Orientation.landscape;

  Size get sizePx => mq.size;

  double get widthPx => sizePx.width;

  double get heightPx => sizePx.height;

  double get diagonalPx {
    final Size s = sizePx;
    return sqrt((s.width * s.width) + (s.height * s.height));
  }

  double widthPct(double fraction) => fraction * widthPx;

  double heightPct(double fraction) => fraction * heightPx;
}
