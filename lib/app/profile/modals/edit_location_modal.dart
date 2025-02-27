import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class EditLocationModal extends StatelessWidget {
  const EditLocationModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  Assets.icons.homeSmile,
                  size: 24,
                  color: styles.theme.grey,
                ),
                const Gap(8),
                Text(
                  'Home',
                  style: styles.typography.h2
                      .textColor(styles.theme.text)
                      .size(20)
                      .semi,
                ),
              ],
            ),
            const Gap(8),
            Text(
              'Address',
              style: styles.typography.t2.textColor(styles.theme.ash).medium,
            ),
          ],
        ),
        const Gap(32),
        Row(
          children: [
            AppIcon(Assets.icons.flagMarker, size: 24, color: styles.theme.ash),
            const Gap(16),
            Text(
              'Edit this location',
              style: styles.typography.t2
                  .textColor(styles.theme.ash)
                  .textHeight(0),
            ),
          ],
        ), //
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Divider(color: styles.theme.secondary),
        ),
        Row(
          children: [
            AppIcon(Assets.icons.bin, size: 24, color: styles.theme.primary),
            const Gap(16),
            Text(
              'Remove location',
              style: styles.typography.t3
                  .textColor(styles.theme.primary)
                  .textHeight(0),
            ),
          ],
        ),
      ],
    );
  }
}
