import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/app/dashboard/view/groups/group_chat_screen.dart';
import 'package:waze_kibris/app/dashboard/view/groups/invitations_screen.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/bloc/groups/groups_event.dart';
import 'package:waze_kibris/core/bloc/groups/groups_state.dart';
import 'package:waze_kibris/core/models/groups/group_models.dart';
import 'package:waze_kibris/core/widgets/misc/custom_badge.dart';

String _formatLastActivity(DateTime? lastMessageAt) {
  if (lastMessageAt == null) return 'No recent activity';
  final now = DateTime.now();
  final diff = now.difference(lastMessageAt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hrs ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${(diff.inDays / 7).floor()} wks ago';
}

String _statusLabelForGroup(CommunityGroup group) {
  if (group.memberCount >= 100) return 'HIGHLY ACTIVE';
  return 'ACTIVE';
}

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  bool _refetchedOnReturn = false;
  bool _hasRequestedGroups = false;
  List<CommunityGroup>? _cachedGroups;
  final Map<String, List<CommunityGroup>> _cacheByFilter = {};

  /// Sum of unread across groups — uses bloc when [GetGroupsSuccess], else cached list.
  int _totalUnreadForAppBar(GroupsState state) {
    if (state is GetGroupsSuccess) return state.totalUnreadCount;
    final cached = _cachedGroups;
    if (cached != null) {
      return cached.fold<int>(0, (sum, g) => sum + g.unreadCount);
    }
    return 0;
  }

  final Map<String, DateTime> _cacheFetchedAt = {};
  String _lastRequestedFilter = 'my_routes';
  bool _isRefreshing = false;
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'my_routes'; // my_routes | near_me | popular
  static const Duration _cacheTtl = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    // Defer fetch to post-frame so we can check cached state (reload fix)
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestGroupsIfNeeded());
  }

  Future<void> _requestGroupsIfNeeded() async {
    if (!mounted || _hasRequestedGroups) return;
    final bloc = context.read<GroupsBloc>();
    final state = bloc.state;
    final hasCachedGroups = state is GetGroupsSuccess && state.groups.isNotEmpty;
    if (!hasCachedGroups) {
      _hasRequestedGroups = true;
      await _dispatchGetGroupsForCurrentFilter();
    }
  }

  Future<void> _dispatchGetGroupsForCurrentFilter() async {
    final bloc = context.read<GroupsBloc>();
    final now = DateTime.now();
    final cacheKey = _filter;
    final cached = _cacheByFilter[cacheKey];
    final fetchedAt = _cacheFetchedAt[cacheKey];
    final isCacheFresh =
        cached != null && fetchedAt != null && now.difference(fetchedAt) < _cacheTtl;

    if (cached != null) {
      setState(() {
        _cachedGroups = cached;
      });
      // If fresh, don't refetch; makes filter switching instant.
      if (isCacheFresh) return;
    }

    if (_filter == 'near_me') {
      final position = await _tryGetCurrentPosition();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Turn on location to see nearby groups.',
              ),
            ),
          );
        }
        bloc.add(const GetGroupsRequested());
        return;
      }
      _lastRequestedFilter = 'near_me';
      setState(() => _isRefreshing = true);
      bloc.add(
        GetGroupsRequested(
          filterType: 'near_me',
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      return;
    }
    _lastRequestedFilter = _filter;
    setState(() => _isRefreshing = true);
    bloc.add(GetGroupsRequested(filterType: _filter));
  }

  Future<Position?> _tryGetCurrentPosition() async {
    final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition();
  }

  void _showCreateGroupModal(BuildContext context) {
    String name = '';
    String description = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Create Community Group',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'Group Name'),
                onChanged: (val) => name = val,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: 'Description'),
                onChanged: (val) => description = val,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (name.isNotEmpty) {
                    context.read<GroupsBloc>().add(
                          CreateGroupRequested(
                            name: name,
                            description: description,
                            visibility: 'public',
                            groupType: 'driving',
                          ),
                        );
                    Navigator.pop(modalContext);
                  }
                },
                child: const Text('Create'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  static const String _nilUuid = '00000000-0000-0000-0000-000000000000';

  List<CommunityGroup> _filterAndSort(
    List<CommunityGroup> groups,
    String searchQuery,
  ) {
    var list = groups
        .where((g) =>
            g.id.isNotEmpty && g.id.toLowerCase() != _nilUuid)
        .toList();
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((g) =>
              g.name.toLowerCase().contains(q) ||
              (g.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: const Text('Route Groups'),
        centerTitle: true,
        actions: [
          BlocBuilder<GroupsBloc, GroupsState>(
            buildWhen: (previous, current) =>
                current is GetGroupsSuccess ||
                current is GroupsLoading ||
                current is GroupsError,
            builder: (context, state) {
              final totalUnread = _totalUnreadForAppBar(state);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mail_outline),
                    tooltip: 'My invitations',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const InvitationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (totalUnread > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CustomBadge(
                        totalUnread > 99 ? '99+' : totalUnread.toString(),
                        radius: 999,
                        bordered: true,
                        borderColor: styles.theme.white,
                      ),
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateGroupModal(context),
            ),
          ),
        ],
      ),
      body: BlocConsumer<GroupsBloc, GroupsState>(
        listener: (context, state) {
          if (state is GroupsError) {
            setState(() => _isRefreshing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is GroupActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is GetGroupsSuccess) {
            setState(() {
              _refetchedOnReturn = false;
              _isRefreshing = false;
              _cachedGroups = state.groups;
              _cacheByFilter[_lastRequestedFilter] = state.groups;
              _cacheFetchedAt[_lastRequestedFilter] = DateTime.now();
            });
          }
        },
        buildWhen: (previous, current) {
          return current is GetGroupsSuccess || current is GroupsLoading;
        },
        builder: (context, state) {
          // When we have a successful groups load, cache so we can show it when returning from chat.
          if (state is GetGroupsSuccess) {
            _cachedGroups = state.groups;
          }

          // While loading (e.g. refetch after return), show cached list if we have it.
          if (state is GroupsLoading && state is! GetGroupsSuccess) {
            if (_cachedGroups != null) {
              final searchQuery = _searchController.text;
              final validGroups = _filterAndSort(_cachedGroups!, searchQuery);
              return _buildListBody(context, theme, validGroups);
            }
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GetGroupsSuccess) {
            final groups = state.groups;
            final searchQuery = _searchController.text;
            final validGroups = _filterAndSort(groups, searchQuery);
            return _buildListBody(context, theme, validGroups);
          }

          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }

  Widget _buildListBody(
    BuildContext context,
    ThemeData theme,
    List<CommunityGroup> validGroups,
  ) {
    return RefreshIndicator(
              onRefresh: () async {
                await _dispatchGetGroupsForCurrentFilter();
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search routes or areas...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _FilterChip(
                                label: 'My Routes',
                                selected: _filter == 'my_routes',
                                onTap: () async {
                                  setState(() => _filter = 'my_routes');
                                  await _dispatchGetGroupsForCurrentFilter();
                                },
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Near Me',
                                selected: _filter == 'near_me',
                                icon: Icons.location_on,
                                onTap: () async {
                                  setState(() => _filter = 'near_me');
                                  await _dispatchGetGroupsForCurrentFilter();
                                },
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Popular',
                                selected: _filter == 'popular',
                                onTap: () async {
                                  setState(() => _filter = 'popular');
                                  await _dispatchGetGroupsForCurrentFilter();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isRefreshing) ...[
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              minHeight: 2,
                              backgroundColor: Colors.transparent,
                              color: Colors.red.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green.shade100,
                                  Colors.green.shade50,
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${validGroups.length} GROUPS ACTIVE IN YOUR AREA',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'ACTIVE GROUPS',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (validGroups.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('No groups available. Create one!'),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final group = validGroups[index];
                          return _GroupCard(
                            group: group,
                            onTap: group.isMember
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            GroupChatScreen(group: group),
                                      ),
                                    );
                                  }
                                : null,
                            onJoin: group.isMember
                                ? null
                                : () {
                                    context.read<GroupsBloc>().add(
                                          JoinGroupRequested(group.shortCode),
                                        );
                                  },
                          );
                        },
                        childCount: validGroups.length,
                      ),
                    ),
                ],
              ),
            );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.red : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected ? null : Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    this.onTap,
    this.onJoin,
  });

  final CommunityGroup group;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMember = group.isMember;
    final unread = group.unreadCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 16,
                            color: Colors.brown.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberCount} Drivers',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '·',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _statusLabelForGroup(group),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.only(left: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Colors.red.shade400,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                            _formatLastActivity(group.lastMessageAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMember)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -8,
                          right: -10,
                          child: CustomBadge(
                            unread > 99 ? '99+' : unread.toString(),
                            radius: 999,
                            bordered: true,
                            borderColor: styles.theme.white,
                          ),
                        ),
                    ],
                  )
                else if (onJoin != null)
                  Material(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onJoin,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          'Join',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
