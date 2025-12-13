import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/common.dart';

class SegmentedTab extends StatelessWidget {
  const SegmentedTab({
    super.key,
    this.sections = defaults,
    this.index = 0,
    this.onTabPressed,
    this.color,
    this.textSize,
  });
  final void Function(int)? onTabPressed;
  final List<TabSection> sections;
  final int index;
  final Color? color;
  final double? textSize;

  static const List<TabSection> defaults = [
    TabSection(label: 'Test'),
    TabSection(label: 'Foo'),
    TabSection(label: 'Bar'),
  ];

  @override
  Widget build(BuildContext context) {
    final clickableLabels = sections
        .map(
          (section) => _clickableLabel(
            section,
            index == sections.indexOf(section),
          ),
        )
        .toList();

    final targetAlignX = -1 + (index * 1 / (sections.length - 1)) * 2;

    return RepaintBoundary(
      child: Stack(
        children: <Widget>[
          _roundedBox(fill: styles.theme.grey.withValues(alpha: .05)),
          _roundedBox(fill: styles.theme.white)
              .fractionallySizedBox(widthFactor: 1 / sections.length)
              .alignment(Alignment(targetAlignX, 0))
              .padding(all: styles.insets.xxs),
          Row(children: clickableLabels),
        ],
      ).height(40).padding(),
    );
  }

  Widget _roundedBox({double? width, Color? border, Color? fill}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(styles.corners.jumbo),
        border: Border.all(
          color: border?.withValues(alpha: .35) ?? Colors.transparent,
        ),
      ),
    );
  }

  Widget _clickableLabel(TabSection section, bool isSelected) {
    final selectedColor = color ?? styles.theme.grey;
    final notSelectedColor = styles.theme.caption;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onTabPressed?.call(sections.indexOf(section)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: styles.insets.xs,
        children: [
          if (section.icon != null)
            AppIcon(
              section.icon!,
              size: 16,
              color: isSelected ? selectedColor : notSelectedColor,
            ),
          if (section.label != null)
            Text(
              section.label!,
              style: styles.typography.t2
                  .textColor(isSelected ? selectedColor : notSelectedColor)
                  .size(textSize ?? 14.0),
            ),
        ],
      ).center(),
    ).expanded();
  }
}

class TabSection {
  const TabSection({this.label, this.icon});
  final String? label;
  final String? icon;
}
