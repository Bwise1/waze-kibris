part of '../app_style.dart';

@immutable
class Insets {
  Insets(this._scale);
  final double _scale;

  late final double none = 2;
  late final double xxs = 4 * _scale;
  late final double xs = 8 * _scale;
  late final double sm = 16 * _scale;
  late final double md = 24 * _scale;
  late final double lg = 32 * _scale;
  late final double xl = 48 * _scale;
  late final double xxl = 56 * _scale;
  late final double xl2 = 64 * _scale;
  late final double offset = 80 * _scale;
}
