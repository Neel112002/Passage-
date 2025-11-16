import 'package:flutter/material.dart';
import 'package:passage/models/notification_item.dart';
import 'package:passage/models/order.dart';
import 'package:passage/services/local_notifications_store.dart';
import 'package:passage/services/local_orders_store.dart';
import 'package:passage/screens/admin_products_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    // Seed notifications if user never opened that screen
    LocalNotificationsStore.ensureSeeded();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.insights_outlined)),
            Tab(text: 'Products', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'Orders', icon: Icon(Icons.receipt_long_outlined)),
            Tab(text: 'Notifications', icon: Icon(Icons.notifications_outlined)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: const [
            _OverviewTab(),
            AdminProductsTab(),
            _OrdersTab(),
            _NotificationsTab(),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  int _ordersCount = 0;
  double _revenue = 0;
  double _avgOrder = 0;
  int _notifTotal = 0;
  int _notifUnread = 0;
  DateTime? _lastOrderAt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await LocalOrdersStore.loadAll();
    final notifs = await LocalNotificationsStore.loadAll();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final revenue = orders.fold<double>(0.0, (sum, e) => sum + e.total);
    final avg = orders.isEmpty ? 0.0 : (revenue / orders.length);

    final lastAt = orders.isNotEmpty ? orders.first.createdAt : null;

    setState(() {
      _ordersCount = orders.length;
      _revenue = revenue;
      _avgOrder = avg;
      _notifTotal = notifs.length;
      _notifUnread = notifs.where((e) => !e.read).length;
      _lastOrderAt = lastAt;
      _loading = false;
    });
  }

  Future<void> _seedDemoOrders() async {
    // Create 3 sample orders for demo purposes
    final now = DateTime.now();
    final samples = <OrderItemModel>[
      OrderItemModel(
        id: 'ord_${now.millisecondsSinceEpoch}',
        userId: 'demo-admin',
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now,
        status: OrderStatus.processing,
        items: [
          const OrderLineItem(
            productId: 'p2',
            name: 'Sonic Pro Headphones',
            imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&h=400&fit=crop',
            unitPrice: 129.00,
            quantity: 1,
          ),
        ],
        subtotal: 129.00,
        shippingFee: 6.99,
        tax: 10.32,
        total: 146.31,
        shippingAddressSummary: 'Alex Johnson · 21 Market St',
        paymentSummary: 'VISA •••• 4242',
      ),
      OrderItemModel(
        id: 'ord_${now.millisecondsSinceEpoch - 1}',
        userId: 'demo-admin',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        updatedAt: now,
        status: OrderStatus.shipped,
        items: [
          const OrderLineItem(
            productId: 'p6',
            name: 'ZenBook Ultrabook',
            imageUrl: 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400&h=400&fit=crop',
            unitPrice: 999.00,
            quantity: 1,
          ),
          const OrderLineItem(
            productId: 'p5',
            name: 'Shadow Sunglasses',
            imageUrl: 'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=400&h=400&fit=crop',
            unitPrice: 39.99,
            quantity: 2,
          ),
        ],
        subtotal: 999.00 + 39.99 * 2,
        shippingFee: 0.00,
        tax: 108.40,
        total: 1187.38,
        shippingAddressSummary: 'Alex Johnson · 21 Market St',
        paymentSummary: 'PayPal alex@example.com',
        trackingNumber: 'ZX123456789',
      ),
      OrderItemModel(
        id: 'ord_${now.millisecondsSinceEpoch - 2}',
        userId: 'demo-admin',
        createdAt: now.subtract(const Duration(days: 4, hours: 6)),
        updatedAt: now,
        status: OrderStatus.delivered,
        items: const [
          OrderLineItem(
            productId: 'p1',
            name: 'AirFlex Sneakers',
            imageUrl: 'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=400&h=400&fit=crop',
            unitPrice: 89.99,
            quantity: 1,
          ),
        ],
        subtotal: 89.99,
        shippingFee: 4.99,
        tax: 4.20,
        total: 99.18,
        shippingAddressSummary: 'Alex Johnson · 21 Market St',
        paymentSummary: 'COD',
        deliveredAt: now.subtract(const Duration(days: 2, hours: 1)),
      ),
    ];

    // Merge with existing
    final existing = await LocalOrdersStore.loadAll();
    final merged = [...samples, ...existing];
    await LocalOrdersStore.saveAll(merged);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seeded 3 demo orders')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCard(
                context,
                title: 'Orders',
                value: '$_ordersCount',
                icon: Icons.receipt_long,
                color: Colors.indigo,
                subtitle: _lastOrderAt != null
                    ? 'Last: ${_formatDateTime(_lastOrderAt!)}'
                    : 'No orders yet',
              ),
              _metricCard(
                context,
                title: 'Revenue',
                value: '\$${_revenue.toStringAsFixed(2)}',
                icon: Icons.payments,
                color: Colors.teal,
                subtitle: 'Avg order: \$${_avgOrder.toStringAsFixed(2)}',
              ),
              _metricCard(
                context,
                title: 'Notifications',
                value: '$_notifTotal',
                icon: Icons.notifications,
                color: Colors.orange,
                subtitle: _notifUnread > 0 ? 'Unread: $_notifUnread' : 'All read',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _seedDemoOrders,
                icon: const Icon(Icons.dataset),
                label: const Text('Seed demo orders'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final n = await LocalNotificationsStore.unreadCount();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unread notifications: $n')),
                  );
                },
                icon: const Icon(Icons.mark_email_unread_outlined, color: Colors.orange),
                label: const Text('Check unread'),
              ),
            ],
          )
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  late Future<List<OrderItemModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = LocalOrdersStore.loadAll();
  }

  Future<void> _reload() async {
    setState(() {
      _future = LocalOrdersStore.loadAll();
    });
  }

  Future<void> _updateStatus(OrderItemModel item, OrderStatus status) async {
    await LocalOrdersStore.upsert(item.copyWith(status: status));
    await _reload();
  }

  Future<void> _delete(String id) async {
    await LocalOrdersStore.remove(id);
    await _reload();
  }

  void _openDetails(OrderItemModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<OrderItemModel>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = List<OrderItemModel>.from(snap.data!);
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (items.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 60),
                Icon(Icons.inbox_outlined, size: 72, color: Colors.indigo.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Center(
                  child: Text('No orders yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Use "Seed demo orders" in Overview to populate some', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                )
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemBuilder: (context, index) {
              final o = items[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(o.status).withValues(alpha: 0.12),
                    child: Icon(Icons.receipt_long, color: _statusColor(o.status)),
                  ),
                  title: Text('#${o.id}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text('${o.items.length} items · Total: \$${o.total.toStringAsFixed(2)}'),
                      const SizedBox(height: 2),
                      Text(_formatDateTime(o.createdAt), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      switch (v) {
                        case 'details':
                          _openDetails(o);
                          break;
                        case 'delete':
                          _delete(o.id);
                          break;
                        case 'processing':
                          _updateStatus(o, OrderStatus.processing);
                          break;
                        case 'shipped':
                          _updateStatus(o, OrderStatus.shipped);
                          break;
                        case 'delivered':
                          _updateStatus(o, OrderStatus.delivered);
                          break;
                        case 'cancelled':
                          _updateStatus(o, OrderStatus.cancelled);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'details', child: ListTile(leading: Icon(Icons.info_outline), title: Text('Details'))),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'processing', child: ListTile(leading: Icon(Icons.timelapse), title: Text('Set Processing'))),
                      const PopupMenuItem(value: 'shipped', child: ListTile(leading: Icon(Icons.local_shipping_outlined), title: Text('Set Shipped'))),
                      const PopupMenuItem(value: 'delivered', child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('Set Delivered'))),
                      const PopupMenuItem(value: 'cancelled', child: ListTile(leading: Icon(Icons.cancel_outlined), title: Text('Set Cancelled'))),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete'))),
                    ],
                  ),
                  onTap: () => _openDetails(o),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
      ),
    );
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.processing:
        return Colors.blue;
      case OrderStatus.shipped:
        return Colors.orange;
      case OrderStatus.delivered:
        return Colors.teal;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final OrderItemModel order;
  const _OrderDetailsSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                  child: const Icon(Icons.receipt_long, color: Colors.indigo),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Order ${order.id}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Text(order.status.name.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            const SizedBox(height: 6),
            ...order.items.map((it) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      it.imageUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset('assets/icons/dreamflow_icon.jpg', width: 48, height: 48, fit: BoxFit.cover),
                    ),
                  ),
                  title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Qty ${it.quantity} · \$' + it.unitPrice.toStringAsFixed(2)), 
                  trailing: Text(' \$' + it.lineTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)), 
                )),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Subtotal: \$' + order.subtotal.toStringAsFixed(2)), 
                  Text('Shipping: \$' + order.shippingFee.toStringAsFixed(2)), 
                  Text('Tax: \$' + order.tax.toStringAsFixed(2)), 
                  const SizedBox(height: 6),
                  Text('Total: \$' + order.total.toStringAsFixed(2), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), 
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (order.shippingAddressSummary != null)
              Text('Ship to: ${order.shippingAddressSummary!}', style: theme.textTheme.bodySmall),
            if (order.paymentSummary != null)
              Text('Payment: ${order.paymentSummary!}', style: theme.textTheme.bodySmall),
            if (order.trackingNumber != null)
              Text('Tracking: ${order.trackingNumber!}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.red),
                label: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = LocalNotificationsStore.loadAll();
  }

  Future<void> _reload() async {
    setState(() {
      _future = LocalNotificationsStore.loadAll();
    });
  }

  Future<void> _toggleRead(AppNotification n) async {
    await LocalNotificationsStore.markRead(n.id, !n.read);
    await _reload();
  }

  Future<void> _remove(String id) async {
    await LocalNotificationsStore.remove(id);
    await _reload();
  }



  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = List<AppNotification>.from(snap.data!);
          items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemBuilder: (context, index) {
              final n = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _typeColor(n.type).withValues(alpha: 0.12),
                    child: Icon(iconForType(n.type), color: _typeColor(n.type)),
                  ),
                  title: Text(n.title),
                  subtitle: Text(n.body),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _toggleRead(n),
                        tooltip: n.read ? 'Mark unread' : 'Mark read',
                        icon: Icon(n.read ? Icons.mark_email_unread : Icons.mark_email_read, color: Colors.orange),
                      ),
                      IconButton(
                        onPressed: () => _remove(n.id),
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
      ),
    );
  }

  Color _typeColor(NotificationType t) {
    switch (t) {
      case NotificationType.order:
        return Colors.blue;
      case NotificationType.promotion:
        return Colors.deepPurple;
      case NotificationType.priceDrop:
        return Colors.teal;
      case NotificationType.system:
        return Colors.grey;
    }
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  NotificationType _type = NotificationType.system;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Compose notification', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<NotificationType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: NotificationType.system, child: Text('System')),
                DropdownMenuItem(value: NotificationType.order, child: Text('Order')),
                DropdownMenuItem(value: NotificationType.promotion, child: Text('Promotion')),
                DropdownMenuItem(value: NotificationType.priceDrop, child: Text('Price Drop')),
              ],
              onChanged: (v) => setState(() => _type = v ?? NotificationType.system),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  final title = _title.text.trim();
                  final body = _body.text.trim();
                  if (title.isEmpty || body.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill title and body')),
                    );
                    return;
                  }
                  Navigator.pop(context, _ComposeResult(title: title, body: body, type: _type));
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ComposeResult {
  final String title;
  final String body;
  final NotificationType type;
  const _ComposeResult({required this.title, required this.body, required this.type});
}
