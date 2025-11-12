import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/order.dart';

class LocalOrdersStore {
  static const String _key = 'orders_v1';

  static Future<List<OrderItemModel>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];
    try {
      return OrderItemModel.decodeList(s);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<OrderItemModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, OrderItemModel.encodeList(items));
  }

  static Future<void> upsert(OrderItemModel item) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.insert(0, item); // newest first
    }
    await saveAll(items);
  }

  static Future<void> remove(String id) async {
    final items = await loadAll();
    items.removeWhere((e) => e.id == id);
    await saveAll(items);
  }

  static Future<OrderItemModel?> getById(String id) async {
    final items = await loadAll();
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
