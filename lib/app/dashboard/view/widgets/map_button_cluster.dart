import 'package:flutter/material.dart';
import 'package:waze_kibris/app/dashboard/modals/report_modal.dart';
import 'package:waze_kibris/app/dashboard/view/groups/group_list_screen.dart';
import 'package:waze_kibris/app/dashboard/view/widgets/map_buttons.dart';
import 'package:waze_kibris/app/profile/view/profile_panel.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';

/// Menu button that opens the profile panel with the current user's details
/// (Waze/Google Maps top-left convention).
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      child: MapCircleButton(
        icon: Icons.menu,
        onTap: () {
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthSuccess && authState.user != null) {
            final user = authState.user!;
            showProfilePanel(
              context,
              userDisplayName: user.displayName,
              userEmail: user.email,
              userProfileIcon: user.profileIcon,
            );
          } else {
            showProfilePanel(context);
          }
        },
      ),
    );
  }
}

/// Compass, exactly opposite the menu button — same 42pt circle, same
/// safe-area offset, so the two align. Hidden during navigation, where the
/// course-up toggle in the nav overlay owns this job instead.
class CompassOverlayButton extends StatelessWidget {
  const CompassOverlayButton({
    required this.mapBearing,
    required this.onTap,
    super.key,
  });

  final ValueNotifier<double> mapBearing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      child: ValueListenableBuilder<double>(
        valueListenable: mapBearing,
        builder: (context, bearing, _) => MapCompassButton(
          bearing: bearing,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Chats: one tap from the map, since it's a daily destination rather than
/// a setting. Hidden while navigating so it can't distract or be
/// mis-tapped. Shows an unread count badge via GroupsBloc.
class ChatsButton extends StatelessWidget {
  const ChatsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 68,
      left: 16,
      child: BlocBuilder<GroupsBloc, GroupsState>(
        buildWhen: (prev, curr) => curr is GetGroupsSuccess,
        builder: (context, groupsState) {
          final unread = groupsState is GetGroupsSuccess
              ? groupsState.totalUnreadCount
              : 0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              MapCircleButton(
                icon: Icons.forum_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const GroupListScreen(),
                  ),
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: styles.theme.primary,
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: styles.typography.hairline
                          .textColor(Colors.white)
                          .copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Floating recenter + report buttons that ride on top of the bottom sheet
/// as it drags — Waze-style. They follow the sheet edge up to a cap; past
/// that the (later-painted) sheet simply slides over them.
class FloatingSheetButtons extends StatelessWidget {
  const FloatingSheetButtons({
    required this.sheetHeightPx,
    required this.onRecenter,
    super.key,
  });

  final ValueNotifier<double> sheetHeightPx;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: sheetHeightPx,
      builder: (context, sheetPx, buttons) {
        final screenH = MediaQuery.of(context).size.height;
        // Before the first drag notification, assume the sheet's initial
        // 36% resting height.
        final height = sheetPx < 0 ? screenH * 0.36 : sheetPx;
        final cap = screenH * 0.45;
        final bottom = (height < cap ? height : cap) + 12;
        return Positioned(
          bottom: bottom,
          right: 16,
          child: buttons!,
        );
      },
      // Same 42pt circle as the menu/chat buttons opposite, so every
      // floating map control reads as one family.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MapCircleButton(
            icon: Icons.gps_fixed,
            iconColor: Colors.blueAccent,
            onTap: onRecenter,
          ),
          const SizedBox(height: 12),
          MapCircleButton(
            icon: Icons.report_problem,
            iconColor: Colors.white,
            backgroundColor: Colors.orange,
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const ReportEventModal(),
              );
            },
          ),
        ],
      ),
    );
  }
}
