import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waze_kibris/common.dart';

import 'package:waze_kibris/core/widgets/buttons/social_media_button.dart';

class GettingStarted extends StatefulWidget {
  const GettingStarted({super.key});

  @override
  State<GettingStarted> createState() => _GettingStartedState();
}

class _GettingStartedState extends State<GettingStarted> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: styles.theme.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: styles.insets.sm, top: 4),
          child: BackBtn(
            onPressed: ()=> context.pop(),
            semanticLabel: '',
            bgColor: Colors.transparent,
            iconColor: styles.theme.grey,
            borderSide: BorderSide(
              color: styles.theme.nu1,
            ),
          ),
        ),
        leadingWidth: 50 + styles.insets.sm,
        actions: [
          AppIcon(
            Assets.icons.routeLogo,
            color: styles.theme.grey,
            size: 45,
          ),
          Gap(styles.insets.sm),
        ],
      ),
      body: Stack(
        children: [
          const GradientBG(),
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Gap(278 * styles.scale),
                Text(
                  'Enter your email',
                  style: styles.typography.h3.textColor(styles.theme.text),
                ),
                Gap(styles.insets.sm),
                CustomTextField(
                  hintText: 'Email address',
                  prefix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 45,
                        width: 45,
                        child: AppIcon(
                          Assets.icons.at,
                          color: styles.theme.grey,
                          size: 18,
                        ),
                      ),
                      Text(
                        '|',
                        style: styles.typography.h4.textColor(styles.theme.ash),
                      ),
                    ],
                  ),
                ),
                Gap(styles.insets.sm),
                AppBtn.from(
                  onPressed: () {
                    context.push(ScreenPaths.verifyEmail);
                  },
                  semanticLabel: '',
                  expand: true,
                  corner: styles.corners.x24,
                  text: 'Continue',
                  iconColor: styles.theme.primary,
                  bgColor: styles.theme.secondary,
                  padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                  minimumSize: const Size(0, 56),
                ),
                Gap(styles.insets.sm),
                SizedBox(
                  height: 40,
                  width: context.widthPx,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Divider(
                          color: styles.theme.divider,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'OR',
                          style: styles.typography.t3
                              .textColor(styles.theme.ash),
                        ),
                      ),
                      Divider(
                        color: styles.theme.grey,
                      ),
                      Flexible(
                        child: Divider(
                          color: styles.theme.divider,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(styles.insets.lg),
                SocialMediaBtn(
                  onPressed: () {},
                  title: 'Continue with Google',
                  socialIcon: Assets.icons.google,
                ),
                Gap(styles.insets.sm),
                SocialMediaBtn(
                  onPressed: () {},
                  title: 'Continue with Apple',
                  socialIcon: Assets.icons.apple,
                ),
                Gap(styles.insets.xl),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'By signing up, you have agreed to our ',
                    style: styles.typography.overline
                        .textColor(styles.theme.text)
                        .textHeight(0),
                    children: [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: styles.typography.overline
                            .textColor(styles.theme.primary)
                            .textHeight(0),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                      TextSpan(
                        text: ', acknowledge our ',
                        style: styles.typography.overline
                            .textColor(styles.theme.text)
                            .textHeight(0),
                      ),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: styles.typography.overline
                            .textColor(styles.theme.primary)
                            .textHeight(0),
                        recognizer: TapGestureRecognizer()..onTap = () {},
                      ),
                      TextSpan(
                        text: ', and confirm that you are an adult.',
                        style: styles.typography.overline
                            .textColor(styles.theme.text)
                            .textHeight(0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
