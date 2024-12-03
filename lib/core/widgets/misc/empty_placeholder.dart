import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class EmptyPlaceholder extends StatelessWidget {
  const EmptyPlaceholder({
    super.key,
    required this.headline,
    required this.tag,
    this.icon,
  });

  final String headline;
  final String tag;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIcon(icon ?? Assets.icons.regular.chat,
            color: styles.theme.grey, size: 28),
        Gap(styles.insets.sm),
        Text(headline, style: styles.typography.h4.semiBold),
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
