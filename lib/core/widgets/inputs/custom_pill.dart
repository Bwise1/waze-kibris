import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomPill extends StatelessWidget {
  const CustomPill({
    super.key,
    this.padding,
    this.text,
    this.color,
    this.textColor,
    this.style,
    this.radius,
    this.onPressed,
  });
  final EdgeInsets? padding;
  final String? text;
  final Color? color;
  final Color? textColor;
  final TextStyle? style;
  final double? radius;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(radius ?? styles.corners.jumbo),
        ),
        child: Text(
          text ?? '',
          style: style ?? TextStyle(color: textColor ?? Colors.white),
        ),
      ),
    );
  }
}
