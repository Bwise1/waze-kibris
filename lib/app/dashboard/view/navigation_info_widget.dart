import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/services/enhanced_navigation_controller.dart';

class NavigationInfoWidget extends StatefulWidget {
  final EnhancedNavigationController controller;

  const NavigationInfoWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<NavigationInfoWidget> createState() => _NavigationInfoWidgetState();
}

class _NavigationInfoWidgetState extends State<NavigationInfoWidget> {
  @override
  void initState() {
    super.initState();
    // Listen to navigation updates
    widget.controller.onStepUpdate = (step, distance) {
      if (mounted) setState(() {});
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isNavigating) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Distance remaining
          _buildInfoItem(
            Icons.straighten,
            widget.controller.formattedDistanceRemaining,
          ),
          
          const SizedBox(width: 16),
          
          // Time remaining
          _buildInfoItem(
            Icons.access_time,
            widget.controller.estimatedTimeRemaining,
          ),
          
          const SizedBox(width: 16),
          
          // ETA
          _buildInfoItem(
            Icons.schedule,
            widget.controller.estimatedArrivalTime,
          ),
          
          const SizedBox(width: 16),
          
          // Step progress
          _buildInfoItem(
            Icons.map,
            '${widget.controller.currentStepIndex + 1}/${widget.controller.totalSteps}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}