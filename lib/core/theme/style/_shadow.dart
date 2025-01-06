part of '../app_style.dart';

@immutable
class Shadows {
  static bool enabled = true;

  static double get radius => 8;

  final soft = [
    Shadow(
      color: Colors.black.withValues(alpha: .25),
      offset: const Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  final midi = [
    Shadow(
      color: Colors.black.withValues(alpha: .6),
      offset: const Offset(0, 2),
      blurRadius: 2,
    ),
  ];

  final strong = [
    Shadow(
      color: Colors.black.withValues(alpha: .6),
      offset: const Offset(0, 4),
      blurRadius: 6,
    ),
  ];

  final List<BoxShadow> xs = [
    BoxShadow(
      color: const Color(0xffE8E8E8).withValues(alpha: 0.2),
      offset: const Offset(0, -2),
      blurRadius: 4,
    ),
  ];

  final List<BoxShadow> sm = [
    BoxShadow(
      color: Colors.grey.withValues(alpha: 0.1),
      spreadRadius: 3,
      blurRadius: 20,
      offset: const Offset(0, 7), // changes position of shadow
    ),
  ];

  final List<BoxShadow> md = [
    BoxShadow(
      color: Colors.grey.withValues(alpha: 0.1),
      spreadRadius: 10,
      blurRadius: 50,
      offset: const Offset(1, 7), // changes position of shadow
    ),
  ];

  final List<BoxShadow> lg = [
    const BoxShadow(
      color: Color(0x66000000),
      offset: Offset(4, 8),
      blurRadius: 8,
    ),
  ];

  List<BoxShadow> custom(Color color, [double opacity = 0]) {
    return enabled
        ? [
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: radius,
              spreadRadius: radius / 2,
              offset: const Offset(1, 0),
            ),
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: radius / 2,
              spreadRadius: radius / 4,
              offset: const Offset(1, 0),
            ),
          ]
        : const <BoxShadow>[];
  }
}
