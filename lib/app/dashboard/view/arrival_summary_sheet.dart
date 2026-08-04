import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/app/dashboard/view/mapbox_navigation_utils.dart';

/// Shown when [NavigationInProgress.isNavigationComplete] is true.
class ArrivalSummarySheet extends StatelessWidget {
  const ArrivalSummarySheet({
    super.key,
    required this.state,
    required void Function() onDone,
  }) : _onDone = onDone;

  final NavigationInProgress state;
  final void Function() _onDone;

  @override
  Widget build(BuildContext context) {
    final route = state.route;
    final distanceKm = route.distance / 1000;
    final plannedMin = route.duration / 60;
    final elapsed = state.routeStartTime != null
        ? DateTime.now().difference(state.routeStartTime!)
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.flag_rounded, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          Text(
            'You have arrived',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _row(
            context,
            Icons.route_rounded,
            'Trip distance',
            '${distanceKm.toStringAsFixed(1)} km',
          ),
          _row(
            context,
            Icons.timer_outlined,
            'Estimated drive time',
            MapboxNavigationUtils.formatDuration(route.duration),
          ),
          if (elapsed != null)
            _row(
              context,
              Icons.schedule_rounded,
              'Actual time',
              '${elapsed.inMinutes} min',
            ),
          const SizedBox(height: 12),
          Text(
            'Planned duration was about ${plannedMin.round()} min.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _onDone();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
