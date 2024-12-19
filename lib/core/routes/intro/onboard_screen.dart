import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/widgets/containers/container.dart';

import '../../widgets/misc/slide_indicator.dart';

class OnboardScreen extends StatelessWidget {
  const OnboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(

      child: Column(
        children: [
          AppHeader(

            backIcon: Assets.icons.routeLogo,

            trailing: (context)=>CustomContainer(
              width:44 ,height: 44,

              color: styles.theme.background,border: Border.all(color:styles.theme.border),borderRadius: BorderRadius.circular(4),
              child:AppIcon(Assets.icons.moon,size: 24,
                color: styles.theme.black,
              ),
            ),






          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [

            SizedBox(
            height: 216,width:216,
              child: Image.asset(Assets.images.route3d.keyName),),


             const Gap( 16),

              Text('Avoid holdups and heavy traffic jams',style:styles.typography.t1.copyWith(color: styles.theme.text,fontWeight:FontWeight.w600 ),)


              ,const Gap( 8),

              Text('We give you the best routes in real-time so you can get to your location on time',style:styles.typography.hairline.copyWith(color: styles.theme.grey,fontWeight:FontWeight.w400,  ),textAlign: TextAlign.center,)

              ,const Gap( 16),

              SlideIndicator(numOfIndicator: 3,),
              const Gap( 44),
            PrimaryButton(text: 'Get Started',),
             const Gap( 44),

              PrimaryButton(text: 'Log in',bgColor: styles.theme.secondary,textColor: styles.theme.primary,),
              const Gap( 24),

              Wrap(
                alignment: WrapAlignment.center,
                children: [
                Text('By signing up, you have agreed to our.',style:styles.typography.hairline.copyWith(color: styles.theme.grey)),
                Text('Terms & Conditions',style:styles.typography.hairline.copyWith(color: styles.theme.primary)),
                Text(',acknowledge our',style:styles.typography.hairline.copyWith(color: styles.theme.grey)),
                Text('Privacy Policy',style:styles.typography.hairline.copyWith(color: styles.theme.primary)),
                Text(',and confirm that you are an adult.',style:styles.typography.hairline.copyWith(color: styles.theme.grey)),
              ],)
            ],),
          ),
        ],
      ),
    );
  }
}


