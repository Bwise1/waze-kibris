import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/app_router.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/app/dashboard/view/groups/group_list_screen.dart';
import 'package:waze_kibris/core/services/trnc_offline_map_service.dart';

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({
    super.key,
    this.savedLocations,
    this.userDisplayName,
    this.userEmail,
    this.userProfileIcon,
  });

  final List<SavedLocations>? savedLocations;
  final String? userDisplayName;
  final String? userEmail;
  /// Either a URL (http/https) or a bundled asset filename (e.g. buddy_buggy.png).
  final String? userProfileIcon;

  @override
  Widget build(BuildContext context) {
    final theme = styles.theme;
    // Prefer backend-provided display name; fall back to email, then Guest.
    final name = userDisplayName?.isNotEmpty == true
        ? userDisplayName!
        : (userEmail?.isNotEmpty == true ? userEmail! : 'Guest');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Profile header (moved slightly up by reducing top padding)
                  Row(
                    children: [
                      buildProfileAvatar(context, userProfileIcon, name),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: styles.typography.h3.textColor(theme.text),
                          ),
                          if (userEmail != null && userEmail!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              userEmail!,
                              style: styles.typography.caption
                                  .textColor(theme.caption),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Personal information
                  const _SectionHeader('Account'),
                  _PanelRow(
                    icon: Icons.person_outline,
                    label: 'Personal information',
                    onTap: () {
                      context.push(ScreenPaths.personalInformation);
                    },
                  ),
                  _PanelRow(
                    icon: Icons.lock_outline,
                    label: 'Login and Privacy',
                    onTap: () {
                      // For now route to help/settings; can be swapped later.
                      context.push(ScreenPaths.helpAndFeedback);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Settings shortcuts
                  const _SectionHeader('Settings'),
                  _PanelRow(
                    icon: Icons.group_outlined,
                    label: 'Groups',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const GroupListScreen(),
                        ),
                      );
                    },
                  ),
                  _PanelRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Driving preferences',
                    onTap: () {
                      context.push(ScreenPaths.drivingPreferences);
                    },
                  ),
                  _PanelRow(
                    icon: Icons.volume_up_outlined,
                    label: 'Sound settings',
                    onTap: () {
                      context.push(ScreenPaths.soundSettings);
                    },
                  ),
                  _PanelRow(
                    icon: Icons.help_outline,
                    label: 'Help & feedback',
                    onTap: () {
                      context.push(ScreenPaths.helpAndFeedback);
                    },
                  ),
                  const _SectionHeader('Maps'),
                  _PanelRow(
                    icon: Icons.download_for_offline_outlined,
                    label: 'Download TRNC offline map',
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Starting offline download (Wi‑Fi recommended)…',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                      try {
                        await TrncOfflineMapService.downloadTrncRegion();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Offline map download finished.'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Offline download failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _PanelRow(
                    icon: Icons.info_outline,
                    label: 'About',
                    onTap: () {
                      context.push(ScreenPaths.aboutUs);
                    },
                  ),
                  _PanelRow(
                    icon: Icons.delete_outline,
                    label: 'Delete account',
                    destructive: true,
                    onTap: () {
                      context.push(ScreenPaths.deleteAccount);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fail-safe: URL -> NetworkImage, else asset filename -> AssetImage, else letter.
  /// Public so PersonalInformationScreen and others can reuse.
  static Widget buildProfileAvatar(
    BuildContext context,
    String? profileIcon,
    String displayName, {
    double radius = 28,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final letterWidget = Center(
      child: Text(
        letter,
        style: styles.typography.h3.textColor(primary),
      ),
    );

    if (profileIcon == null || profileIcon.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: primary.withOpacity(0.1),
        child: letterWidget,
      );
    }

    final value = profileIcon.trim();
    final ImageProvider imageProvider;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      imageProvider = NetworkImage(value);
    } else {
      imageProvider = AssetImage('assets/user_profiles/$value');
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withOpacity(0.1),
      ),
      child: ClipOval(
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (_, __, ___) => letterWidget,
        ),
      ),
    );
  }

  List<Widget> _buildSavedLocationRows(BuildContext context) {
    final locations = savedLocations ?? [];

    SavedLocations? home;
    SavedLocations? office;

    for (final loc in locations) {
      final nameLower = loc.name.toLowerCase();
      if (nameLower == 'home') {
        home ??= loc;
      } else if (nameLower == 'office') {
        office ??= loc;
      }
    }

    final rows = <Widget>[
      _PanelRow(
        icon: Icons.home_outlined,
        label: 'Home',
        subtitle: home?.address ?? 'Set home address',
        onTap: () {
          context.push(ScreenPaths.addLocation, extra: {'type': 'home'});
        },
      ),
      _PanelRow(
        icon: Icons.work_outline,
        label: 'Office',
        subtitle: office?.address ?? 'Set office address',
        onTap: () {
          context.push(ScreenPaths.addLocation, extra: {'type': 'office'});
        },
      ),
      _PanelRow(
        icon: Icons.add,
        label: 'Add new location',
        onTap: () {
          context.push(ScreenPaths.addLocation);
        },
      ),
    ];

    return rows;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: styles.typography.t2.bold.textColor(styles.theme.text),
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? Colors.red : styles.theme.text; // use theme text color

    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: styles.typography.t2.textColor(color),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: styles.typography.caption.textColor(styles.theme.caption),
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Helper to show the profile panel as a full-screen page.
Future<void> showProfilePanel(
  BuildContext context, {
  List<SavedLocations>? savedLocations,
  String? userDisplayName,
  String? userEmail,
  String? userProfileIcon,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => ProfilePanel(
        savedLocations: savedLocations,
        userDisplayName: userDisplayName,
        userEmail: userEmail,
        userProfileIcon: userProfileIcon,
      ),
    ),
  );
}
