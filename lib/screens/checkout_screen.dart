import 'package:flutter/material.dart';
import 'package:passage/models/cart_item.dart';
import 'package:passage/models/order.dart';
import 'package:passage/services/local_cart_store.dart';
import 'package:passage/services/firestore_orders_service.dart';
import 'orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  const CheckoutScreen({super.key, required this.items});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _placing = false;

  double get _subtotal => widget.items.fold(0.0, (sum, e) => sum + e.unitPrice * e.quantity);
  // Campus marketplace: local pickup only
  double get _shippingFee => 0.0;
  double get _tax => 0.0;
  double get _total => _subtotal + _shippingFee + _tax;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // No-op: local pickup flow doesn't require preloading address/payment defaults
  }





  Future<void> _placeOrder() async {
    // No address/payment required for local pickup reservations
    setState(() => _placing = true);

    final now = DateTime.now();
    final order = OrderItemModel(
      id: 'ord-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'demo-user',
      createdAt: now,
      updatedAt: now,
      status: OrderStatus.processing,
      items: widget.items
          .map((e) => OrderLineItem(
                productId: e.productId,
                name: e.name,
                imageUrl: e.imageUrl,
                unitPrice: e.unitPrice,
                quantity: e.quantity,
              ))
          .toList(),
      subtotal: _subtotal,
      shippingFee: _shippingFee,
      tax: _tax,
      total: _total,
      shippingAddressSummary: 'Local pickup',
      paymentSummary: 'Pay in person',
      notes: 'Reservation created for local pickup',
    );

    await FirestoreOrdersService.create(order);
    await LocalCartStore.clear();

    if (!mounted) return;
    setState(() => _placing = false);

    // Show success and redirect
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Order placed!', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Reservation created. Coordinate pickup with the seller in Orders.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // dismiss sheet
                        Navigator.pop(context, true); // return to cart with success
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        );
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View orders'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                   _sectionTitle(context, 'Pickup'),
                   Card(
                     child: ListTile(
                       leading: CircleAvatar(
                         backgroundColor: Colors.teal.withValues(alpha: 0.12),
                         child: const Icon(Icons.handshake_outlined, color: Colors.teal),
                       ),
                       title: const Text('Local pickup on campus'),
                       subtitle: const Text('You’ll coordinate time and place directly with the seller'),
                     ),
                   ),
                   const SizedBox(height: 16),

                  _sectionTitle(context, 'Order summary'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          ...widget.items.map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.shopping_bag_outlined, color: Colors.indigo, size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text('Qty ${e.quantity}', style: theme.textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                    Text('\$${(e.unitPrice * e.quantity).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              )),
                          const Divider(height: 20),
                          _priceRow('Subtotal', _subtotal),
                          const SizedBox(height: 6),
                          _priceRow('Shipping', _shippingFee, freeWhenZero: true),
                          const SizedBox(height: 6),
                          _priceRow('Tax', _tax),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                              const Spacer(),
                              Text('\$${_total.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                   Text('This is a student marketplace. Orders are local pickup only. No delivery or in-app payments.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                ],
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08))),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                    child: FilledButton.icon(
                    onPressed: _placing ? null : _placeOrder,
                      icon: _placing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.handshake_rounded),
                      label: const Text('Reserve for pickup'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _priceRow(String label, double value, {bool freeWhenZero = false}) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(value == 0 && freeWhenZero ? 'Free' : '\$${value.toStringAsFixed(2)}'),
      ],
    );
  }
}
