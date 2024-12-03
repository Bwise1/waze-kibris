import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class ModalHeader extends StatelessWidget {
  const ModalHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64 * styles.scale,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Row(
                children: [
                  Gap(styles.insets.md * styles.scale),
                  Text(title, style: styles.typography.h3),
                  Spacer(),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: AppIcon(
                      Assets.icons.regular.close,
                      color: styles.theme.black,
                      size: 24 * styles.scale,
                    ),
                  ),
                  Gap(styles.insets.xs * styles.scale),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
