import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/common.dart';

class CustomRoundedCheck extends StatefulWidget {
  const CustomRoundedCheck({
    required this.value,
    required this.onChanged,
    super.key,
    this.duration = const Duration(milliseconds: 200),
    this.size = 25,
    this.radius = 4,
    this.color,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final Duration duration;
  final double size;
  final double radius;
  final Color? color;

  @override
  State<CustomRoundedCheck> createState() => _CustomRoundedCheckState();
}

class _CustomRoundedCheckState extends State<CustomRoundedCheck>
    with SingleTickerProviderStateMixin {
  late bool _isChecked;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: 0.9, // This defines the minimum scale
    );
  }

  @override
  void didUpdateWidget(covariant CustomRoundedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isChecked != widget.value) {
      setState(() {
        _isChecked = widget.value;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCheckbox() {
    setState(() {
      _isChecked = !_isChecked;
      widget.onChanged(_isChecked);
      // Perform scale animation on tap
      _controller.forward().then((_) => _controller.reverse());
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCheckbox,
      child: Container(
        height: widget.size,
        width: widget.size,
        padding: EdgeInsets.all(styles.insets.xxs),
        decoration: BoxDecoration(
          color: (widget.color ?? styles.theme.primary).withValues(alpha: .2),
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: widget.color ?? styles.theme.primary,
            width: 1.5,
          ),
        ),
        child: AnimatedScale(
          scale: _isChecked ? 1.0 : 0.9, // Scale animation toggling
          duration: widget.duration,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: _isChecked
                  ? (widget.color ?? styles.theme.primary)
                  : styles.theme.white,
            ),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }
}

enum StyledCheckboxValue {
  all,
  none,
  partial,
}

class CustomCheckBox extends StatelessWidget {
  const CustomCheckBox({
    super.key,
    this.value = StyledCheckboxValue.none,
    this.size = 18,
    this.onChanged,
  });
  final StyledCheckboxValue value;
  final double size;
  final void Function(StyledCheckboxValue)? onChanged;

  void _handleTapUp(TapUpDetails details) {
    switch (value) {
      case StyledCheckboxValue.all:
        onChanged?.call(StyledCheckboxValue.none);
      case StyledCheckboxValue.none:
        onChanged?.call(StyledCheckboxValue.partial);
      case StyledCheckboxValue.partial:
        onChanged?.call(StyledCheckboxValue.all);
    }
  }

  Widget _getIconForCurrentState() {
    switch (value) {
      case StyledCheckboxValue.all:
        return const Padding(
          padding: EdgeInsets.all(3),
          child: AppIcon('Assets.icons.regular.tick'),
        );
      case StyledCheckboxValue.none:
        return Container();
      case StyledCheckboxValue.partial:
        return const AppIcon('Assets.icons.regular.minus');
    }
  }

  Widget _wrapGestures(Widget child) {
    if (onChanged == null) return child;
    return child.gestures(
      onTapUp: _handleTapUp,
      behavior: HitTestBehavior.opaque,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: value == StyledCheckboxValue.none
            ? Colors.transparent
            : styles.theme.primary,
        borderRadius: BorderRadius.circular(styles.corners.sm),
        border: Border.all(
          color: value == StyledCheckboxValue.none
              ? styles.theme.primary
              : styles.theme.primary,
          width: 2,
        ),
      ),
      child: _wrapGestures(_getIconForCurrentState()),
    );
  }
}
