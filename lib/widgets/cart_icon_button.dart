import 'package:flutter/material.dart';
import 'package:passage/screens/cart_screen.dart';
import 'package:passage/services/local_cart_store.dart';

// Global key to locate the cart icon on screen for fly-to-cart animations
final GlobalKey cartIconGlobalKey = GlobalKey(debugLabel: 'cartIcon');

class CartIconButton extends StatelessWidget {
  final Color iconColor;
  final EdgeInsets badgePadding;
  final VoidCallback? onPressed;
  const CartIconButton({super.key, this.iconColor = Colors.green, this.badgePadding = const EdgeInsets.only(right: 8, top: 8), this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 0),
      child: ValueListenableBuilder<int>(
        valueListenable: LocalCartStore.itemCountNotifier,
        builder: (context, count, _) {
          print('Cart icon rebuilding with count: $count');
          return Stack(
            key: cartIconGlobalKey.currentContext == null ? cartIconGlobalKey : null,
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onPressed ?? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
                icon: Icon(Icons.shopping_cart_outlined, color: iconColor),
                tooltip: 'Cart',
              ),
              if (count > 0)
                Positioned(
                  // Position at top-right of icon
                  right: 4,
                  top: 4,
                  child: _AnimatedBadge(count: count),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  final int count;
  const _AnimatedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : count.toString();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: child,
        );
      },
      child: Container(
        key: ValueKey(display),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Center(
          child: Text(
            display,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
