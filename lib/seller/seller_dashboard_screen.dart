import 'package:flutter/material.dart';
import 'package:passage/services/local_seller_accounts_store.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:passage/seller/seller_add_product_screen.dart';
import 'package:passage/seller/seller_inventory_screen.dart';
import 'package:passage/seller/seller_orders_screen.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/services/firestore_products_service.dart';
import 'package:passage/services/firestore_orders_service.dart';
import 'package:passage/models/product.dart';
import 'package:passage/models/order.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  int _index = 0;

  Future<void> _logout() async {
    // Exit seller mode only; do NOT sign out of Firebase user session
    await LocalSellerAccountsStore.clearSession();
    if (!mounted) return;
    // Go back to the consumer (user) side Home screen
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _SellerHomeTab(),
      const _SellerOrdersTab(),
      const _SellerAccountTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // remove back arrow
        title: const Text('Seller Dashboard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'repair_images':
                  final ctx = context;
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Repairing image URLs...')));
                  final count = await FirestoreProductsService.repairProductImageUrls(limit: 500);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Repaired $count product(s)')));
                  }
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'repair_images', child: ListTile(leading: Icon(Icons.build_circle_outlined), title: Text('Repair images (admin)'))),
              PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Exit to Home'))),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      // Floating button to sell/add a product
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              heroTag: 'sellProductFab',
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const SellerAddProductScreen()),
                );
                if (created == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product added')),
                  );
                }
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Sell Product'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

class _SellerHomeTab extends StatelessWidget {
  const _SellerHomeTab();

  Future<({String name, String? store})> _loadSellerMeta() async {
    final email = await LocalSellerAccountsStore.getCurrentSeller();
    final sellers = await LocalSellerAccountsStore.listSellers();
    final seller = sellers.firstWhere(
      (s) => s.email == (email ?? ''),
      orElse: () => sellers.isNotEmpty
          ? sellers.first
          : const SellerAccountModel(email: '', name: 'Seller', passwordHash: '', createdAtMs: 0),
    );
    return (name: seller.name.isEmpty ? 'Seller' : seller.name, store: seller.storeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<({String name, String? store})>(
      future: _loadSellerMeta(),
      builder: (context, snap) {
        final displayName = snap.data?.store ?? snap.data?.name ?? 'Seller';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroHeader(title: 'Hi, $displayName', subtitle: 'Here’s your store at a glance'),
            const SizedBox(height: 16),

            _OverviewMetrics(),

            const SizedBox(height: 16),

            // Quick actions (Add Product removed; use floating button instead)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickActionButton(
                          icon: Icons.inventory_outlined,
                          label: 'Manage Inventory',
                          color: Colors.indigo,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SellerInventoryScreen()),
                            );
                          },
                        ),
                        _QuickActionButton(
                          icon: Icons.receipt_long_outlined,
                          label: 'View Orders',
                          color: Colors.orange,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SellerOrdersScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mini chart card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales (last 7 days)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: _MiniSalesChart(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _RecentOrdersCard(),
          ],
        );
      },
    );
  }
}

class _SellerOrdersTab extends StatelessWidget {
  const _SellerOrdersTab();
  @override
  Widget build(BuildContext context) {
    return const SellerOrdersList(embed: true);
  }
}

class _SellerAccountTab extends StatefulWidget {
  const _SellerAccountTab();
  @override
  State<_SellerAccountTab> createState() => _SellerAccountTabState();
}

class _SellerAccountTabState extends State<_SellerAccountTab> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _email;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessionEmail = await LocalSellerAccountsStore.getCurrentSeller();
    final sellers = await LocalSellerAccountsStore.listSellers();
    final seller = sellers.firstWhere(
      (s) => s.email == (sessionEmail ?? ''),
      orElse: () => sellers.isNotEmpty
          ? sellers.first
          : const SellerAccountModel(email: '', name: '', passwordHash: '', createdAtMs: 0),
    );
    _email = seller.email.isEmpty ? sessionEmail : seller.email;
    _name.text = seller.name;
    setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _email == null || _email!.isEmpty) return;
    setState(() => _saving = true);
    final ok = await LocalSellerAccountsStore.updateProfile(
      email: _email!,
      name: _name.text.trim(),
      // Store name removed from UI per requirements
      storeName: null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile updated' : 'Unable to update')),
    );
  }

  Future<void> _changePassword() async {
    // Security management removed per requirements
  }

  Future<void> _signOut() async {
    // Session section removed; keeping stub for safety if referenced
  }

  Future<void> _deleteAccount() async {
    if (_email == null || _email!.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete seller account?'),
        content: const Text('This will remove your seller account from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await LocalSellerAccountsStore.removeSeller(_email!);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete account')));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Account', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 12),
                        // Store name field removed
                        TextFormField(
                          initialValue: _email ?? '',
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveProfile,
                            icon: _saving
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(theme.colorScheme.onPrimary)),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'Saving...' : 'Save changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Security and Session sections removed per requirements

                const SizedBox(height: 16),
                Text('Danger zone', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.red)),
                const SizedBox(height: 12),
                Card(
                  color: Colors.red.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.withValues(alpha: 0.3))),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever_outlined, color: Colors.red),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Delete seller account from this device')),
                        FilledButton.tonal(
                          onPressed: _deleteAccount,
                          style: FilledButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.1), foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
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

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeroHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onPrimary.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String label;
  final int value;
  final String? valuePrefix;
  final String? valueSuffix;
  const _MetricCard({super.key, required this.color, required this.icon, required this.label, required this.value, this.valuePrefix, this.valueSuffix});

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..forward();
  late final Animation<double> _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      height: 130,
      child: ScaleTransition(
        scale: _scale,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(widget.icon, color: widget.color),
                    ),
                    const Spacer(),
                    Icon(Icons.trending_up, color: Colors.green.withValues(alpha: 0.8), size: 18),
                  ],
                ),
                const Spacer(),
                Text(widget.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: widget.value.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  builder: (context, v, _) => Text(
                    '${widget.valuePrefix ?? ''}${v.toStringAsFixed(0)}${widget.valueSuffix ?? ''}',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _MiniSalesChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sellerId = FirebaseAuthService.currentUserId;
    if (sellerId == null || sellerId.isEmpty) {
      return const Center(child: Text('Sign in to view sales'));
    }

    return StreamBuilder<List<OrderItemModel>>(
      stream: FirestoreOrdersService.watchBySeller(sellerId),
      builder: (context, snap) {
        if (!snap.hasData) {
          // Avoid spinner: show a light placeholder
          return Center(
            child: Text('No data yet', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          );
        }
        final orders = snap.data!;
        // Build last 7 days buckets (6 days ago .. today)
        final now = DateTime.now();
        DateTime atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);
        final days = List<DateTime>.generate(7, (i) => atMidnight(now.subtract(Duration(days: 6 - i))));

        bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

        final dailyTotals = List<double>.generate(7, (i) {
          final day = days[i];
          final total = orders
              .where((o) => isSameDay(o.createdAt, day) && o.status != OrderStatus.cancelled)
              .fold<double>(0, (p, o) => p + o.total);
          return total;
        });

        final spots = <FlSpot>[
          for (int i = 0; i < 7; i++) FlSpot(i.toDouble(), dailyTotals[i])
        ];

        final maxY = (dailyTotals.fold<double>(0, (p, v) => v > p ? v : p));
        final maxYAdjusted = (maxY <= 0 ? 5.0 : (maxY * 1.2));

        String dayLabel(int index) {
          final d = days[index].weekday; // 1..7 Mon..Sun
          switch (d) {
            case DateTime.monday:
              return 'M';
            case DateTime.tuesday:
              return 'T';
            case DateTime.wednesday:
              return 'W';
            case DateTime.thursday:
              return 'T';
            case DateTime.friday:
              return 'F';
            case DateTime.saturday:
              return 'S';
            case DateTime.sunday:
            default:
              return 'S';
          }
        }

        return LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        idx >= 0 && idx < 7 ? dayLabel(idx) : '',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 6,
            minY: 0,
            maxY: maxYAdjusted,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: cs.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [cs.primary.withValues(alpha: 0.35), cs.primary.withValues(alpha: 0.05)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sellerId = FirebaseAuthService.currentUserId;
    if (sellerId == null || sellerId.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 140,
      child: StreamBuilder<List<AdminProductModel>>(
        // Use relaxed watcher to surface legacy items without sellerId
        stream: FirestoreProductsService.watchBySellerRelaxed(sellerId, includeInactive: false),
        builder: (context, prodSnap) {
          final liveProducts = prodSnap.data?.length ?? 0;
          return StreamBuilder<List<OrderItemModel>>(
            stream: FirestoreOrdersService.watchBySeller(sellerId),
            builder: (context, orderSnap) {
              final orders = orderSnap.data ?? const <OrderItemModel>[];
              final now = DateTime.now();
              bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
              // Today sales: sum order totals for orders created today and not cancelled
              final todaySales = orders
                  .where((o) => isSameDay(o.createdAt, now) && o.status != OrderStatus.cancelled)
                  .fold<double>(0, (p, o) => p + o.total);
              // Pending orders: processing or shipped
              final pending = orders.where((o) => o.status == OrderStatus.processing || o.status == OrderStatus.shipped).length;
              return ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _MetricCard(
                    color: Colors.teal,
                    icon: Icons.attach_money,
                    label: 'Today Sales',
                    value: todaySales.round(),
                    valuePrefix: '₹',
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    color: Colors.indigo,
                    icon: Icons.shopping_bag_outlined,
                    label: 'Orders Pending',
                    value: pending,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    color: Colors.orange,
                    icon: Icons.inventory_2_outlined,
                    label: 'Products Live',
                    value: liveProducts,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sellerId = FirebaseAuthService.currentUserId;
    if (sellerId == null || sellerId.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Recent orders', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<OrderItemModel>>(
              stream: FirestoreOrdersService.watchBySeller(sellerId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  // Avoid spinner: compact placeholder
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text('No recent orders', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    ),
                  );
                }
                final orders = snap.data!;
                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No recent orders', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  );
                }
                final recent = orders.take(5).toList();
                return Column(
                  children: [
                    ...recent.map((o) => _OrderListTile(
                          title: 'Order ${o.id.substring(0, 6).toUpperCase()} · ${o.items.length} item(s)',
                          subtitle: _fmtDate(o.createdAt),
                          color: o.status == OrderStatus.cancelled
                              ? Colors.red
                              : (o.status == OrderStatus.delivered
                                  ? Colors.teal
                                  : (o.status == OrderStatus.shipped ? Colors.indigo : Colors.orange)),
                        )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$m/$day/${d.year} • $hh:$mm';
  }
}

class _OrderListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  const _OrderListTile({required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.shopping_bag, color: color)),
      title: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      onTap: () {},
    );
  }
}
