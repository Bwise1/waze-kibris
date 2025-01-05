import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/widgets/buttons/social_media_button.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Stack(
        children: [
          SizedBox(
            width: context.widthPx,
            height: context.heightPx,
            child: Assets.images.introGradientPng.image(fit: BoxFit.cover),
          ),
          AppHeader(
            backIcon: Assets.icons.backArrow,
            trailing: (context) => BackBtn(
              onPressed: () {},
              icon: Assets.icons.routeLogo,
              semanticLabel: 'Logo',
              bgColor: Colors.transparent,
              iconColor: styles.theme.grey,
            ),
            isTransparent: true,
          ),
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Gap(120 * styles.scale),
                Assets.images.frame2023.image(
                  height: 88,
                  width: 160,
                ),
                const Gap(16),
                Text(
                  'Hey,  Welcome back!',
                  style: styles.typography.h3.textColor(styles.theme.text),
                ),
                Gap(styles.insets.sm),
                CustomTextField(
                  hintText: 'Email address',
                  prefix: Row(
                    children: [
                      IconBtn(
                        icon: Assets.icons.at,
                        bgColor: Colors.transparent,
                        color: styles.theme.text,
                        onPressed: () {},
                        semanticLabel: 'at',
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
                    context.push(ScreenPaths.dashBoard);
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
                          style: styles.typography.caption
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
                Gap(styles.insets.offset),
                AppBtn.basic(
                  onPressed: () {},
                  semanticLabel: 'log-in-trouble',
                  child: Text(
                    'Having troubles logging in?',
                    style: styles.typography.hairline
                        .textColor(styles.theme.primary)
                        .underline(styles.theme.primary),
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
