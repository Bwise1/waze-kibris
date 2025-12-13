import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';

class RouteBar extends StatelessWidget {
  final String start;
  final String end;
  final VoidCallback onCancel;

  const RouteBar({
    required this.start,
    required this.end,
    required this.onCancel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(32),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _dot(start, Colors.red),
              const SizedBox(width: 8),
              Text(start, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Expanded(
                child: Divider(
                  color: Colors.grey,
                  thickness: 1,
                  indent: 0,
                  endIndent: 0,
                ),
              ),
              const SizedBox(width: 8),
              _dot(end, Colors.red),
              const SizedBox(width: 8),
              Text(getInitials(end),
                  style: const TextStyle(fontWeight: FontWeight.bold)),

              // IconButton(
              //   icon: const Icon(Icons.close),
              //   onPressed: onCancel,
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(String label, Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

String getInitials(String input) {
  return input
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase())
      .join();
}
