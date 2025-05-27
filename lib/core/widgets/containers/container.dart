import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomContainer extends StatelessWidget {
  const CustomContainer({
    super.key,
    this.color,
    this.borderRadius,
    this.shadows,
    this.child,
    this.width,
    this.height,
    this.align,
    this.margin,
    this.duration,
    this.padding,
    this.border,
    this.transform,
  });
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? shadows;
  final Widget? child;
  final double? width;
  final double? height;
  final Alignment? align;
  final EdgeInsets? margin;
  final Duration? duration;
  final BoxBorder? border;
  final EdgeInsets? padding;
  final Matrix4? transform;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      transform: transform,
      width: width,
      height: height,
      margin: margin,
      alignment: align,
      padding: padding,
      duration: duration ?? styles.times.med,
      curve: Curves.easeInOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? styles.theme.nu1,
        borderRadius: borderRadius,
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );
  }
}
