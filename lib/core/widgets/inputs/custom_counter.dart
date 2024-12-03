import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class CustomCounter extends StatefulWidget {
  const CustomCounter({
    required this.onChanged,
    super.key,
    this.initialValue = 0,
    this.maxValue = 10,
    this.minValue = 0,
    this.label,
  });
  final int initialValue;
  final int maxValue;
  final int minValue;
  final String? label;
  final ValueChanged<int> onChanged;

  @override
  State<CustomCounter> createState() => _CustomCounterState();
}

class _CustomCounterState extends State<CustomCounter> {
  late int currentValue;

  @override
  void initState() {
    currentValue = widget.initialValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(
            widget.label ?? '',
            style:
                styles.typography.t2.textColor(styles.theme.textPrimary).medium,
          ),
          Gap(styles.insets.xs),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(styles.corners.md),
            border: Border.all(color: styles.theme.nu2),
          ),
          child: Row(
            children: [
              IconButton(
                icon: AppIcon(
                  'Assets.icons.regular.minus',
                  color: styles.theme.grey,
                ),
                onPressed: () {
                  if (currentValue > widget.minValue) {
                    setState(() {
                      currentValue--;
                      widget.onChanged(currentValue);
                    });
                  }
                },
              ),
              Expanded(
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: styles.theme.grey,
                    borderRadius: BorderRadius.circular(styles.corners.jumbo),
                  ),
                  child: Center(
                    child: Text(
                      currentValue.toString(),
                      style: styles.typography.t2
                          .textColor(styles.theme.white)
                          .medium,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: AppIcon(
                  'Assets.icons.regular.plus',
                  color: styles.theme.grey,
                ),
                onPressed: () {
                  if (currentValue < widget.maxValue) {
                    setState(() {
                      currentValue++;
                      widget.onChanged(currentValue);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
