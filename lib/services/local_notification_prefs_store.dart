import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/notification_prefs.dart';

class LocalNotificationPrefsStore {
  static const String _key = 'notification_prefs_v1';

  static Future<NotificationPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_key);
      if (s == null || s.isEmpty) {
        final def = NotificationPrefs.defaults();
        await save(def);
        return def;
      }
      try {
        return NotificationPrefs.fromJson(s);
      } catch (_) {
        final def = NotificationPrefs.defaults();
        await save(def);
        return def;
      }
    } catch (_) {
      // Fall back to defaults if SharedPreferences fails
      return NotificationPrefs.defaults();
    }
  }

  static Future<void> save(NotificationPrefs p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, p.toJson());
    } catch (_) {
      // Ignore save errors in environments where SharedPreferences isn't available
    }
  }

  static Future<void> reset() async {
    await save(NotificationPrefs.defaults());
  }
}
