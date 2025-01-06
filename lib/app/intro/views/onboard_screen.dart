import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waze_kibris/common.dart';

class OnboardScreen extends StatelessWidget {
  const OnboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: styles.insets.sm),
          child: AppIcon(
            Assets.icons.routeLogo,
            color: styles.theme.grey,
            size: 50,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        actions: [
          IconBtn(
            onPressed: () {},
            semanticLabel: 'Theme',
            icon: Assets.icons.moon,
            bgColor: Colors.transparent,
            border: BorderSide(color: styles.theme.nu1),
            color: styles.theme.grey,
          ),
          Gap(styles.insets.sm),
        ],
      ),
      body: Stack(
        children: [
          SizedBox(
            width: context.widthPx,
            height: context.heightPx,
            child: Assets.images.introGradientPng.image(fit: BoxFit.cover),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Assets.images.route3d.image(
                  height: 216,
                  width: 216,
                ),
                const Gap(16),
                Text(
                  'Avoid holdups and heavy traffic jams',
                  style: styles.typography.h3.textColor(styles.theme.text),
                ),
                const Gap(8),
                Text(
                  'We give you the best routes in real-time so you can get'
                  ' to your location on time',
                  style: styles.typography.body.textColor(styles.theme.caption),
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                const SlideIndicator(),
                Gap(styles.insets.lg),
                AppBtn.from(
                  onPressed: () {
                    context.push(ScreenPaths.getStarted);
                  },
                  semanticLabel: '',
                  expand: true,
                  corner: styles.corners.x24,
                  text: 'Get Started',
                  iconColor: styles.theme.white,
                  padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                  minimumSize: const Size(0, 56),
                ),
                Gap(styles.insets.md),
                AppBtn.from(
                  onPressed: () {
                    context.push(ScreenPaths.signIn);
                  },
                  semanticLabel: '',
                  expand: true,
                  corner: styles.corners.x24,
                  text: 'Log in',
                  iconColor: styles.theme.primary,
                  padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                  minimumSize: const Size(0, 56),
                  bgColor: styles.theme.primary.withValues(alpha: .1),
                ),
                Gap(styles.insets.md),
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

class SlideIndicator extends StatelessWidget {
  const SlideIndicator({super.key, this.numOfIndicator = 1});

  final int numOfIndicator;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        numOfIndicator,
        (context) => CustomContainer(
          width: 40,
          height: 2,
          margin: EdgeInsets.only(right: styles.corners.md),
          color: styles.theme.primary,
          borderRadius: BorderRadius.circular(styles.corners.md),
        ),
      ),
    );
  }
}
