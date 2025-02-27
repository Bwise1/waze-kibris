import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class ReportEventModal extends StatelessWidget {
  const ReportEventModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(styles.insets.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 68,
            decoration: BoxDecoration(
              color: styles.theme.grey.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Gap(styles.insets.sm),
          Text('What do you see', style: styles.typography.f.size(20).bold),
          Text(
            'Aid others by telling us what you see',
            style: styles.typography.t3.textColor(styles.theme.caption),
          ),
          GridView.builder(
            itemCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 19,
            ),
            itemBuilder: (context, index){
              return GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: styles.theme.white,
                    borderRadius: BorderRadius.circular(styles.corners.md),
                    boxShadow: styles.shadows.md,
                  ),
                  padding: EdgeInsets.all(styles.insets.md),
                  child: Column(
                    children: [
                      Assets.icons.accident.image(),
                      Gap(styles.insets.xs),
                      Text('Pothole', style: styles.typography.t3.bold),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
