import 'package:flutter/material.dart';
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
                borderRadius: BorderRadius.only(bottomLeft:  Radius.circular(styles.corners.md),bottomRight: Radius.circular(styles.corners.lg),),
                color: styles.theme.background,child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                Gap(54*styles.scale),
                ClipOval(child: Assets.images.profilePic.image(height: 88, width:84,fit: BoxFit.cover))
                ,              const Gap(1),
                Text(
                  'Grace Opata',
                  style: styles.typography.h3.textColor(styles.theme.text),
                ),
                  const Gap(24),

                  // Row(children: [Assets.icons.profile.],)

              ],),),


              AppBtn.basic(onPressed: (){},
                  child: Text("Having troubles logging in?",style: styles.typography.hairline.textColor(styles.theme.primary).underline(styles.theme.primary),),
                  semanticLabel: "log-in-trouble"
              )
            ],
          ),
        ),
      ],
    ),




    )
;  }
}
