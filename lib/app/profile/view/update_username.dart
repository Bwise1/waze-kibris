import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class UpdateUsernameScreen extends StatelessWidget {
  const UpdateUsernameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(
          backIcon: Assets.icons.backArrow,
          isTransparent: true,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(16 * styles.scale),
                Text(
                  'Update your name',
                  style: styles.typography.h3.textColor(styles.theme.text),
                ),
                Gap(8 * styles.scale),
                Text(
                  '''
What do you want us to call you by? Enter your full name below''',
                  style:
                  styles.typography.body.textColor(styles.theme.ash),
                ),
                Gap(24 * styles.scale),
                Text(
                  'First name',
                  style: styles.typography.body.textColor(styles.theme.text),
                ),
                Gap(2 * styles.scale),
                CustomTextField(
                  fillColor: styles.theme.white,
                  hintText: 'Enter your first name',
                  initialValue: 'Enter your first name',
                  prefix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconBtn(
                        icon: Assets.icons.profile,
                        bgColor: Colors.transparent,
                        color: styles.theme.text,
                        onPressed: () {},
                        semanticLabel: 'at',
                      ),
                      Text(
                        '|',
                        style:
                        styles.typography.h4.textColor(styles.theme.ash),
                      ),
                    ],
                  ),
                ),
                Gap(16 * styles.scale),
                Text(
                  'Last name',
                  style: styles.typography.body.textColor(styles.theme.text),
                ),
                Gap(2 * styles.scale),
                CustomTextField(
                  fillColor: styles.theme.white,
                  hintText: 'Enter your first name',
                  prefix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconBtn(
                        icon: Assets.icons.profile,
                        bgColor: Colors.transparent,
                        color: styles.theme.text,
                        onPressed: () {},
                        semanticLabel: 'at',
                      ),
                      Text(
                        '|',
                        style:
                        styles.typography.h4.textColor(styles.theme.ash),
                      ),
                    ],
                  ),
                ),
                Gap(282 * styles.scale),
              ],
            ),
          ),
        ),
        Container(
          height: 80,
          padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
          child: Column(
            children: [
              AppBtn.from(
                onPressed: () {},
                semanticLabel: '',
                expand: true,
                corner: styles.corners.x24,
                text: 'Save',
                iconColor: styles.theme.primary,
                bgColor: styles.theme.secondary,
                padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                minimumSize: const Size(0, 56),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
