import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:passage/models/order.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/services/firestore_orders_service.dart';
// Removed LocalProductsStore; no demo seeding
// Removed product import (no demo seeding)

class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Orders')),
      body: const SellerOrdersList(embed: false),
    );
  }
}

enum _SellerOrderFilter { all, active, processing, shipped, delivered, cancelled }

class SellerOrdersList extends StatefulWidget {
  final bool embed; // if true, show padding without its own Scaffold
  const SellerOrdersList({super.key, required this.embed});

  @override
  State<SellerOrdersList> createState() => _SellerOrdersListState();
}

class _SellerOrdersListState extends State<SellerOrdersList> {
  List<OrderItemModel> _orders = [];
  bool _loading = true;

  // UI state
  _SellerOrderFilter _filter = _SellerOrderFilter.all;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Stream<List<OrderItemModel>>? _stream;

  @override
  void initState() {
    super.initState();
    final sellerId = FirebaseAuthService.currentUserId;
    _stream = (sellerId == null || sellerId.isEmpty)
        ? Stream.value(<OrderItemModel>[])
        : FirestoreOrdersService.watchBySeller(sellerId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async => Future.delayed(const Duration(milliseconds: 250));

  List<OrderItemModel> get _visibleOrders {
    Iterable<OrderItemModel> out = _orders;

    // Filter
    out = out.where((o) {
      switch (_filter) {
        case _SellerOrderFilter.all:
          return true;
        case _SellerOrderFilter.active:
          return o.status == OrderStatus.processing || o.status == OrderStatus.shipped;
        case _SellerOrderFilter.processing:
          return o.status == OrderStatus.processing;
        case _SellerOrderFilter.shipped:
          return o.status == OrderStatus.shipped;
        case _SellerOrderFilter.delivered:
          return o.status == OrderStatus.delivered;
        case _SellerOrderFilter.cancelled:
          return o.status == OrderStatus.cancelled;
      }
    });

    // Search by order id or item name
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((o) {
        final idMatch = o.id.toLowerCase().contains(q);
        final itemMatch = o.items.any((i) => i.name.toLowerCase().contains(q));
        return idMatch || itemMatch;
      });
    }

    // Sort newest first
    final list = out.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.processing:
        return Colors.orange;
      case OrderStatus.shipped:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.teal;
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
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$m/$day/${d.year} • $hh:$mm';
  }

  Future<void> _updateStatus(OrderItemModel order, OrderStatus status) async {
    await FirestoreOrdersService.updateStatusBySeller(order.id, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order ${order.id.substring(0, 6).toUpperCase()} → ${_statusLabel(status)}')),
    );
  }

  Future<void> _editTrackingNumber(OrderItemModel order) async {
    final ctrl = TextEditingController(text: order.trackingNumber ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit tracking number'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g., 1Z999AA10123456784',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (result != null) {
      await FirestoreOrdersService.updateTrackingBySeller(order.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tracking updated')),
        );
      }
    }
  }

  void _openDetail(OrderItemModel o) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text('Order ${o.id.substring(0, 6).toUpperCase()}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(o.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: _statusColor(o.status).withValues(alpha: 0.25)),
                  ),
                  child: Text(_statusLabel(o.status),
                      style: theme.textTheme.bodySmall?.copyWith(color: _statusColor(o.status), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Placed on ${_fmtDate(o.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            ...o.items.map(
              (it) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 48, height: 48, child: _AnyImage(url: it.imageUrl, width: 48, height: 48)),
                ),
                title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Qty ${it.quantity} · \$${it.unitPrice.toStringAsFixed(2)}'),
                trailing: Text('\$${(it.unitPrice * it.quantity).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const Divider(height: 24),
            _line('Subtotal', o.subtotal),
            _line('Shipping', o.shippingFee),
            _line('Tax', o.tax),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('\$${o.total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                    onPressed: () => _updateStatus(o, OrderStatus.processing),
                    icon: const Icon(Icons.hourglass_bottom),
                    label: const Text('Processing')),
                OutlinedButton.icon(
                    onPressed: () => _updateStatus(o, OrderStatus.shipped),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Shipped')),
                OutlinedButton.icon(
                    onPressed: () => _updateStatus(o, OrderStatus.delivered),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Delivered')),
                OutlinedButton.icon(
                    onPressed: () => _updateStatus(o, OrderStatus.cancelled),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelled')),
                FilledButton.tonalIcon(
                  onPressed: () => _editTrackingNumber(o),
                  icon: const Icon(Icons.edit_note, color: Colors.deepPurple),
                  label: Text(o.trackingNumber == null || o.trackingNumber!.isEmpty
                      ? 'Add tracking'
                      : 'Edit tracking'),
                )
              ],
            ),
            const SizedBox(height: 12),
            if (o.trackingNumber != null && o.trackingNumber!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tracking: ${o.trackingNumber!}', style: theme.textTheme.bodySmall)),
                ],
              ),
            if (o.shippingAddressSummary != null)
              Text('Ship to: ${o.shippingAddressSummary}', style: theme.textTheme.bodySmall),
            if (o.paymentSummary != null)
              Text('Paid via: ${o.paymentSummary}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text('\$${amount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<OrderItemModel>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          // Avoid spinner per request
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Loading orders…', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
          );
        }
        _orders = snap.data!;
        final visible = _visibleOrders;
        Widget content;
        if (visible.isEmpty) {
          content = _emptyState(theme);
        } else {
          content = ListView(
            padding: EdgeInsets.only(top: widget.embed ? 8 : 12, bottom: 24),
            children: [
              _topControls(theme),
              _summaryRow(theme),
              const SizedBox(height: 4),
              ...visible.map((o) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _orderCard(o, theme),
                  )),
              const SizedBox(height: 24),
            ],
          );
        }
        return RefreshIndicator(onRefresh: _refresh, child: content);
      },
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
                _filterChip('All', _SellerOrderFilter.all),
                _filterChip('Active', _SellerOrderFilter.active),
                _filterChip('Processing', _SellerOrderFilter.processing),
                _filterChip('Shipped', _SellerOrderFilter.shipped),
                _filterChip('Delivered', _SellerOrderFilter.delivered),
                _filterChip('Cancelled', _SellerOrderFilter.cancelled),
                const SizedBox(width: 8),
                Text('${_visibleOrders.length} result(s)', style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(ThemeData theme) {
    final total = _orders.fold<double>(0, (p, o) => p + o.total);
    final active = _orders.where((o) => o.status == OrderStatus.processing || o.status == OrderStatus.shipped).length;
    final delivered = _orders.where((o) => o.status == OrderStatus.delivered).length;
    final cancelled = _orders.where((o) => o.status == OrderStatus.cancelled).length;

    final now = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    final todayRevenue = _orders.where((o) => isSameDay(o.createdAt, now)).fold<double>(0, (p, o) => p + o.total);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Responsive columns: 2 on small phones, 3 on tablets, 4 on desktop
        int cols = 2;
        if (width >= 1200) {
          cols = 4;
        } else if (width >= 900) {
          cols = 3;
        } else if (width >= 600) {
          cols = 2;
        }

        const gap = 8.0;
        final horizontalPadding = 16.0 * 2; // from external padding below
        final available = width - horizontalPadding - gap * (cols - 1);
        final itemWidth = available / cols;

        Widget tile({required IconData icon, required Color color, required String label, required String value}) {
          return SizedBox(
            width: itemWidth,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              tile(icon: Icons.flash_on, color: Colors.orange, label: 'Active', value: '$active'),
              tile(icon: Icons.verified, color: Colors.teal, label: 'Delivered', value: '$delivered'),
              tile(icon: Icons.cancel, color: Colors.red, label: 'Cancelled', value: '$cancelled'),
              tile(icon: Icons.payments_rounded, color: Colors.indigo, label: 'Revenue', value: '\$${total.toStringAsFixed(2)}'),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, _SellerOrderFilter value) {
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
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: _AnyImage.square56(url: show[i].imageUrl, fallbackColor: theme.colorScheme.surfaceVariant),
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

  Widget _orderCard(OrderItemModel o, ThemeData theme) {
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openDetail(o),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.deepPurple),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ${o.id.substring(0, 6).toUpperCase()}',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(_fmtDate(o.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  _statusPill(o.status),
                ],
              ),
              const SizedBox(height: 12),
              _thumbStrip(o, context),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${o.items.length} item(s)',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
                  const Spacer(),
                  Text('\$${o.total.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _topControls(theme),
        _summaryRow(theme),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_outlined, color: Colors.deepPurple, size: 40),
              ),
              const SizedBox(height: 16),
              Text('No orders yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('You\'ll see new orders here as customers checkout.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Demo seeding removed to keep only real orders
}

class _AnyImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? fallbackColor;
  const _AnyImage({required this.url, this.fit = BoxFit.cover, this.width, this.height, this.fallbackColor});

  factory _AnyImage.square56({required String url, Color? fallbackColor}) =>
      _AnyImage(url: url, width: 56, height: 56, fit: BoxFit.cover, fallbackColor: fallbackColor);

  bool get _isDataImage => url.startsWith('data:image');

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cw = width != null ? (width! * dpr).round() : null;
    final ch = height != null ? (height! * dpr).round() : null;
    if (_isDataImage) {
      try {
        final base64Part = url.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cw,
          cacheHeight: ch,
          filterQuality: FilterQuality.low,
        );
      } catch (_) {
        return Container(width: width, height: height, color: fallbackColor ?? Colors.black12);
      }
    }
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cw,
      cacheHeight: ch,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/icons/dreamflow_icon.jpg',
        fit: fit,
        width: width,
        height: height,
      ),
    );
  }
}
