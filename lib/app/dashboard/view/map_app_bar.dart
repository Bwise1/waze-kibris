import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sheet/sheet.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:waze_kibris/common.dart';

class MapAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MapAppBar({required this.controller, super.key});
  final SheetController controller;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  State<MapAppBar> createState() => _MapAppBarState();
}

class _MapAppBarState extends State<MapAppBar> {
  bool scrolled = false;
  late VoidCallback _animationListener;
  
  @override
  void initState() {
    super.initState();
    _animationListener = () {
      if (!mounted) return; // Prevent setState after dispose
      final animationValue = widget.controller.animation.value;
      if (animationValue > 0.3) {
        setState(() {
          scrolled = true;
        });
      } else {
        setState(() {
          scrolled = false;
        });
      }
    };
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.animation.addListener(_animationListener);
    });
  }
  
  @override
  void dispose() {
    widget.controller.animation.removeListener(_animationListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: scrolled
          ? AppBar(
              key: const ValueKey('scrolled'),
              elevation: 1,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              automaticallyImplyLeading: false,
              leadingWidth: 50 + styles.insets.sm,
              leading: BackBtn.close(
                onPressed: () async {
                  await widget.controller.relativeAnimateTo(
                    0.3,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                },
              ).padding(left: 16, top: 4),
            )
          : AnimatedBuilder(
              key: const ValueKey('nonScrolled'),
              animation: widget.controller.animation,
              builder: (BuildContext context, Widget? child) {
                final sheetBar = widget.controller.animation.value > 0.98;
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: sheetBar ? 1 : 0),
                  duration: const Duration(milliseconds: 200),
                  builder: (BuildContext context, double t, Widget? child) {
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: 1,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: context.mq.padding.top,
                        ),
                        height: kToolbarHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(),
                            const SizedBox(),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}