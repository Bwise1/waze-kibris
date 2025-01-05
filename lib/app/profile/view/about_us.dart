import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/res/strings.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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
                  Card(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    elevation: 8,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: context.widthPx,
                          height: 120,
                          child: Assets.images.friendsWithPuzzel.image(
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: UnconstrainedBox(
                            child: Container(
                              height: 120,
                              width: context.widthPx * 0.4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.white.withValues(alpha: .7),
                                  ],
                                  stops: const [0, 0.8],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: context.widthPx * 0.4,
                          child: UnconstrainedBox(
                            child: Container(
                              height: 120,
                              width: context.widthPx * 0.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.7),
                                    Colors.white.withValues(alpha: 0.15),
                                  ],
                                  stops: const [0, 0.2],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 25,
                          bottom: 15,
                          child: Text(
                            'About Us',
                            style: styles.typography.h2
                                .textColor(styles.theme.text)
                                .weight(FontWeight.w600)
                                .textHeight(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap(16 * styles.scale),
                  Text(
                    Strings.aboutUsNote,
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
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
