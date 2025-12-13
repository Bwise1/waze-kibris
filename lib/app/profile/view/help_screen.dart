import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class HelpAndFeedbackScreen extends StatelessWidget {
  const HelpAndFeedbackScreen({super.key});

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
                    'How can we help you today?',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),
                  Gap(8 * styles.scale),
                  Text(
                    '''
Having issues or questions? leave us a message or check from our frequently asked questions''',
                    style:
                        styles.typography.hairline.textColor(styles.theme.ash),
                  ),
                  Gap(16 * styles.scale),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomContainer(
                        color: Colors.transparent,
                        width: 160 * styles.scale,
                        height: 160 * styles.scale,
                        border: Border.all(width: 3, color: styles.theme.white),
                        borderRadius: BorderRadius.circular(styles.corners.sm),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(styles.corners.md),
                          child: Assets.images.liveChatBackground
                              .image(fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        bottom: 15,
                        child: Text(
                          'Live\nchat',
                          style: styles.typography.h2
                              .textColor(styles.theme.text)
                              .weight(FontWeight.w400)
                              .textHeight(0.9),
                        ),
                      ),
                    ],
                  ),
                  Gap(16 * styles.scale),
                  CustomTextField(
                    hintText: 'search language',
                    initialValue: ' ',
                    prefix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconBtn(
                          icon: Assets.icons.searchGlass,
                          bgColor: Colors.transparent,
                          color: styles.theme.text,
                          onPressed: () {},
                          semanticLabel: 'Glass',
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
                  CustomClickableText(
                    text: 'Frequently asked questions',
                    style: styles.typography.t3
                        .textColor(styles.theme.text)
                        .weight(FontWeight.w500),
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
