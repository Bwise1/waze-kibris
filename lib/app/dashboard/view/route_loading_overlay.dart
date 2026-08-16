import 'package:flutter/material.dart';

/// Full-screen loading overlay shown while fetching routes (Waze-style)
class RouteLoadingOverlay extends StatelessWidget {
  const RouteLoadingOverlay({
    this.message = 'Finding routes...',
    super.key,
  });

  final String message;

  /// Shows the loading overlay and returns a function to dismiss it.
  ///
  /// The dismiss closure removes exactly the dialog's own route. The old
  /// version stored the navigator and called a bare pop(): if the user
  /// backed out (or anything else changed the stack) while routes were
  /// still fetching, the deferred dismiss popped the map sheet or the
  /// place-details screen instead of the already-gone spinner — throwing
  /// the user out of the flow. It's also idempotent, since one error path
  /// calls it twice.
  static VoidCallback show(BuildContext context, {String? message}) {
    BuildContext? dialogContext;
    var dismissed = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (ctx) {
        dialogContext = ctx;
        return RouteLoadingOverlay(message: message ?? 'Finding routes...');
      },
    );

    return () {
      if (dismissed) return;
      dismissed = true;
      final ctx = dialogContext;
      // If the dialog is already gone (or never built), there is nothing
      // to remove — crucially, nothing ELSE gets popped in its place.
      if (ctx == null || !ctx.mounted) return;
      final route = ModalRoute.of(ctx);
      if (route == null) return;
      Navigator.of(ctx, rootNavigator: true).removeRoute(route);
    };
  }

  /// Hide the loading overlay (legacy method - prefer using the dismiss function from show())
  static void hide(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
