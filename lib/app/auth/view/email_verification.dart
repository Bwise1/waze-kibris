import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:waze_kibris/common.dart';

class EmailVerification extends StatefulWidget {
  const EmailVerification({super.key});

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> {
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
              semanticLabel: 'Back Button',
              bgColor: Colors.transparent,
              iconColor: styles.theme.grey,
            ),
            isTransparent: true,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Gap(220 * styles.scale),
                  Text(
                    'Email verification',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),
                  Gap(styles.insets.xs),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: 'We sent a verification code to \n ',
                      style: styles.typography.hairline
                          .textColor(styles.theme.text)
                          .textHeight(0),
                      children: [
                        TextSpan(
                          text: 'myname@email.com.',
                          style: styles.typography.hairline
                              .textColor(styles.theme.primary)
                              .textHeight(0),
                          recognizer: TapGestureRecognizer()..onTap = () {},
                        ),
                        TextSpan(
                          text: ' Please input code below ',
                          style: styles.typography.hairline
                              .textColor(styles.theme.text)
                              .textHeight(0),
                        ),
                      ],
                    ),
                  ),
                  Gap(styles.insets.sm),
                  SizedBox(
                    width: 327 * styles.scale,
                    child: Pinput(
                      defaultPinTheme: PinTheme(
                        width: 75 * styles.scale,
                        height: 75 * styles.scale,
                        textStyle: TextStyle(
                          fontSize: 20,
                          color: styles.theme.text,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: styles.theme.secondary,
                          border:
                              Border.all(color: styles.theme.primary, width: 2),
                          borderRadius:
                              BorderRadius.circular(styles.corners.sm),
                        ),
                      ),
                      focusedPinTheme: PinTheme(
                        width: 75 * styles.scale,
                        height: 75 * styles.scale,
                        textStyle: TextStyle(
                          fontSize: 20,
                          color: styles.theme.text,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: styles.theme.secondary,
                          border:
                              Border.all(color: styles.theme.primary, width: 2),
                          borderRadius:
                              BorderRadius.circular(styles.corners.sm),
                        ),
                      ),
                      followingPinTheme: PinTheme(
                        width: 75 * styles.scale,
                        height: 75 * styles.scale,
                        textStyle: TextStyle(
                          fontSize: 20,
                          color: styles.theme.text,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: styles.theme.background,
                          borderRadius: BorderRadius.circular(
                            styles.corners.sm,
                          ),
                        ),
                      ),
                      errorPinTheme: PinTheme(
                        width: 75 * styles.scale,
                        height: 75 * styles.scale,
                        textStyle: TextStyle(
                          fontSize: 20,
                          color: styles.theme.text,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: styles.theme.background,
                          border: Border.all(
                            color: styles.theme.primary.withValues(alpha: 0.25),
                          ),
                          borderRadius: BorderRadius.circular(
                            styles.corners.sm,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Gap(styles.insets.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resend in: 59s',
                        style: styles.typography.overline
                            .textColor(styles.theme.primary)
                            .textHeight(0),
                      ),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: "Didn't get it? ",
                          style: styles.typography.overline
                              .textColor(styles.theme.text)
                              .textHeight(0),
                          children: [
                            TextSpan(
                              text: 'Click here',
                              style: styles.typography.overline
                                  .textColor(styles.theme.primary)
                                  .underline(styles.theme.primary)
                                  .textHeight(0),
                              recognizer: TapGestureRecognizer()..onTap = () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(195),
                  AppBtn.from(
                    onPressed: () => context.push(ScreenPaths.dashBoard),
                    semanticLabel: '',
                    expand: true,
                    corner: styles.corners.x24,
                    text: 'Continue',
                    iconColor: styles.theme.white,
                    bgColor: styles.theme.primary,
                    padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                    minimumSize: const Size(0, 56),
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
