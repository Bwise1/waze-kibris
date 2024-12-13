import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/widgets/containers/container.dart';

class OnboardScreen extends StatelessWidget {
  const OnboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(

      child: Column(children: [
        AppHeader(

          backIcon: Assets.icons.routeLogo,

          trailing: (context)=>CustomContainer(
            width:44 ,height: 44,

            color: styles.theme.background,border: Border.all(color:styles.theme.border),borderRadius: BorderRadius.circular(4),
              child:AppIcon(Assets.icons.moon,size: 24,
                color: styles.theme.black,
              ),
      ),),
SizedBox(
height: 216,width:216,
  child: Image.asset(Assets.images.route3d.keyName),),


        SizedBox(height:16),

        Text('Avoid holdups and heavy traffic jams',style:styles.typography.t1.copyWith(color: styles.theme.text,fontWeight:FontWeight.w600 ),)


        ,SizedBox(height:8),

        Text('We give you the best routes in real-time so you can get to your location on time',style:styles.typography.body.copyWith(color: styles.theme.grey,fontWeight:FontWeight.w400,  ),textAlign: TextAlign.center,)

        ,SizedBox(height:16),

        SlideIndicator(),



      ],),
    );
  }
}


class SlideIndicator extends StatelessWidget {
  const SlideIndicator({super.key,   this.numOfIndicator=1});

  final int  numOfIndicator;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: List.generate(numOfIndicator, (context)=>CustomContainer(width: 40,height: 2,
      margin:EdgeInsets.only(right: styles.corners.md ),
      color: styles.theme.primary,
      borderRadius:BorderRadius.circular( styles.corners.md),)
    ),);
  }
}
