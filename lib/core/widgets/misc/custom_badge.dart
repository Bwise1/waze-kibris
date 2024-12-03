import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomBadge extends StatelessWidget {
  const CustomBadge(
    this.value, {
    super.key,
    this.width,
    this.color,
    this.radius,
    this.bordered = false,
    this.borderColor,
  });
  final String value;
  final double? width;
  final Color? color;
  final double? radius;
  final bool bordered;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        vertical: styles.insets.xxs,
        horizontal: styles.insets.xs,
      ),
      decoration: BoxDecoration(
        color: color ?? styles.theme.red,
        borderRadius: BorderRadius.circular(radius ?? styles.corners.sm),
        border: bordered
            ? Border.all(color: borderColor ?? styles.theme.red, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: styles.typography.hairline
                .textColor(borderColor ?? styles.theme.white)
                .medium
                .textHeight(0),
          ),
        ],
      ),
    );
  }
}
