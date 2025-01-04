import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/app/profile/view/profile_main.dart';
import 'package:waze_kibris/common.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(

      child:
      Column(
        children: [
          AppHeader(
            backIcon: Assets.icons.backArrow,


            isTransparent: true,
          ),


          Padding(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Gap(16*styles.scale),
                  Text(
                    'Sound setting',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ).alignment(Alignment.bottomLeft),
                  Gap(8*styles.scale),

                  Text(
                    ' Take full control of your voice and sound controls. All your sound settings are here ',
                    style: styles.typography.hairline.textColor(styles.theme.ash),
                  ).alignment(Alignment.bottomLeft),

                  Gap(16*styles.scale),

                  Row(children: [
                    Text(
                      'Sounds',
                      style: styles.typography.h3.textColor(styles.theme.text),
                    )

                  ],),
                  Gap(24*styles.scale),


                  ProfileActionItemButton(

                    onPressed: (){
                      context.push(ScreenPaths.updateUserName);
                    },
                    icon: Assets.icons.profile, title: 'Grace Opata',
                    semanticLabel: 'name-action-btn',
                    trailing: Text('Edit', style: styles.typography.hairline.textColor(styles.theme.primary)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: styles.theme.secondary,),
                  ),

                  ProfileActionItemButton(

                    onPressed: (){
                      context.push(ScreenPaths.signIn);
                    },
                    icon: Assets.icons.at, title: "fullname@gmail.com", semanticLabel: 'email-action-btn',trailing: Text("Edit", style: styles.typography.hairline.textColor(styles.theme.primary),),),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
