import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/profile/view/profile_panel.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/app_router.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';

class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) => curr is AuthSuccess || curr is AuthLoading,
      builder: (context, state) {
        final user = state is AuthSuccess ? state.user : null;
        final name = user?.displayName ?? 'Guest';
        final email = user?.email ?? '';
        final profileIcon = user?.profileIcon;

        return Column(
          children: [
            AppHeader(
              backIcon: Assets.icons.backArrow,
              isTransparent: true,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: styles.insets.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Gap(16 * styles.scale),
                    Text(
                      'Personal Information',
                      style: styles.typography.h3.textColor(styles.theme.text),
                    ).alignment(Alignment.centerLeft),
                    Gap(8 * styles.scale),
                    Text(
                      'Edit all personal information right here to allow us contact you on new updates and feature changes',
                      style: styles.typography.body.textColor(styles.theme.ash),
                    ).alignment(Alignment.centerLeft),
                    Gap(24 * styles.scale),
                    Center(
                      child: ProfilePanel.buildProfileAvatar(
                        context,
                        profileIcon,
                        name,
                      ),
                    ),
                    Gap(32 * styles.scale),
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: name.isEmpty ? '—' : name,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: styles.theme.secondary),
                    ),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: email.isEmpty ? '—' : email,
                    ),
                    Gap(32 * styles.scale),
                    AppBtn.from(
                      onPressed: () {
                        context.push(ScreenPaths.updateUserName);
                      },
                      semanticLabel: 'edit-profile',
                      expand: true,
                      corner: styles.corners.x24,
                      text: 'Edit profile',
                      iconColor: styles.theme.primary,
                      bgColor: styles.theme.secondary,
                      padding: EdgeInsets.symmetric(vertical: styles.insets.xs),
                      minimumSize: const Size(0, 56),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: styles.theme.grey, size: 24),
        Gap(16),
        Expanded(
          child: Text(
            label,
            style: styles.typography.t2.textColor(styles.theme.text),
          ),
        ),
      ],
    );
  }
}
