import 'package:flutter/material.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/common.dart';

class CustomSwitch extends StatefulWidget {
  const CustomSwitch({required this.onChanged, required this.value, super.key});
  final ValueChanged<bool> onChanged;
  final bool value;

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch> {
  bool onTapState = false;
  bool toggleState = false;
  static Color colorRed = styles.theme.red;
  static Color colorGreen = styles.theme.primary;

  @override
  void initState() {
    toggleState = widget.value;
    super.initState();
  }

  void _handleTap(bool newState) {
    setState(() {
      onTapState = newState;
    });
  }

  void _handleToggle() {
    setState(() => toggleState = !toggleState);
    widget.onChanged(toggleState);
  }

  Widget _styledBox({
    required Widget child,
    required bool tapState,
    required bool toggleState,
  }) {
    return child
        .padding(all: 5)
        .constrained(height: 25, width: 50)
        .ripple(splashColor: Colors.white.withValues(alpha: 0.1))
        .clipRRect(all: 25)
        .decorated(
          color: toggleState ? colorGreen : colorRed,
          borderRadius: BorderRadius.circular(30),
          animate: true,
        )
        .scale(all: tapState ? 0.95 : 1, animate: true);
  }

  Widget _styledOuterCircle({
    required Widget child,
    required bool toggleState,
  }) {
    return child
        .decorated(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        )
        .constrained(width: toggleState ? 8 : 15, height: 20, animate: true)
        .padding(right: toggleState ? 5 : 0, animate: true)
        .alignment(
          toggleState ? Alignment.centerRight : Alignment.centerLeft,
          animate: true,
        );
  }

  Widget _styledInnerCircle({required bool toggleState}) {
    return Styled.widget()
        .decorated(
          color: toggleState ? colorGreen : colorRed,
          borderRadius: BorderRadius.circular(6),
          animate: true,
        )
        .constrained(width: toggleState ? 0 : 5, height: 5, animate: true)
        .alignment(Alignment.center);
  }

  @override
  Widget build(BuildContext context) {
    return _styledInnerCircle(toggleState: toggleState)
        .parent(
          ({required Widget child}) =>
              _styledOuterCircle(child: child, toggleState: toggleState),
        )
        .parent(
          ({required Widget child}) => _styledBox(
            child: child,
            tapState: onTapState,
            toggleState: toggleState,
          ),
        )
        .gestures(onTapChange: _handleTap, onTap: _handleToggle)
        .animate(const Duration(milliseconds: 300), Curves.easeOut);
  }
}
