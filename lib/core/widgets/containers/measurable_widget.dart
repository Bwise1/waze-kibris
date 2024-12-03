import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MeasurableWidget extends SingleChildRenderObjectWidget {
  const MeasurableWidget({
    required this.onChange, required Widget super.child, super.key,
  });
  final void Function(Size size) onChange;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      MeasureSizeRenderObject(onChange);
}

class MeasureSizeRenderObject extends RenderProxyBox {
  MeasureSizeRenderObject(this.onChange);
  void Function(Size size) onChange;

  Size _prevSize = Size.zero;
  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size ?? Size.zero;
    if (_prevSize == newSize) return;
    _prevSize = newSize;
    scheduleMicrotask(() => onChange(newSize));
  }
}
