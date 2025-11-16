import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cart_screen.dart';
import 'package:passage/models/order.dart';
import 'package:passage/models/cart_item.dart';
import 'package:passage/services/local_cart_store.dart';
import 'package:passage/services/local_orders_store.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

enum _OrderFilter { all, active, delivered, cancelled }

class _OrdersScreenState extends State<OrdersScreen> {
  List<OrderItemModel> _orders = [];
  bool _loading = true;

  // UI state
  _OrderFilter _filter = _OrderFilter.all;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await LocalOrdersStore.loadAll();
    setState(() {
      _orders = items;
      _loading = false;
    });
  }

  List<OrderItemModel> get _visibleOrders {
    Iterable<OrderItemModel> out = _orders;

    // Filter
    out = out.where((o) {
      switch (_filter) {
        case _OrderFilter.all:
          return true;
        case _OrderFilter.active:
          return o.status == OrderStatus.processing || o.status == OrderStatus.shipped;
        case _OrderFilter.delivered:
          return o.status == OrderStatus.delivered;
        case _OrderFilter.cancelled:
          return o.status == OrderStatus.cancelled;
      }
    });

    // Search
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((o) {
        final idMatch = o.id.toLowerCase().contains(q);
        final itemMatch = o.items.any((i) => i.name.toLowerCase().contains(q));
        return idMatch || itemMatch;
      });
    }

    return out.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Orders'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _orders.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48),
                          child: Column(
                            children: [
                              const Icon(Icons.inbox_outlined, size: 72, color: Colors.blueGrey),
                              const SizedBox(height: 12),
                              Text('No orders',
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                'When you place orders, they will appear here for tracking.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.shopping_bag, color: Colors.teal),
                                label: const Text('Browse products'),
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _topControls(theme)),
                        if (_visibleOrders.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 72),
                              child: Column(
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 64, color: Colors.blueGrey),
                                  const SizedBox(height: 12),
                                  Text('No matching orders',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text('Try a different keyword or filter.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      )),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverList.separated(
                            itemCount: _visibleOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final o = _visibleOrders[index];
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OrderDetailsScreen(orderId: o.id),
                                    ),
                                  ),
                                  child: Card(
                                    margin: EdgeInsets.zero,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'Order ${o.id.substring(0, 6).toUpperCase()}',
                                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        _statusPill(o.status),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      '${o.items.length} item(s) • ${_fmtDate(o.createdAt)}',
                                                      style: theme.textTheme.bodySmall,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          _thumbStrip(o, context),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  o.paymentSummary ?? '-',
                                                  style: theme.textTheme.bodySmall,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '\$${o.total.toStringAsFixed(2)}',
                                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _AnimatedOrderTrackingBar(status: o.status),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ],
                    ),
            ),
    );
  }

  Widget _topControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search orders or items',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  textInputAction: TextInputAction.search,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                _filterChip('All', _OrderFilter.all),
                _filterChip('Active', _OrderFilter.active),
                _filterChip('Delivered', _OrderFilter.delivered),
                _filterChip('Cancelled', _OrderFilter.cancelled),
                const SizedBox(width: 8),
                Text('${_visibleOrders.length} result(s)', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _OrderFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        avatar: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }

  Widget _thumbStrip(OrderItemModel o, BuildContext context) {
    final theme = Theme.of(context);
    final count = o.items.length;
    final show = o.items.take(4).toList();

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          for (int i = 0; i < show.length; i++) ...[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.shopping_bag_outlined, color: Colors.indigo),
              ),
            ),
            if (i != show.length - 1) const SizedBox(width: 8),
          ],
          if (count > 4) ...[
            const SizedBox(width: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('+${count - 4}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _statusPill(OrderStatus s) {
    final color = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(s),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.processing:
        return Colors.amber;
      case OrderStatus.shipped:
        return Colors.blue;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$m/$day/${d.year}';
  }
}

class _AnimatedOrderTrackingBar extends StatelessWidget {
  final OrderStatus status;
  const _AnimatedOrderTrackingBar({required this.status});

  int get _currentStep => switch (status) {
        OrderStatus.processing => 0,
        OrderStatus.shipped => 1,
        OrderStatus.delivered => 2,
        OrderStatus.cancelled => -1,
      };

  double get _progress => switch (status) {
        OrderStatus.processing => 0.33,
        OrderStatus.shipped => 0.66,
        OrderStatus.delivered => 1.0,
        OrderStatus.cancelled => 0.0,
      };

  Color get _activeColor => switch (status) {
        OrderStatus.processing => Colors.amber,
        OrderStatus.shipped => Colors.blue,
        OrderStatus.delivered => Colors.green,
        OrderStatus.cancelled => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status == OrderStatus.cancelled) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: Container(
          key: const ValueKey('cancelled'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Order cancelled',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(_activeColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _stepLabel('Processing', 0, theme),
            _dot(),
            _stepLabel('Shipped', 1, theme),
            _dot(),
            _stepLabel('Delivered', 2, theme),
          ],
        ),
      ],
    );
  }

  Widget _dot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Icon(Icons.circle, size: 6, color: Colors.grey.withValues(alpha: 0.6)),
      );

  Widget _stepLabel(String text, int stepIndex, ThemeData theme) {
    final active = _currentStep >= stepIndex;
    final color = active ? _activeColor : Colors.grey;
    return Expanded(
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        style: theme.textTheme.labelSmall!.copyWith(
          color: color,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              stepIndex == 0
                  ? Icons.receipt_long
                  : (stepIndex == 1 ? Icons.local_shipping : Icons.home),
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  OrderItemModel? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final o = await LocalOrdersStore.getById(widget.orderId);
    setState(() {
      _order = o;
      _loading = false;
    });
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final updated = _order!.copyWith(status: OrderStatus.cancelled);
      await LocalOrdersStore.upsert(updated);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Order cancelled')));
      }
    }
  }

  Future<void> _reorderItems() async {
    final o = _order;
    if (o == null) return;
    int totalLines = 0;
    for (final li in o.items) {
      await LocalCartStore.addOrIncrement(CartItem(
        productId: li.productId,
        name: li.name,
        imageUrl: li.imageUrl,
        unitPrice: li.unitPrice,
        quantity: li.quantity,
      ));
      totalLines += li.quantity;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $totalLines item(s) to cart'),
        action: SnackBarAction(
          label: 'View cart',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
      ),
    );
  }

  Future<void> _copyTracking(String tracking) async {
    try {
      await Clipboard.setData(ClipboardData(text: tracking));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking number copied')),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text('Order not found',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _headerCard(_order!),
                    const SizedBox(height: 12),
                    _itemsCard(_order!),
                    const SizedBox(height: 12),
                    _summaryCard(_order!),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _reorderItems,
                          icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.teal),
                          label: const Text('Reorder items'),
                        ),
                        if (_order!.trackingNumber != null && _order!.trackingNumber!.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _copyTracking(_order!.trackingNumber!),
                            icon: const Icon(Icons.local_shipping_outlined, color: Colors.blue),
                            label: const Text('Copy tracking'),
                          ),
                        if (_order!.status == OrderStatus.processing)
                          FilledButton.icon(
                            onPressed: _cancelOrder,
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text('Cancel order'),
                          ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _headerCard(OrderItemModel o) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${o.id.substring(0, 6).toUpperCase()}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _statusChip(o.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('Placed on ${_fmtDateTime(o.createdAt)}', style: theme.textTheme.bodySmall),
            if (o.trackingNumber != null && o.trackingNumber!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Tracking: ${o.trackingNumber!}', style: theme.textTheme.bodySmall),
                  ),
                  TextButton(
                    onPressed: () => _copyTracking(o.trackingNumber!),
                    child: const Text('Copy'),
                  )
                ],
              ),
            ],
            if (o.shippingAddressSummary != null && o.shippingAddressSummary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(o.shippingAddressSummary!, style: theme.textTheme.bodyMedium),
                  )
                ],
              ),
            ],
            if (o.paymentSummary != null && o.paymentSummary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.payment, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(o.paymentSummary!, style: theme.textTheme.bodyMedium),
                  )
                ],
              ),
            ],
            const SizedBox(height: 12),
            _AnimatedOrderTrackingBar(status: o.status),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(OrderStatus s) {
    final color = () {
      switch (s) {
        case OrderStatus.processing:
          return Colors.amber;
        case OrderStatus.shipped:
          return Colors.blue;
        case OrderStatus.delivered:
          return Colors.green;
        case OrderStatus.cancelled:
          return Colors.red;
      }
    }();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        () {
          switch (s) {
            case OrderStatus.processing:
              return 'Processing';
            case OrderStatus.shipped:
              return 'Shipped';
            case OrderStatus.delivered:
              return 'Delivered';
            case OrderStatus.cancelled:
              return 'Cancelled';
          }
        }(),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _itemsCard(OrderItemModel o) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...o.items.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.shopping_bag_outlined, color: Colors.indigo),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Qty ${i.quantity}', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('\$${i.lineTotal.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(OrderItemModel o) {
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(value,
                  style: bold
                      ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)
                      : theme.textTheme.bodyMedium),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            row('Subtotal', '\$${o.subtotal.toStringAsFixed(2)}'),
            row('Shipping', '\$${o.shippingFee.toStringAsFixed(2)}'),
            row('Tax', '\$${o.tax.toStringAsFixed(2)}'),
            const Divider(height: 16),
            row('Total', '\$${o.total.toStringAsFixed(2)}', bold: true),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$m/$day/${d.year} • $hh:$mm';
  }
}

// ignore: unused_element
class _AnyImage extends StatelessWidget {
  final String url;
  const _AnyImage({required this.url});

  bool get _isDataImage => url.startsWith('data:image');

  @override
  Widget build(BuildContext context) {
    if (_isDataImage) {
      try {
        final base64Part = url.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        );
      } catch (_) {
        return Container(color: Colors.black12);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/icons/dreamflow_icon.jpg',
        fit: BoxFit.cover,
      ),
    );
  }
}
