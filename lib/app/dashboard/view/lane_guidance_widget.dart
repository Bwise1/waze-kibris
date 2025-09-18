import 'package:flutter/material.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';

class LaneGuidanceWidget extends StatelessWidget {
  final List<MapboxLane> lanes;

  const LaneGuidanceWidget({
    Key? key,
    required this.lanes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (lanes.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: [
        // Lane guidance label
        const Text(
          'Lane Guidance',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        
        // Lane indicators
        SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: lanes.asMap().entries.map((entry) {
              final lane = entry.value;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 40,
                decoration: BoxDecoration(
                  color: _getLaneColor(lane),
                  borderRadius: BorderRadius.circular(8),
                  border: lane.active 
                      ? Border.all(color: Colors.blue, width: 2) 
                      : null,
                  boxShadow: lane.active
                      ? [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildLaneArrows(lane.indications),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getLaneColor(MapboxLane lane) {
    if (lane.active) {
      return Colors.blue; // Recommended lane
    } else if (lane.valid) {
      return Colors.grey.withOpacity(0.6); // Valid but not recommended
    } else {
      return Colors.red.withOpacity(0.4); // Invalid lane
    }
  }

  List<Widget> _buildLaneArrows(List<String> indications) {
    return indications.take(2).map((indication) { // Limit to 2 arrows per lane
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: _buildArrowIcon(indication),
      );
    }).toList();
  }

  Widget _buildArrowIcon(String indication) {
    IconData icon;
    double rotation = 0;
    
    switch (indication.toLowerCase()) {
      case 'left':
        icon = Icons.arrow_upward;
        rotation = -90 * (3.14159 / 180); // Convert to radians
        break;
      case 'right':
        icon = Icons.arrow_upward;
        rotation = 90 * (3.14159 / 180);
        break;
      case 'straight':
        icon = Icons.arrow_upward;
        break;
      case 'slight_left':
        icon = Icons.arrow_upward;
        rotation = -45 * (3.14159 / 180);
        break;
      case 'slight_right':
        icon = Icons.arrow_upward;
        rotation = 45 * (3.14159 / 180);
        break;
      case 'sharp_left':
        icon = Icons.arrow_upward;
        rotation = -135 * (3.14159 / 180);
        break;
      case 'sharp_right':
        icon = Icons.arrow_upward;
        rotation = 135 * (3.14159 / 180);
        break;
      case 'uturn':
        icon = Icons.u_turn_left;
        break;
      default:
        icon = Icons.arrow_upward;
    }
    
    if (indication.toLowerCase() == 'uturn') {
      return Icon(
        icon,
        color: Colors.white,
        size: 16,
      );
    }
    
    return Transform.rotate(
      angle: rotation,
      child: Icon(
        icon,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}