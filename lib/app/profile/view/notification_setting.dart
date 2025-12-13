import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class NotificationSettingScreen extends StatelessWidget {
  const NotificationSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppHeader(
            backIcon: Assets.icons.backArrow,
            isTransparent: true,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gap(16 * styles.scale),
                  Text(
                    'Notification setting',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    '''
We want to notify you as much as we can about everything around you''',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(16 * styles.scale),
                  CustomClickableText(
                    onTap: () {},
                    text: 'Email notification',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: styles.theme.secondary,
                      thickness: 1,
                    ),
                  ),
                  CustomClickableText(
                    onTap: () {},
                    text: 'Push notification',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: styles.theme.secondary,
                      thickness: 1,
                    ),
                  ),
                  CustomClickableText(onTap: () {}, text: 'Reminders'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
