import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/profile/view/profile_main.dart';
import 'package:waze_kibris/common.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

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
                children: [
                  Gap(16 * styles.scale),
                  Text(
                    'Sound setting',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ).alignment(Alignment.bottomLeft),
                  Gap(8 * styles.scale),
                  Text(
                    '''
 Take full control of your voice and sound controls.'''
                    ' All your sound settings are here ',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ).alignment(Alignment.bottomLeft),
                  Gap(16 * styles.scale),
                  Row(
                    children: [
                      Text(
                        'Sounds',
                        style:
                            styles.typography.h3.textColor(styles.theme.text),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: styles.theme.secondary,
                    ),
                  ),
                  Gap(24 * styles.scale),
                  ProfileActionItemButton(
                    onPressed: () {
                      context.push(ScreenPaths.updateUserName);
                    },
                    icon: ' ',
                    title: 'Voice Assistant',
                    subTitle: 'English (United Kingdom) - Franklin',
                    semanticLabel: 'voice-action-btn',
                  ),
                  CustomContainer(
                    child: Column(
                      children: [
                        Text(
                          'Voice Command',
                          style:
                              styles.typography.h5.textColor(styles.theme.ash),
                        ).alignment(Alignment.bottomLeft),
                        Gap(24 * styles.scale),
                        Text(
                          'Reports',
                          style: styles.typography.body.copyWith(
                              color: styles.theme.text,
                              fontWeight: FontWeight.w500,),
                        ).alignment(Alignment.bottomLeft),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: styles.theme.secondary,
                            thickness: 1,
                          ),
                        ),
                        ProfileActionItemButton(
                          onPressed: () {
                            context.push(ScreenPaths.signIn);
                          },
                          icon: Assets.icons.at,
                          title: 'Google assistance',
                          subTitle: 'Universal assistant',
                          semanticLabel: 'google-action-btn',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            color: styles.theme.secondary,
                            thickness: 1,
                          ),
                        ),
                        ProfileActionItemButton(
                          onPressed: () {},
                          icon: Assets.icons.microphone,
                          title: 'Voice typing',
                          subTitle: 'English (United Kingdom)',
                          semanticLabel: 'voice-action-btn',
                        ),
                        Gap(24 * styles.scale),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
