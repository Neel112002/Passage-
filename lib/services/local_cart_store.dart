import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/cart_item.dart';

class LocalCartStore {
  static const String _key = 'cart_items_v1';

  // Live item count notifier for badges
  static final ValueNotifier<int> itemCountNotifier = ValueNotifier<int>(0);

  // Call once on app start to populate initial count
  static Future<void> bootstrap() async {
    final c = await countItems();
    itemCountNotifier.value = c;
  }

  static Future<List<CartItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];
    try {
      return CartItem.decodeList(s);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, CartItem.encodeList(items));
    _emitCount(items);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _emitCount(const []);
  }

  static Future<void> addOrIncrement(CartItem item) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.productId == item.productId);
    if (idx >= 0) {
      final existing = items[idx];
      items[idx] = existing.copyWith(quantity: existing.quantity + item.quantity);
    } else {
      items.add(item);
    }
    await saveAll(items);
  }

  static Future<void> setQuantity(String productId, int quantity) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.productId == productId);
    if (idx >= 0) {
      if (quantity <= 0) {
        items.removeAt(idx);
      } else {
        items[idx] = items[idx].copyWith(quantity: quantity);
      }
      await saveAll(items);
    }
  }

  static Future<void> remove(String productId) async {
    final items = await loadAll();
    items.removeWhere((e) => e.productId == productId);
    await saveAll(items);
  }

  static Future<int> countItems() async {
    final items = await loadAll();
    return items.fold<int>(0, (sum, e) => sum + e.quantity);
  }

  static Future<double> subtotal() async {
    final items = await loadAll();
    return items.fold<double>(0.0, (sum, e) => sum + e.unitPrice * e.quantity);
  }

  static void _emitCount(List<CartItem> items) {
    final c = items.fold<int>(0, (sum, e) => sum + e.quantity);
    print('Cart count update: old=${itemCountNotifier.value}, new=$c, items=${items.length}');
    if (itemCountNotifier.value != c) {
      itemCountNotifier.value = c;
    }
  }
}
