import 'package:flutter/material.dart';
import 'package:passage/models/cart_item.dart';
import 'package:passage/services/local_cart_store.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await LocalCartStore.loadAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  double get _subtotal => _items.fold(0.0, (sum, e) => sum + e.unitPrice * e.quantity);
  double get _shippingFee => _subtotal >= 50 ? 0 : (_items.isEmpty ? 0 : 4.99);
  double get _tax => _subtotal * 0.08;
  double get _total => _subtotal + _shippingFee + _tax;

  Future<void> _increment(String productId) async {
    final idx = _items.indexWhere((e) => e.productId == productId);
    if (idx < 0) return;
    final next = _items[idx].copyWith(quantity: _items[idx].quantity + 1);
    await LocalCartStore.setQuantity(productId, next.quantity);
    setState(() => _items[idx] = next);
  }

  Future<void> _decrement(String productId) async {
    final idx = _items.indexWhere((e) => e.productId == productId);
    if (idx < 0) return;
    final current = _items[idx];
    if (current.quantity <= 1) {
      await _remove(productId);
      return;
    }
    final next = current.copyWith(quantity: current.quantity - 1);
    await LocalCartStore.setQuantity(productId, next.quantity);
    setState(() => _items[idx] = next);
  }

  Future<void> _remove(String productId) async {
    await LocalCartStore.remove(productId);
    setState(() => _items.removeWhere((e) => e.productId == productId));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from cart')));
  }

  Future<void> _clear() async {
    await LocalCartStore.clear();
    setState(() => _items = const []);
  }

  Future<void> _checkout() async {
    if (_items.isEmpty) return;
    final placed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(items: _items)),
    );
    if (placed == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              label: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _EmptyCart(onBrowse: () => Navigator.pop(context))
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _CartRow(
                              item: item,
                              onIncrement: () => _increment(item.productId),
                              onDecrement: () => _decrement(item.productId),
                              onRemove: () => _remove(item.productId),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: _items.length,
                        ),
                      ),
                      _SummaryCard(
                        subtotal: _subtotal,
                        shipping: _shippingFee,
                        tax: _tax,
                        total: _total,
                        onCheckout: _checkout,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  const _CartRow({required this.item, required this.onIncrement, required this.onDecrement, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
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
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('\$${item.unitPrice.toStringAsFixed(2)} each', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _qtyButton(icon: Icons.remove, color: Colors.red, onTap: onDecrement),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('${item.quantity}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      _qtyButton(icon: Icons.add, color: Colors.green, onTap: onIncrement),
                      const Spacer(),
                      Text('\$${item.lineTotal.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;
  final VoidCallback onCheckout;
  const _SummaryCard({required this.subtotal, required this.shipping, required this.tax, required this.total, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Subtotal'),
                const Spacer(),
                Text('\$${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Shipping'),
                const Spacer(),
                Text(shipping == 0 ? 'Free' : '\$${shipping.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Tax'),
                const Spacer(),
                Text('\$${tax.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('\$${total.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.lock),
                label: const Text('Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyCart({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.teal),
            const SizedBox(height: 12),
            Text('Your cart is empty', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Browse products and add items to your cart to checkout later.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.explore),
              label: const Text('Start shopping'),
            ),
          ],
        ),
      ),
    );
  }
}
