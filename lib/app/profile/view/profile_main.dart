import 'package:flutter/material.dart';
import 'package:waze_kibris/app/profile/modals/edit_location_modal.dart';
import 'package:waze_kibris/common.dart';

class ProfileMainScreen extends StatelessWidget {
  const ProfileMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                        onPressed: () {},
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
    this.titleColor,  this.isImageFile=false,
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

              isImageFile==true?SizedBox(height:30,width: 30,child: Image.asset(icon) ,):
              AppIcon(
                icon,
                size: 20,
                color: styles.theme.grey,
              ),
              const Gap(16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
