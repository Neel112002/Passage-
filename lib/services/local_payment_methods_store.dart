import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/payment_method.dart';

class LocalPaymentMethodsStore {
  static const String _key = 'payment_methods_v1';

  static Future<List<PaymentMethodItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];
    try {
      return PaymentMethodItem.decodeList(s);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<PaymentMethodItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, PaymentMethodItem.encodeList(items));
  }

  static Future<void> upsert(PaymentMethodItem item) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      // Ensure at most one default
      if (item.isDefault) {
        for (var i = 0; i < items.length; i++) {
          items[i] = items[i].copyWith(isDefault: i == idx);
        }
        items[idx] = item.copyWith(isDefault: true);
      } else {
        items[idx] = item;
      }
    } else {
      if (item.isDefault) {
        for (var i = 0; i < items.length; i++) {
          items[i] = items[i].copyWith(isDefault: false);
        }
      } else if (items.isEmpty) {
        // First payment method becomes default automatically
        item = item.copyWith(isDefault: true);
      }
      items.add(item);
    }
    await saveAll(items);
  }

  static Future<void> remove(String id) async {
    final items = await loadAll();
    final wasDefault = items.firstWhere(
      (e) => e.id == id,
      orElse: () => const PaymentMethodItem(id: '', type: PaymentMethodType.cod, label: '', details: '', isDefault: false),
    ).isDefault;
    items.removeWhere((e) => e.id == id);
    if (wasDefault && items.isNotEmpty) {
      items[0] = items[0].copyWith(isDefault: true);
      for (var i = 1; i < items.length; i++) {
        items[i] = items[i].copyWith(isDefault: false);
      }
    }
    await saveAll(items);
  }

  static Future<void> setDefault(String id) async {
    final items = await loadAll();
    bool found = false;
    for (var i = 0; i < items.length; i++) {
      final isDef = items[i].id == id;
      items[i] = items[i].copyWith(isDefault: isDef);
      if (isDef) found = true;
    }
    if (found) await saveAll(items);
  }

  static Future<PaymentMethodItem?> getDefault() async {
    final items = await loadAll();
    try {
      return items.firstWhere((e) => e.isDefault);
    } catch (_) {
      if (items.isNotEmpty) return items.first;
      return null;
    }
  }
}
