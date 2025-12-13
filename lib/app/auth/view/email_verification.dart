import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';

class EmailVerification extends StatefulWidget {
  const EmailVerification({super.key});

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> {
  String _otpCode = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            RSnackBar.error(state.message).show(context);
          }
          if (state is AuthSuccess) {
            context.go(ScreenPaths.dashBoard);
          }
        },
        builder: (context, state) {
          var email = '';

          if(state is OtpSent){
            email = state.email;
          }

          return Stack(
            children: [
              SizedBox(
                width: context.widthPx,
                height: context.heightPx,
                child: Assets.images.introGradientPng.image(fit: BoxFit.cover),
              ),
              AppHeader(
                isTransparent: true,
                backIcon: Assets.icons.backArrow,
                trailing: (context) => BackBtn(
                  icon: Assets.icons.routeLogo,
                  semanticLabel: 'Back Button',
                  bgColor: Colors.transparent,
                  iconColor: styles.theme.grey,
                ),
                onBack: () => context.pop(),
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
                        style:
                            styles.typography.h3.textColor(styles.theme.text),
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
                              text: email,
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
                              border: Border.all(
                                color: styles.theme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(
                                styles.corners.sm,
                              ),
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
                              border: Border.all(
                                color: styles.theme.primary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(
                                styles.corners.sm,
                              ),
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
                                color: styles.theme.primary
                                    .withValues(alpha: 0.25),
                              ),
                              borderRadius: BorderRadius.circular(
                                styles.corners.sm,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _otpCode = value;
                            });
                          },
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
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(195),
                      PrimaryButton(
                        isLoading: state is AuthLoading,
                        onPressed: () {
                          context.read<AuthBloc>().add(
                                AuthEvent.verifyOtpRequested(
                                  email: email,
                                  code: _otpCode,
                                  type: 'login',
                                ),
                              );
                        },
                        text: 'Continue',
                        bgColor: styles.theme.primary,
                        textColor: styles.theme.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
