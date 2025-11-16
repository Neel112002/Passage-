import 'package:flutter/material.dart';
import 'package:passage/models/notification_item.dart';
import 'package:passage/services/local_notifications_store.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _FilterType { all, order, promotion, priceDrop, system }

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;
  List<AppNotification> _items = [];

  // UI state: filters and search
  _FilterType _filter = _FilterType.all;
  bool _unreadOnly = false;
  final TextEditingController _queryController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<List<AppNotification>> _load() async {
    final list = await LocalNotificationsStore.loadAll();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _items = list;
    return list;
  }

  Future<void> _refresh() async {
    final list = await _load();
    if (!mounted) return;
    setState(() {
      _items = list;
    });
  }

  Future<void> _markAllRead() async {
    await LocalNotificationsStore.markAllRead();
    await _refresh();
  }

  Future<void> _toggleRead(AppNotification n) async {
    final updated = n.copyWith(read: !n.read);
    await LocalNotificationsStore.upsert(updated);
    await _refresh();
  }

  Future<void> _delete(AppNotification n) async {
    await LocalNotificationsStore.remove(n.id);
    await _refresh();
  }

  Future<void> _clearAll() async {
    await LocalNotificationsStore.saveAll([]);
    await _refresh();
  }

  Future<void> _deleteAllRead() async {
    final all = await LocalNotificationsStore.loadAll();
    final kept = all.where((e) => !e.read).toList();
    await LocalNotificationsStore.saveAll(kept);
    await _refresh();
  }

  String _sectionFor(DateTime ts) {
    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(ts, now)) return 'Today';
    if (ts.isAfter(now.subtract(const Duration(days: 7)))) return 'This week';
    return 'Earlier';
  }

  List<_Section> _buildSections(List<AppNotification> list) {
    final Map<String, List<AppNotification>> map = {};
    for (final n in list) {
      final key = _sectionFor(n.timestamp);
      map.putIfAbsent(key, () => []).add(n);
    }
    final order = ['Today', 'This week', 'Earlier'];
    final sections = <_Section>[];
    for (final k in order) {
      final items = map[k];
      if (items == null || items.isEmpty) continue;
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      sections.add(_Section(title: k, items: items));
    }
    return sections;
  }

  List<AppNotification> _applyFilters(List<AppNotification> list) {
    Iterable<AppNotification> it = list;

    if (_filter != _FilterType.all) {
      it = it.where((e) {
        switch (_filter) {
          case _FilterType.order:
            return e.type == NotificationType.order;
          case _FilterType.promotion:
            return e.type == NotificationType.promotion;
          case _FilterType.priceDrop:
            return e.type == NotificationType.priceDrop;
          case _FilterType.system:
            return e.type == NotificationType.system;
          case _FilterType.all:
            return true;
        }
      });
    }

    if (_unreadOnly) {
      it = it.where((e) => !e.read);
    }

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      it = it.where((e) => e.title.toLowerCase().contains(q) || e.body.toLowerCase().contains(q));
    }

    final filtered = it.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  String _formatTime(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')}/${ts.year}';
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_items.any((e) => !e.read))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all as read'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'deleteRead':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete read notifications?'),
                      content: const Text('All read notifications will be removed.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) await _deleteAllRead();
                  break;
                case 'clearAll':
                  final ok2 = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear all notifications?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                      ],
                    ),
                  );
                  if (ok2 == true) await _clearAll();
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'deleteRead', child: Text('Delete read')),
              PopupMenuItem(value: 'clearAll', child: Text('Clear all')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final filtered = _applyFilters(_items);
          if (filtered.isEmpty) {
            return _EmptyState(
              onRefresh: _refresh,
              title: 'No notifications',
              message: _items.isEmpty
                  ? 'You\'re all caught up. New updates will appear here.'
                  : 'No notifications match your filters.',
              header: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _FiltersHeader(
                  filter: _filter,
                  unreadOnly: _unreadOnly,
                  queryController: _queryController,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onUnreadOnlyChanged: (v) => setState(() => _unreadOnly = v),
                  onQueryChanged: (q) => setState(() => _query = q),
                ),
              ),
            );
          }

          final sections = _buildSections(filtered);
          final totalRows = sections.fold<int>(1, (sum, s) => sum + 1 + s.items.length); // +1 for header

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: totalRows,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FiltersHeader(
                    filter: _filter,
                    unreadOnly: _unreadOnly,
                    queryController: _queryController,
                    onFilterChanged: (f) => setState(() => _filter = f),
                    onUnreadOnlyChanged: (v) => setState(() => _unreadOnly = v),
                    onQueryChanged: (q) => setState(() => _query = q),
                  );
                }

                int cursor = 0;
                for (final section in sections) {
                  if (index - 1 == cursor) {
                    return _SectionHeader(title: section.title);
                  }
                  cursor += 1;
                  final sectionStart = cursor;
                  final sectionEnd = sectionStart + section.items.length;
                  if (index - 1 >= sectionStart && index - 1 < sectionEnd) {
                    final item = section.items[(index - 1) - sectionStart];
                    return _NotificationTile(
                      item: item,
                      timeLabel: _formatTime(item.timestamp),
                      onToggleRead: () => _toggleRead(item),
                      onDelete: () => _delete(item),
                    );
                  }
                  cursor = sectionEnd;
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}

class _Section {
  final String title;
  final List<AppNotification> items;
  _Section({required this.title, required this.items});
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _FiltersHeader extends StatelessWidget {
  final _FilterType filter;
  final bool unreadOnly;
  final TextEditingController queryController;
  final ValueChanged<_FilterType> onFilterChanged;
  final ValueChanged<bool> onUnreadOnlyChanged;
  final ValueChanged<String> onQueryChanged;

  const _FiltersHeader({
    required this.filter,
    required this.unreadOnly,
    required this.queryController,
    required this.onFilterChanged,
    required this.onUnreadOnlyChanged,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _typeChip(context, label: 'All', type: _FilterType.all),
              const SizedBox(width: 8),
              _typeChip(context, label: 'Orders', type: _FilterType.order),
              const SizedBox(width: 8),
              _typeChip(context, label: 'Promotions', type: _FilterType.promotion),
              const SizedBox(width: 8),
              _typeChip(context, label: 'Price drops', type: _FilterType.priceDrop),
              const SizedBox(width: 8),
              _typeChip(context, label: 'System', type: _FilterType.system),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Unread only'),
                selected: unreadOnly,
                onSelected: (v) => onUnreadOnlyChanged(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: queryController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search notifications',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: queryController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () {
                        queryController.clear();
                        onQueryChanged('');
                      },
                    ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }

  Widget _typeChip(BuildContext context, {required String label, required _FilterType type}) {
    final selected = filter == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onFilterChanged(type),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final String timeLabel;
  final VoidCallback onToggleRead;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.item,
    required this.timeLabel,
    required this.onToggleRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bg = item.read
        ? theme.colorScheme.surface
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.25);

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );

    return Dismissible(
      key: ValueKey(item.id),
      background: _SwipeBackground(
        color: Colors.blue.withValues(alpha: 0.15),
        icon: Icons.mark_email_read_outlined,
        label: item.read ? 'Mark unread' : 'Mark read',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: const _SwipeBackground(
        color: Colors.redAccent,
        icon: Icons.delete_outline,
        label: 'Delete',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleRead();
          return false; // keep item, just toggle
        }
        if (direction == DismissDirection.endToStart) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete notification?'),
              content: const Text('This action cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
              ],
            ),
          );
          if (ok == true) {
            onDelete();
            return true;
          }
          return false;
        }
        return false;
      },
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onToggleRead,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconForType(item.type),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: titleStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!item.read)
                  Container(
                    height: 10,
                    width: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
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

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final AlignmentGeometry alignment;

  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRight = alignment == Alignment.centerRight;
    final iconWidget = Icon(icon, color: isRight ? Colors.white : Colors.blue);
    final textWidget = Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: isRight ? Colors.white : Colors.blue));
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: isRight
            ? [textWidget, const SizedBox(width: 8), iconWidget]
            : [iconWidget, const SizedBox(width: 8), textWidget],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final String title;
  final String message;
  final Widget? header;
  const _EmptyState({
    required this.onRefresh,
    this.title = 'No notifications yet',
    this.message = "You're all caught up. New updates will appear here.",
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          if (header != null) header!,
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
