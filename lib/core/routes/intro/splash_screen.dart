 import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
 

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(


        body:Container(
width: context.widthPx,height: context.heightPx,


          decoration: BoxDecoration(

            color: Colors.red,
            image: DecorationImage
            (fit: BoxFit.cover
              ,image: AssetImage(Assets.images.splashBackground.keyName)
            ,),
          ),
child: AppIcon(Assets.icons.routeLogoText,color: styles.theme.white,size: 45,),
        )
      ,);
  }
}
