import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/widgets/containers/container.dart';


class SlideIndicator extends StatelessWidget {
  const SlideIndicator({super.key,   this.numOfIndicator=1,   this.activeIndex=0});

  final int  numOfIndicator;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: List.generate(numOfIndicator, (index)=>CustomContainer(width: 40,height: 2,
        margin:EdgeInsets.only(right: styles.corners.md ),
        color: index==activeIndex
            ?styles.theme.primary:styles.theme.nu3,
        borderRadius:BorderRadius.circular( styles.corners.md),)
      ),);
  }
}
