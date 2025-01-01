import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/common.dart';

class ProfileMainScreen extends StatelessWidget {
  const ProfileMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(child:Stack(
      children: [
        SizedBox(
          width: context.widthPx,
          height: context.heightPx,
          child:
          Assets.images.introGradientPng.image(fit: BoxFit.cover  ),
        ),


        SingleChildScrollView(
          // padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),

          child: Column(
            children: [

              CustomContainer(
                width: context.widthPx,
                padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),

                borderRadius: BorderRadius.only(bottomLeft:  Radius.circular(styles.corners.md),bottomRight: Radius.circular(styles.corners.lg),),
                color: styles.theme.background,child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                Gap(54*styles.scale),
                CircleAvatar(
                  radius: 47,
                  backgroundColor: styles.theme.secondary,

                  child: ClipOval(
                    child: Assets.images.profilePic.image(height: 88, width:84,fit: BoxFit.cover),
                  ),
                )
                ,              const Gap(1),
                Text(
                  'Grace Opata',
                  style: styles.typography.h3.textColor(styles.theme.text),
                ),
                  Gap(styles.insets.md),

                  ProfileActionItemButton(icon: Assets.icons.profile, title: "Personal Information", semanticLabel: 'profile-action-btn',),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: styles.theme.secondary,),
                  ),
                  ProfileActionItemButton(icon: Assets.icons.shieldZap, title: "Login and Privacy", semanticLabel: 'profile-action-btn',),
  Gap(styles.insets.md),
              ],),),
              Gap(styles.insets.xs),


              CustomContainer(
                width: context.widthPx,
                padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),

                borderRadius: BorderRadius.only(bottomLeft:  Radius.circular(styles.corners.md),bottomRight: Radius.circular(styles.corners.lg),),
                color: styles.theme.background,child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,
                 children: [

                  Gap(styles.insets.md),
                Text(
                  'Saved Locations',
                  style: styles.typography.h5.textColor(styles.theme.text),
                ),
                  Gap(styles.insets.md),

                  ProfileActionItemButton(icon: Assets.icons.profile, title: "Personal Information", semanticLabel: 'profile-action-btn',),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: styles.theme.secondary,),
                  ),
                  ProfileActionItemButton(icon: Assets.icons.shieldZap, title: "Login and Privacy", semanticLabel: 'profile-action-btn',),
  Gap(styles.insets.md),
              ],),),



            ],
          ),
        ),
      ],
    ),




    )
;  }
}

class ProfileActionItemButton extends StatelessWidget {
  const ProfileActionItemButton({
    super.key, required this.icon, required this.title, this.onPressed, required this.semanticLabel,
  });
final String icon;
final String title;
  // interaction:
  final VoidCallback? onPressed;
   final String semanticLabel;
  @override
  Widget build(BuildContext context) {
    return AppBtn.basic(
      onPressed:onPressed,
      semanticLabel: semanticLabel,
      child: Row(
        children: [SvgPicture.asset(icon,height: 24,width: 24,),Gap(16),
          Text(title, style: styles.typography.caption.copyWith(color: styles.theme.text,fontStyle: FontStyle.normal),),],),
    );
  }
}
