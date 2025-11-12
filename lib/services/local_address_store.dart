import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/address.dart';

class LocalAddressStore {
  static const String _key = 'addresses_v1';

  static Future<List<AddressItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];
    try {
      return AddressItem.decodeList(s);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<AddressItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, AddressItem.encodeList(items));
  }

  static Future<void> upsert(AddressItem item) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      // Preserve uniqueness of default
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
        // First address becomes default automatically
        item = item.copyWith(isDefault: true);
      }
      items.add(item);
    }
    await saveAll(items);
  }

  static Future<void> remove(String id) async {
    final items = await loadAll();
    final wasDefault = items.firstWhere((e) => e.id == id, orElse: () => const AddressItem(
      id: '', label: '', recipientName: '', phone: '', line1: '', line2: '', city: '', state: '', postalCode: '', countryCode: '', isDefault: false,
    )).isDefault;
    items.removeWhere((e) => e.id == id);
    if (wasDefault && items.isNotEmpty) {
      // Promote first to default
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

  static Future<AddressItem?> getDefault() async {
    final items = await loadAll();
    return items.firstWhere((e) => e.isDefault, orElse: () => items.isNotEmpty ? items.first : const AddressItem(
      id: '', label: '', recipientName: '', phone: '', line1: '', line2: '', city: '', state: '', postalCode: '', countryCode: '', isDefault: false,
    ));
  }
}
