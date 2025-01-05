import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

import 'package:waze_kibris/core/widgets/dialogs/custom_dialog.dart';

class ProfileMainScreen extends StatelessWidget {
  const ProfileMainScreen({super.key});

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
          SingleChildScrollView(
            // padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),

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
                      CircleAvatar(
                        radius: 47,
                        backgroundColor: styles.theme.secondary,
                        child: ClipOval(
                          child: Assets.images.profilePic
                              .image(height: 88, width: 84, fit: BoxFit.cover),
                        ),
                      ),
                      const Gap(1),
                      Text(
                        'Grace Opata',
                        style:
                            styles.typography.h3.textColor(styles.theme.text),
                      ),
                      Gap(styles.insets.md),
                      ProfileActionItemButton(
                        icon: Assets.icons.profile,
                        title: 'Personal Information',
                        semanticLabel: 'profile-action-btn',
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
                        onPressed: () {
                          CustomDialog.openBottomSheet(
                            context,
                            Column(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SvgPicture.asset(
                                          Assets.icons.homeSmile,
                                          height: 24,
                                          width: 24,
                                        ),
                                        const Gap(8),
                                        Text(
                                          'Home',
                                          style: styles.typography.t3.copyWith(
                                            color: styles.theme.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Gap(8),
                                    Text(
                                      'Address',
                                      style: styles.typography.t3
                                          .textColor(styles.theme.ash)
                                          .medium,
                                    ),
                                  ],
                                ),

                                const Gap(32),
                                Row(
                                  children: [
                                    AppIcon(
                                      Assets.icons.flagMarker,
                                      size: 34,
                                      color: styles.theme.ash,
                                    ),
                                    const Gap(16),
                                    Text(
                                      'Edit this location',
                                      style: styles.typography.caption.copyWith(
                                        color: styles.theme.ash,
                                        fontStyle: FontStyle.normal,
                                      ),
                                    ),
                                  ],
                                ), //
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 17,
                                  ),
                                  child: Divider(
                                    color: styles.theme.secondary,
                                  ),
                                ),

                                Row(
                                  children: [
                                    AppIcon(
                                      Assets.icons.bin,
                                      size: 34,
                                      color: styles.theme.primary,
                                    ),
                                    const Gap(16),
                                    Text(
                                      'Remove location',
                                      style: styles.typography.caption.copyWith(
                                        color: styles.theme.primary,
                                        fontStyle: FontStyle.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
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
                        icon: Assets.icons.briefcase,
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
                        icon: Assets.icons.plus,
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
                        icon: Assets.icons.chat,
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
                        icon: Assets.icons.chat,
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
                        onPressed: () {},
                        icon: Assets.icons.bin,
                        titleColor: styles.theme.red,
                        title: 'Logout',
                        semanticLabel: 'logout-action-btn',
                      ),
                      Gap(styles.insets.md),
                      const ModalHeader(
                        title: 'Hello',
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
  });
  final String icon;
  final String title;
  final String subTitle;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final Color? titleColor;
  // interaction:
  final VoidCallback? onPressed;
  final String semanticLabel;
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
              AppIcon(
                icon,
                size: 24,
              ),
              const Gap(16),
              Column(
                children: [
                  Text(
                    title,
                    style: titleStyle ??
                        styles.typography.caption.copyWith(
                          color: titleColor ?? styles.theme.text,
                          fontStyle: FontStyle.normal,
                        ),
                  ),
                  if (subTitle != '') ...[
                    Text(
                      subTitle,
                      style: styles.typography.caption.copyWith(
                        color: styles.theme.ash,
                        fontStyle: FontStyle.normal,
                      ),
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
