import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/widgets/buttons/social_media_button.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 50 + styles.insets.sm,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Padding(
          padding: EdgeInsets.only(left: styles.insets.sm, top: 4),
          child: BackBtn(
            onPressed: () => context.pop(),
            semanticLabel: '',
            bgColor: Colors.transparent,
            iconColor: styles.theme.grey,
            borderSide: BorderSide(
              color: styles.theme.nu1,
            ),
          ),
        ),
        actions: [
          AppIcon(
            Assets.icons.routeLogo,
            color: styles.theme.grey,
            size: 45,
          ),
          Gap(styles.insets.sm),
        ],
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            RSnackBar.error(state.message).show(context);
          }
          if (state is OtpSent) {
            context.go(ScreenPaths.verifyEmail);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              const GradientBG(),
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
                            style: styles.typography.h4
                                .textColor(styles.theme.ash),
                          ),
                        ],
                      ),
                      onChanged: (value) {},
                      controller: _emailController,
                    ),
                    Gap(styles.insets.sm),
                    PrimaryButton(
                      textColor: styles.theme.white,
                      isLoading: state is AuthLoading,
                      onPressed: () {
                        context.read<AuthBloc>().add(
                              AuthEvent.loginRequested(
                                email: _emailController.text,
                              ),
                            );
                      },
                      text: 'Continue',
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
                              style: styles.typography.body
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
                    CustomClickableText(
                      text: 'Having troubles logging in?',
                      style: styles.typography.body
                          .textColor(styles.theme.primary)
                          .underline(styles.theme.primary),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
