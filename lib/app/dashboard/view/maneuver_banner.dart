import 'package:flutter/material.dart';

class ManeuverBanner extends StatelessWidget {
  final String distance;
  final String instruction;
  final String roadName;
  final IconData icon;
  final VoidCallback? onVoiceTap;

  const ManeuverBanner({
    super.key,
    required this.distance,
    required this.instruction,
    required this.roadName,
    required this.icon,
    this.onVoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(distance,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(instruction, style: const TextStyle(fontSize: 16)),
                Text(roadName,
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.mic),
              onPressed: onVoiceTap,
            ),
          ],
        ),
      ),
    );
  }
}
