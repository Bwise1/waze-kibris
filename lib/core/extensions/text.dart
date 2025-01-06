/*
 * Copyright (c) 2024. Relett, Inc.
 *
 */

import 'package:flutter/material.dart';

extension TextStyleExtension on TextStyle {
  TextStyle get xLight => weight(FontWeight.w100);
  TextStyle get light => weight(FontWeight.w200);

  TextStyle get regular => weight(FontWeight.w400);
  TextStyle get medium => weight(FontWeight.w500);
  TextStyle get semi => weight(FontWeight.w600);
  TextStyle get bold => weight(FontWeight.w700);
  TextStyle get italic => style(FontStyle.italic);

  TextStyle textColor(Color v) => copyWith(color: v);

  TextStyle size(double v) => copyWith(fontSize: v);
  TextStyle scale(double v) => copyWith(fontSize: (fontSize ?? 0) * v);

  TextStyle weight(FontWeight v) => copyWith(fontWeight: v);
  TextStyle style(FontStyle v) => copyWith(fontStyle: v);

  TextStyle letterSpace(double v) => copyWith(letterSpacing: v);
  TextStyle wordSpace(double v) => copyWith(wordSpacing: v);
  TextStyle textHeight(double v) => copyWith(height: v);
  TextStyle underline(Color color) =>
      copyWith(decoration: TextDecoration.underline, decorationColor: color);
  TextStyle lineThrough(double thickness, Color color) => copyWith(
        decoration: TextDecoration.lineThrough,
        decorationThickness: thickness,
        decorationColor: color,
      );
}
