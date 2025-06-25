import 'package:flutter/material.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';

class RouteSelectionSheet extends StatelessWidget {
  final List<DirectionsRoute> routes;
  final ValueChanged<DirectionsRoute> onRouteSelected;

  const RouteSelectionSheet({
    required this.routes,
    required this.onRouteSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...routes.asMap().entries.map((entry) {
              final idx = entry.key;
              final route = entry.value;
              final isPrimary = idx == 0;
              return InkWell(
                onTap: () => onRouteSelected(route),
                child: Container(
                  color: isPrimary ? Colors.red[50] : Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isPrimary ? Icons.star : Icons.alt_route,
                        color: isPrimary ? Colors.orange : Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  // Assuming duration is in seconds
                                  '${(route.legs.first.duration.value / 60).round()} mins',
                                  style: TextStyle(
                                    color:
                                        isPrimary ? Colors.red : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  // Assuming distance is in meters
                                  '${(route.legs.first.distance.value / 1000).toStringAsFixed(0)}km',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              route.summary,
                              style: const TextStyle(fontSize: 15),
                            ),
                            if (route.legs.first != null)
                              Text(
                                route.legs.first.endAddress,
                                style: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("Cancel trip"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // You can handle "Start route" here if needed
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "Start route",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
