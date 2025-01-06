import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class EmptyPlaceholder extends StatelessWidget {
  const EmptyPlaceholder({
    required this.headline,
    required this.tag,
    super.key,
    this.icon,
  });

  final String headline;
  final String tag;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(
          icon ?? 'Assets.icons.regular.chat',
          color: styles.theme.grey,
          size: 28,
        ),
        Gap(styles.insets.sm),
        Text(headline, style: styles.typography.h4.semi),
        Gap(styles.insets.xxs),
        Text(
          tag,
          style: styles.typography.btn
              .style(FontStyle.normal)
              .textColor(styles.theme.caption)
              .regular
              .textHeight(1.2),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
