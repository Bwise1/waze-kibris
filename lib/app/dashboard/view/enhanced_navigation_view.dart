import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/app/dashboard/services/enhanced_navigation_controller.dart';
import 'package:waze_kibris/app/dashboard/view/maneuver_banner.dart';
import 'package:waze_kibris/app/dashboard/view/navigation_info_widget.dart';

class EnhancedNavigationView extends StatefulWidget {
  final MapboxRoute route;
  final Stream<Position> positionStream;
  final VoidCallback? onNavigationComplete;
  final VoidCallback? onNavigationCancel;

  const EnhancedNavigationView({
    Key? key,
    required this.route,
    required this.positionStream,
    this.onNavigationComplete,
    this.onNavigationCancel,
  }) : super(key: key);

  @override
  State<EnhancedNavigationView> createState() => _EnhancedNavigationViewState();
}

class _EnhancedNavigationViewState extends State<EnhancedNavigationView> {
  late final EnhancedNavigationController _controller;
  MapboxStep? _currentStep;
  double _distanceRemaining = 0;
  MapboxBannerInstruction? _currentBanner;

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  Future<void> _initializeNavigation() async {
    _controller = EnhancedNavigationController();
    await _controller.initialize();

    // Set up navigation callbacks
    _controller.onStepUpdate = (step, distance) {
      if (mounted) {
        setState(() {
          _currentStep = step;
          _distanceRemaining = distance;
        });
      }
    };

    _controller.onBannerUpdate = (banner) {
      if (mounted) {
        setState(() {
          _currentBanner = banner;
        });
      }
    };

    _controller.onDestinationReached = () {
      if (mounted) {
        _showDestinationReachedDialog();
        widget.onNavigationComplete?.call();
      }
    };

    // Listen to position updates
    widget.positionStream.listen((position) {
      _controller.updateCurrentPosition(position);
    });

    // Start navigation
    await _controller.startNavigation(widget.route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDestinationReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Destination Reached!'),
        content: const Text('You have arrived at your destination.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onNavigationComplete?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNavigationSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _NavigationSettingsSheet(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content (your map would go here)
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: Text(
                'Map View\n(Your existing map implementation)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),

          // Navigation UI overlay
          if (_currentStep != null) ...[
            // Maneuver banner at the top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ManeuverBanner(
                step: _currentStep!,
                distanceRemaining: _distanceRemaining,
                navigationController: _controller,
              ),
            ),

            // Navigation info at the bottom
            Positioned(
              bottom: 100,
              left: 16,
              child: NavigationInfoWidget(controller: _controller),
            ),
          ],

          // Navigation controls
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Settings button
                FloatingActionButton(
                  heroTag: 'settings',
                  mini: true,
                  onPressed: _showNavigationSettings,
                  child: const Icon(Icons.settings),
                ),
                
                const SizedBox(height: 8),
                
                // Cancel navigation button
                FloatingActionButton(
                  heroTag: 'cancel',
                  backgroundColor: Colors.red,
                  onPressed: () {
                    _showCancelConfirmation();
                  },
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Navigation'),
        content: const Text('Are you sure you want to cancel navigation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _controller.stopNavigation();
              widget.onNavigationCancel?.call();
            },
            child: const Text('Cancel Navigation'),
          ),
        ],
      ),
    );
  }
}

class _NavigationSettingsSheet extends StatefulWidget {
  final EnhancedNavigationController controller;

  const _NavigationSettingsSheet({required this.controller});

  @override
  State<_NavigationSettingsSheet> createState() => _NavigationSettingsSheetState();
}

class _NavigationSettingsSheetState extends State<_NavigationSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Navigation Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Voice instructions toggle
          SwitchListTile(
            title: const Text('Voice Instructions'),
            subtitle: const Text('Enable turn-by-turn voice guidance'),
            value: widget.controller.isVoiceEnabled,
            onChanged: (value) {
              setState(() {
                widget.controller.isVoiceEnabled = value;
              });
            },
          ),

          // Test voice button
          if (widget.controller.isVoiceEnabled)
            ListTile(
              title: const Text('Test Voice'),
              subtitle: const Text('Test voice instructions'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                await widget.controller.testVoice();
              },
            ),

          const Divider(),

          // Voice settings (if enabled)
          if (widget.controller.isVoiceEnabled) ...[
            const Text(
              'Voice Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            // Speech rate slider
            const Text('Speech Rate'),
            Slider(
              value: 0.5, // You'd get this from the controller
              onChanged: (value) async {
                await widget.controller.setVoiceSpeechRate(value);
              },
              divisions: 10,
              label: 'Speech Rate',
            ),

            // Volume slider
            const Text('Volume'),
            Slider(
              value: 1.0, // You'd get this from the controller
              onChanged: (value) async {
                await widget.controller.setVoiceVolume(value);
              },
              divisions: 10,
              label: 'Volume',
            ),
          ],

          const SizedBox(height: 16),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}