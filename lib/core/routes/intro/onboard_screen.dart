import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/widgets/containers/container.dart';

class OnboardScreen extends StatelessWidget {
  const OnboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(

      child: Column(children: [
        AppHeader(backIcon: Assets.icons.routeLogo,trailing: (context)=>AppIcon(Assets.icons.moon,size: 44,color: styles.theme.black,),)

,CustomContainer(width:44 ,)
      ],),
    );
  }
}
