import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/notification_item.dart';
import 'package:passage/models/notification_prefs.dart';
import 'package:passage/services/local_notification_prefs_store.dart';

class LocalNotificationsStore {
  static const String _key = 'notifications_v1';

  // --------------------
  // Persistence helpers
  // --------------------
  static Future<List<AppNotification>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return AppNotification.decodeList(jsonStr);
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<AppNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, AppNotification.encodeList(items));
  }

  static Future<int> unreadCount() async {
    final items = await loadAll();
    return items.where((e) => !e.read).length;
  }

  // --------------------
  // Delivery gating
  // --------------------
  static bool _categoryEnabled(NotificationPrefs p, NotificationType t) {
    switch (t) {
      case NotificationType.order:
        return p.orderUpdates;
      case NotificationType.promotion:
        return p.promotions;
      case NotificationType.priceDrop:
        return p.priceDrops;
      case NotificationType.system:
        return p.systemAlerts;
    }
  }

  static bool _isInQuietHours(NotificationPrefs p, DateTime now) {
    if (!p.dndEnabled) return false;
    final minutesNow = now.hour * 60 + now.minute;
    final start = p.dndStartMinutes % 1440;
    final end = p.dndEndMinutes % 1440;
    if (start == end) {
      // Edge case: full-day mute
      return true;
    }
    if (start < end) {
      // Same-day window, e.g., 22:00 -> 23:59
      return minutesNow >= start && minutesNow < end;
    } else {
      // Cross-midnight window, e.g., 22:00 -> 07:00
      return minutesNow >= start || minutesNow < end;
    }
  }

  /// Returns true if the notification should be delivered now based on user prefs.
  static Future<bool> _shouldDeliver(AppNotification item) async {
    final prefs = await LocalNotificationPrefsStore.load();
    if (!prefs.pushEnabled) return false;
    if (!_categoryEnabled(prefs, item.type)) return false;
    if (_isInQuietHours(prefs, DateTime.now())) return false;
    return true;
  }

  // --------------------
  // CRUD
  // --------------------
  /// Insert or update a notification. New insertions are gated by preferences
  /// (push master, category toggles, Do Not Disturb). Updates to existing
  /// notifications always go through so UI actions like mark read/unread work.
  static Future<void> upsert(AppNotification item) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == item.id);

    if (idx >= 0) {
      // Existing item: always allow update
      items[idx] = item;
      await saveAll(items);
      return;
    }

    // New item: respect user preferences
    final allowed = await _shouldDeliver(item);
    if (!allowed) {
      return; // drop silently
    }

    items.insert(0, item);
    await saveAll(items);
  }

  static Future<void> markRead(String id, bool read) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(read: read);
      await saveAll(items);
    }
  }

  static Future<void> markAllRead() async {
    final items = await loadAll();
    final updated = items.map((e) => e.copyWith(read: true)).toList();
    await saveAll(updated);
  }

  static Future<void> remove(String id) async {
    final items = await loadAll();
    items.removeWhere((e) => e.id == id);
    await saveAll(items);
  }

  // Seed some example notifications if none exist yet.
  // Seeding ignores preferences to guarantee initial content for the demo.
  static Future<void> ensureSeeded() async {
    final items = await loadAll();
    if (items.isNotEmpty) return;

    final now = DateTime.now();
    final samples = <AppNotification>[
      AppNotification(
        id: 'n1',
        type: NotificationType.order,
        title: 'Your order #4271 is out for delivery',
        body: 'Arriving today by 8 PM. Track your package.',
        timestamp: now.subtract(const Duration(hours: 2)),
        read: false,
      ),
      AppNotification(
        id: 'n2',
        type: NotificationType.promotion,
        title: 'Limited-time deal: 20% off on electronics',
        body: 'Grab top gadgets before the sale ends tonight!',
        timestamp: now.subtract(const Duration(hours: 6)),
        read: false,
      ),
      AppNotification(
        id: 'n3',
        type: NotificationType.priceDrop,
        title: 'Price drop on “Noise-Cancelling Headphones”',
        body: 'Now only \$129. Tap to view.',
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
        read: false,
      ),
      AppNotification(
        id: 'n4',
        type: NotificationType.system,
        title: 'Welcome to Passage',
        body: 'We\'re excited to have you here. Start exploring!',
        timestamp: now.subtract(const Duration(days: 5)),
        read: true,
      ),
    ];

    await saveAll(samples);
  }
}
