// route_overview.dart
import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/bloc/navigation_bloc.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';

class RouteOverviewWidget extends StatelessWidget {
  final NavigationInProgress navigationState;
  final VoidCallback onBackToNavigation;

  const RouteOverviewWidget({
    Key? key,
    required this.navigationState,
    required this.onBackToNavigation,
  }) : super(key: key);

  String _formatDistance(int distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters}m';
    } else {
      final km = (distanceMeters / 1000).toStringAsFixed(1);
      return '${km}km';
    }
  }

  String _cleanInstruction(String htmlInstruction) {
    String instruction = htmlInstruction;
    instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), '');
    instruction = instruction.replaceAll('&nbsp;', ' ');
    instruction = instruction.replaceAll('&amp;', '&');
    return instruction.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBackToNavigation,
                  icon: const Icon(Icons.arrow_back),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Route Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${navigationState.route.legs.first.steps.length} steps • ${_formatDistance(navigationState.route.legs.first.distance.value)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          // Route steps list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: navigationState.route.legs.first.steps.length,
              itemBuilder: (context, index) {
                final step = navigationState.route.legs.first.steps[index];
                final isCurrentStep = index == navigationState.currentStepIndex;
                final isPastStep = index < navigationState.currentStepIndex;
                final isLastStep =
                    index == navigationState.route.legs.first.steps.length - 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step timeline indicator
                      Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCurrentStep
                                  ? styles.theme.primary
                                  : isPastStep
                                      ? Colors.green
                                      : Colors.grey[300],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCurrentStep
                                    ? const Color(0xffF05A5A)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: isPastStep
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : isCurrentStep
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                            ),
                          ),
                          // Connecting line
                          if (!isLastStep)
                            Container(
                              width: 2,
                              height: 40,
                              color: isPastStep || isCurrentStep
                                  ? Colors.green[300]
                                  : Colors.grey[300],
                            ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // Step details
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrentStep
                                ? styles.theme.secondary
                                : isPastStep
                                    ? Colors.green[50]
                                    : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrentStep
                                  ? styles.theme.secondary
                                  : isPastStep
                                      ? Colors.green[200]!
                                      : Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step instruction
                              Text(
                                _cleanInstruction(step.htmlInstr),
                                style: TextStyle(
                                  fontWeight: isCurrentStep
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                  color: isPastStep
                                      ? Colors.grey[600]
                                      : isCurrentStep
                                          ? styles.theme.primary
                                          : Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Step metadata
                              Row(
                                children: [
                                  // Distance
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Text(
                                      _formatDistance(step.distance.value),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Duration
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Text(
                                      '${(step.duration.value / 60).round()}m',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  // Current step indicator
                                  if (isCurrentStep) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: styles.theme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom action button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBackToNavigation,
                icon: const Icon(Icons.navigation),
                label: const Text(
                  'Back to Navigation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: styles.theme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
