import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/common.dart';

class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  int _settingTab = 0;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(16 * styles.scale),
                      Text(
                        'Sound setting',
                        style:
                            styles.typography.h3.textColor(styles.theme.text),
                      ).alignment(Alignment.bottomLeft),
                      Gap(8 * styles.scale),
                      Text(
                        '''
                       Take full control of your voice and sound controls.'''
                        ' All your sound settings are here ',
                        style:
                            styles.typography.body.textColor(styles.theme.ash),
                      ).alignment(Alignment.bottomLeft),
                      Gap(16 * styles.scale),
                      Row(
                        children: [
                          Text(
                            'Sounds',
                            style: styles.typography.t2
                                .textColor(styles.theme.text),
                          ),
                          Expanded(child: Container()),
                          Expanded(
                            flex: 2,
                            child: SegmentedTab(
                              index: _settingTab,
                              textSize: 14,
                              sections: const [
                                TabSection(label: 'On'),
                                TabSection(label: 'Off'),
                                TabSection(label: 'Alerts'),
                              ],
                              onTabPressed: (index) {
                                setState(() {
                                  _settingTab = index;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                Text(
                                  'Voice Assistant',
                                  style: styles.typography.t2
                                      .textColor(styles.theme.text),
                                ),
                                Text(
                                  'English (United Kingdom) - Franklin',
                                  style: styles.typography.t3
                                      .textColor(styles.theme.ash),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 8,
                  color: styles.theme.white,
                  margin: EdgeInsets.symmetric(
                    vertical: styles.insets.sm,
                  ),
                ),
                CustomContainer(
                  color: styles.theme.transparent,
                  borderRadius: BorderRadius.circular(styles.corners.lg),
                  padding: EdgeInsets.all(styles.insets.md),
                  child: Column(
                    children: [
                      Text(
                        'Voice Command',
                        style: styles.typography.h4.textColor(styles.theme.ash),
                      ).alignment(Alignment.bottomLeft),
                      Gap(24 * styles.scale),
                      Row(
                        children: [
                          Text(
                            'Reports',
                            style: styles.typography.t2
                                .textColor(styles.theme.text),
                          ),
                          Expanded(child: Container()),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                          thickness: 1,
                        ),
                      ),
                      Row(
                        children: [
                          Assets.icons.googleAssistant
                              .image(height: 24, width: 24),
                          Gap(styles.insets.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                Text(
                                  'Google Assistance',
                                  style: styles.typography.t2
                                      .textColor(styles.theme.text),
                                ),
                                Text(
                                  'Universal Assist',
                                  style: styles.typography.t3
                                      .textColor(styles.theme.ash),
                                ),
                              ],
                            ),
                          ),
                        ],
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
    );
  }
}
