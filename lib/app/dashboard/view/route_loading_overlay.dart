import 'package:flutter/material.dart';

/// Full-screen loading overlay shown while fetching routes (Waze-style)
class RouteLoadingOverlay extends StatelessWidget {
  const RouteLoadingOverlay({
    this.message = 'Finding routes...',
    super.key,
  });

  final String message;

  /// Shows the loading overlay and returns a function to dismiss it
  /// Use the returned function instead of hide() to ensure proper dismissal
  static VoidCallback show(BuildContext context, {String? message}) {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => RouteLoadingOverlay(message: message ?? 'Finding routes...'),
    );
    
    // Return a dismiss function that uses the stored navigator
    return () {
      if (navigator.canPop()) {
        navigator.pop();
      }
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
