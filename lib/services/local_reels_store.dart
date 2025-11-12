import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/reel_item.dart';

class LocalReelsStore {
  static const String _key = 'reels_v1';

  static Future<List<ReelItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return <ReelItem>[];
    try {
      return ReelItem.decodeList(s);
    } catch (_) {
      return <ReelItem>[];
    }
  }

  static Future<void> saveAll(List<ReelItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ReelItem.encodeList(items));
  }

  static Future<void> add(ReelItem item) async {
    final items = await loadAll();
    items.insert(0, item); // newest first
    await saveAll(items);
  }

  static Future<void> remove(String id) async {
    final items = await loadAll();
    items.removeWhere((e) => e.id == id);
    await saveAll(items);
  }
}
