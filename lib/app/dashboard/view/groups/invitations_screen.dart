import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  bool _loadingInvitations = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupsBloc>().add(const LoadMyInvitationsRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('My Invitations'),
        centerTitle: true,
      ),
      body: BlocConsumer<GroupsBloc, GroupsState>(
        listener: (context, state) {
          if (state is GroupsError) {
            if (mounted) setState(() => _loadingInvitations = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is GroupActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is MyInvitationsLoaded) {
            if (mounted) setState(() => _loadingInvitations = false);
          }
        },
        buildWhen: (prev, curr) =>
            curr is MyInvitationsLoaded || curr is GroupsError,
        builder: (context, state) {
          if (_loadingInvitations && state is! MyInvitationsLoaded && state is! GroupsError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GroupsError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      context.read<GroupsBloc>().add(const LoadMyInvitationsRequested());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is MyInvitationsLoaded) {
            final invitations = state.invitations;
            if (invitations.isEmpty) {
              return Center(
                child: Text(
                  'No pending invitations.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<GroupsBloc>().add(const LoadMyInvitationsRequested());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: invitations.length,
                itemBuilder: (context, index) {
                  final inv = invitations[index];
                  return _InvitationCard(
                    invitation: inv,
                    onAccept: () {
                      context.read<GroupsBloc>().add(
                            AcceptInvitationRequested(inv.id),
                          );
                    },
                    onDecline: () {
                      context.read<GroupsBloc>().add(
                            DeclineInvitationRequested(inv.id),
                          );
                    },
                  );
                },
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  final GroupInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invitation.groupName ?? 'Group',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (invitation.invitedByName != null &&
                invitation.invitedByName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Invited by ${invitation.invitedByName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
