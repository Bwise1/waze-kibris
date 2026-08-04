import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waze_kibris/app/profile/modals/edit_location_modal.dart';
import 'package:waze_kibris/app/profile/view/profile_picture_sheet.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/models/auth/auth_response.dart';

class ProfileMainScreen extends StatefulWidget {
  const ProfileMainScreen({super.key});

  @override
  State<ProfileMainScreen> createState() => _ProfileMainScreenState();
}

class _ProfileMainScreenState extends State<ProfileMainScreen> {
  // Snapshot of the latest user from the bloc. Updated via BlocListener
  // so we always redraw even when two AuthSuccess states are Equatable-equal
  // (same props but different data — e.g. name changed but updated_at
  // precision didn't differ).
  User? _user;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AuthBloc>().state;
    if (s is AuthSuccess) _user = s.user;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          setState(() {
            _user = state.user;
            _isUpdating = false;
          });
        } else if (state is ProfileUpdating) {
          setState(() => _isUpdating = true);
        } else if (state is ProfileUpdateFailed) {
          setState(() => _isUpdating = false);
        }
      },
      child: SafeArea(
      child: Stack(
        children: [
          const GradientBG(),
          SingleChildScrollView(
            child: Column(
              children: [
                CustomContainer(
                  width: context.widthPx,
                  padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(styles.corners.md),
                    bottomRight: Radius.circular(styles.corners.lg),
                  ),
                  color: styles.theme.background,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Gap(54 * styles.scale),
                      Column(
                            children: [
                              _AvatarWithEdit(
                                user: _user,
                                isUpdating: _isUpdating,
                                onTap: () =>
                                    ProfilePictureSheet.show(context),
                              ),
                              const Gap(4),
                              Text(
                                _user?.displayName ?? '—',
                                style: styles.typography.h3
                                    .textColor(styles.theme.text),
                              ),
                              if (_user?.username != null) ...[
                                const Gap(2),
                                InkWell(
                                  onTap: () =>
                                      context.push(ScreenPaths.changeUsername),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '@${_user!.username}',
                                        style: styles.typography.body
                                            .textColor(styles.theme.ash),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        _user!.canChangeUsername
                                            ? Icons.edit_outlined
                                            : Icons.lock_outline,
                                        size: 14,
                                        color: styles.theme.ash,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                      Gap(styles.insets.md),
                      ProfileActionItemButton(
                        icon: Assets.icons.profile,
                        title: 'Personal Information',
                        semanticLabel: 'profile-action-btn',
                        onPressed: () =>
                            context.push(ScreenPaths.personalInformation),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      ProfileActionItemButton(
                        icon: Assets.icons.shieldZap,
                        title: 'Login and Privacy',
                        semanticLabel: 'profile-action-btn',
                      ),
                      Gap(styles.insets.md),
                    ],
                  ),
                ),
                Gap(styles.insets.xs),
                CustomContainer(
                  width: context.widthPx,
                  padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(styles.corners.md),
                    bottomRight: Radius.circular(styles.corners.lg),
                  ),
                  color: styles.theme.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(styles.insets.md),
                      Text(
                        'Saved Locations',
                        style:
                            styles.typography.h5.textColor(styles.theme.text),
                      ),
                      Gap(styles.insets.md),
                      ProfileActionItemButton(
                        onPressed: () => CustomDialogRoutes.openBottomSheet(
                          context,
                          const EditLocationModal(),
                        ),
                        icon: Assets.icons.homeSmile,
                        title: 'Home',
                        subTitle: 'Address',
                        semanticLabel: 'home-action-btn',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      ProfileActionItemButton(
                        icon: Assets.icons.briefcaseSvg,
                        title: 'Office',
                        subTitle: 'Address',
                        semanticLabel: 'office-action-btn',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      ProfileActionItemButton(
                        onPressed: () {},
                        icon: Assets.icons.plusSvg,
                        title: 'Add new location',
                        semanticLabel: 'add-action-btn',
                      ),
                      Gap(styles.insets.md),
                    ],
                  ),
                ),
                Gap(styles.insets.xs),
                CustomContainer(
                  width: context.widthPx,
                  padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(styles.corners.md),
                    bottomRight: Radius.circular(styles.corners.lg),
                  ),
                  color: styles.theme.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Gap(styles.insets.md),
                      Text(
                        'Settings',
                        style:
                            styles.typography.h5.textColor(styles.theme.text),
                      ),
                      Gap(styles.insets.md),
                      ProfileActionItemButton(
                        onPressed: () {
                          context.push(ScreenPaths.soundSettings);
                        },
                        icon: Assets.icons.microphone,
                        title: 'Sound',
                        semanticLabel: 'sound-action-btn',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      ProfileActionItemButton(
                        onPressed: () {
                          context.push(ScreenPaths.helpAndFeedback);
                        },
                        icon: 'Assets.icons.chat',
                        title: 'Help & Feedback',
                        semanticLabel: 'help-action-btn',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      ProfileActionItemButton(
                        onPressed: () {
                          context.push(ScreenPaths.aboutUs);
                        },
                        icon: 'Assets.icons.chat',
                        title: 'About us',
                        semanticLabel: 'about-action-btn',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      ProfileActionItemButton(
                        onPressed: () {
                          context.push(ScreenPaths.deleteAccount);
                        },
                        icon: Assets.icons.bin,
                        titleColor: styles.theme.red,
                        title: 'Delete account',
                        semanticLabel: 'delete-action-btn',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: styles.theme.secondary,
                        ),
                      ),
                      ProfileActionItemButton(
                        onPressed: () {
                          context.read<AuthBloc>().add(
                                const LogoutRequested(),
                              );
                        },
                        icon: Assets.icons.bin,
                        titleColor: styles.theme.red,
                        title: 'Logout',
                        semanticLabel: 'logout-action-btn',
                      ),
                      Gap(styles.insets.md),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// Avatar with a tap-to-change camera badge in the corner. Handles three
/// display sources: uploaded URL (starts with http), preset asset filename
/// (matches one of `assets/user_profiles/`), or default profile-pic image.
class _AvatarWithEdit extends StatelessWidget {
  const _AvatarWithEdit({
    required this.user,
    required this.isUpdating,
    required this.onTap,
  });
  final User? user;
  final bool isUpdating;
  final VoidCallback onTap;

  ImageProvider _resolveAvatar() {
    final icon = user?.profileIcon;
    if (icon == null || icon.isEmpty) {
      return const AssetImage('assets/images/profile_pic.png');
    }
    if (icon.startsWith('http')) {
      return NetworkImage(icon);
    }
    // Assume preset asset filename.
    return AssetImage('assets/user_profiles/$icon');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUpdating ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 47,
            backgroundColor: styles.theme.secondary,
            backgroundImage: _resolveAvatar(),
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
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.photo_camera,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileActionItemButton extends StatelessWidget {
  const ProfileActionItemButton({
    required this.semanticLabel,
    required this.icon,
    required this.title,
    super.key,
    this.onPressed,
    this.subTitle = '',
    this.trailing,
    this.titleStyle,
    this.titleColor,
    this.isImageFile = false,
  });
  final String icon;
  final String title;
  final String subTitle;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final Color? titleColor;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool isImageFile;
  @override
  Widget build(BuildContext context) {
    return AppBtn.basic(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isImageFile == true)
                SizedBox(
                  height: 25,
                  width: 25,
                  child: Image.asset(icon),
                )
              else
                AppIcon(
                  icon,
                  size: 20,
                  color: styles.theme.grey,
                ),
              const Gap(16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(3),
                  Text(
                    title,
                    style: titleStyle ??
                        styles.typography.t2
                            .textColor(styles.theme.black)
                            .medium,
                  ),
                  if (subTitle != '') ...[
                    const Gap(4),
                    Text(
                      subTitle,
                      style:
                          styles.typography.t3.textColor(styles.theme.caption),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}
