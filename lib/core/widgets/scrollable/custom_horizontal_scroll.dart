import 'package:flutter/material.dart';

class CustomHorizontalScroll extends StatefulWidget {

  const CustomHorizontalScroll({required this.child, super.key, this.physics});
  final Widget child;
  final ScrollPhysics? physics;

  @override
  State createState() => _CustomHorizontalScrollState();
}

class _CustomHorizontalScrollState extends State<CustomHorizontalScroll> {
  late ScrollController _controller;

  @override
  void initState() {
    _controller = ScrollController();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _controller,
      physics: widget.physics ?? const BouncingScrollPhysics(),
      child: widget.child,
    );
  }
}
