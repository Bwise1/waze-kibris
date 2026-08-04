import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/profile/view/profile_panel.dart';
import 'package:waze_kibris/app/profile/view/profile_picture_sheet.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/app_router.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';

class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      // Also rebuild during ProfileUpdating so we can show the loading state
      // on the avatar, and ProfileUpdateFailed for the snackbar case.
      buildWhen: (prev, curr) =>
          curr is AuthSuccess ||
          curr is AuthLoading ||
          curr is ProfileUpdating,
      builder: (context, state) {
        final user = state is AuthSuccess ? state.user : null;
        final firstName = user?.firstName?.trim() ?? '';
        final lastName = user?.lastName?.trim() ?? '';
        final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
        final email = user?.email ?? '';
        final profileIcon = user?.profileIcon;
        final username = user?.username;
        final canChangeUsername = user?.canChangeUsername ?? true;
        final isUpdating = state is ProfileUpdating;

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
                      'Tap your photo to change it. Tap your @username to change it (once only).',
                      style:
                          styles.typography.body.textColor(styles.theme.ash),
                    ).alignment(Alignment.centerLeft),
                    Gap(24 * styles.scale),
                    // Tappable avatar with camera badge — opens the picker
                    // sheet (preset avatars + upload from library).
                    Center(
                      child: _EditableAvatar(
                        profileIcon: profileIcon,
                        name: fullName.isNotEmpty ? fullName : (user?.email ?? ''),
                        isUpdating: isUpdating,
                        onTap: () => ProfilePictureSheet.show(context),
                      ),
                    ),
                    Gap(32 * styles.scale),
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: fullName.isNotEmpty ? fullName : '—',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: styles.theme.secondary),
                    ),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: email.isEmpty ? '—' : email,
                    ),
                    if (username != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: styles.theme.secondary),
                      ),
                      // Username row: tappable when the user still has their
                      // one-shot; shows a lock icon otherwise so the state
                      // is obvious before they tap.
                      InkWell(
                        onTap: canChangeUsername
                            ? () => context.push(ScreenPaths.changeUsername)
                            : null,
                        child: Row(
                          children: [
                            Icon(Icons.alternate_email,
                                color: styles.theme.grey, size: 24),
                            Gap(16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@$username',
                                    style: styles.typography.t2
                                        .textColor(styles.theme.text),
                                  ),
                                  Text(
                                    canChangeUsername
                                        ? 'Tap to change (once only)'
                                        : 'Locked — contact support to change',
                                    style: styles.typography.caption
                                        .textColor(styles.theme.ash),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              canChangeUsername
                                  ? Icons.chevron_right
                                  : Icons.lock_outline,
                              color: styles.theme.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                    Gap(32 * styles.scale),
                    AppBtn.from(
                      onPressed: () {
                        context.push(ScreenPaths.updateUserName);
                      },
                      semanticLabel: 'edit-profile',
                      expand: true,
                      corner: styles.corners.x24,
                      text: 'Edit name',
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

/// Circular avatar with a small camera badge overlay in the bottom-right,
/// tappable to open the profile-picture picker sheet. Shows a translucent
/// spinner overlay while the bloc is uploading a new photo.
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    required this.profileIcon,
    required this.name,
    required this.isUpdating,
    required this.onTap,
  });
  final String? profileIcon;
  final String name;
  final bool isUpdating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Big avatar for the profile page — the panel-row default (28pt) is
    // right for a list item but way too small when the avatar is the
    // hero of its own screen.
    const double radius = 56;
    return GestureDetector(
      onTap: isUpdating ? null : onTap,
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfilePanel.buildProfileAvatar(
              context,
              profileIcon,
              name,
              radius: radius,
            ),
            if (isUpdating)
              const Positioned.fill(
                child: CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
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
