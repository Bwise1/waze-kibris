import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomClickableText extends StatelessWidget {
  const CustomClickableText({
    required this.text,
    super.key,
    this.onTap,
    this.padding,
    this.color,
    this.textColor,
    this.style,
    this.radius,
    this.overlay,
  })  : _isText = true,
        widget = null;

  const CustomClickableText.widget({
    required this.widget,
    super.key,
    this.onTap,
    this.padding,
    this.color,
    this.textColor,
    this.radius,
    this.overlay,
  })  : _isText = false,
        text = '',
        style = null;

  final String text;
  final Widget? widget;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool _isText;
  final Color? color;
  final Color? textColor;
  final TextStyle? style;
  final BorderRadius? radius;
  final Color? overlay;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        FocusScope.of(context).requestFocus();
        if (onTap != null) {
          onTap?.call();
        }
      },
      style: TextButton.styleFrom(
        padding: padding ?? EdgeInsets.symmetric(horizontal: styles.insets.xs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius ?? BorderRadius.circular(styles.corners.sm),
        ),
        overlayColor: (overlay ?? color)?.withValues(alpha: .1),
      ),
      child: _isText
          ? Text(
              text,
              style: style ??
                  styles.typography.caption
                      .textColor(textColor ?? styles.theme.text)
                      .style(FontStyle.normal),
            )
          : widget!,
    );
  }
}
